package ITS::XML2XLIFF;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS);
use Log::Any qw($log);

use ITS qw(its_ns);
use ITS::DOM;
use ITS::DOM::Element qw(new_element);
use ITS::XML2XLIFF::LogUtils qw(node_log_id);

our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';
our $ITSXLF_NS = 'http://www.w3.org/ns/its-xliff/';

# ABSTRACT: Extract ITS-decorated XML into XLIFF
# VERSION

__PACKAGE__->new()->convert($ARGV[0]) unless caller;

=head1 METHODS

=head2 C<new>

Creates a new converter instance.

=back

=cut
sub new {
	my ($class, %args) = @_;
	return bless {}, $class;
}

=head2 C<convert>

Extracts strings from the input XML document into an XLIFF document.

Argument is either a string containing an XML file name, a string pointer
containing actual XML data, or a filehandle for a file containing the data.

Return value is a string pointer containing the output XLIFF string.

=cut

sub convert {
	my ($self, $doc_data) = @_;

	#create the document from the input data
	my $ITS = ITS->new('xml', doc => $doc_data);
	my $doc = $ITS->get_doc;

	if(!_is_legal_doc($doc)){
		croak 'cannot process a file with ITS element ' .
			'as root (except span). Include this file within ' .
			'another ITS document instead.';
	}

	# extract $doc into an XLIFF document;
	my ($xlf_doc) = $self->_xlfize($doc);
	return \($xlf_doc->string);
}

# returns true if the root of the given document not an ITS element
# (or is an ITS span element)
sub _is_legal_doc {
	my ($doc) = @_;
	my $root = $doc->get_root;
	if($root->namespace_URI eq its_ns() &&
		$root->local_name ne 'span'){
		return 0;
	}
	return 1;
}


# Pass in document to be the source of an XLIFF file
# return the new XLIFF document
sub _xlfize {
	my ($self, $doc) = @_;

	$log->debug('extracting translation units from document')
		if $log->is_debug;
	# traverse every document element, extracting text for trans-units
	# and saving standoff/rules markup
	$self->{its_els} = [];
	$self->{tu} = [];
	$self->_extract_convert($doc->get_root);
	return $self->_xliff_structure($doc->get_source);
}

# Extract translation units from the given element, placing them in
# the given new parent element. If newParent is undef, a new translation
# unit is created.
sub _extract_convert {
	my ($self, $el, $new_parent) = @_;
	for my $child ($el->children){
		# extract non-empty text nodes
		if($child->type eq 'TXT' && $child->text =~ /\S/){
			# create a new source element if needed
			$new_parent ||= $self->_get_new_source($el);
			$child->paste($new_parent);
		}elsif($child->type eq 'ELT'){
			#ITS standoff and rules need special processing
			if($el->namespace_URI &&
				$el->namespace_URI eq its_ns() &&
				$el->local_name !~ 'span'){
				#ignore its:rules and save standoff for later pasting
				if($el->local_name ne 'rules'){
					# save standoff markup for pasting in the head
					push @{ $self->{its_els} }, $el;
					if($log->is_debug){
						$log->debug('placing ' . node_log_id($el) .
							' as-is in XLIFF document');
					}
				}
				return;
			}
			#TODO: check if it's translatable
			#TODO: check withinText global rules
			my $within_text = $child->att('withinText', its_ns()) || '';
			#remove the no-longer-needed attribute before copying the element
			if($within_text){
				$child->remove_att('withinText', its_ns());
			}
			if( $within_text eq 'yes'){
				# create a new source element if needed
				$new_parent ||= $self->_get_new_source($el);
				$self->_extract_convert($child,
					$self->_get_new_mrk($child, $new_parent));
			}elsif($within_text eq 'nested'){
				# create a new source element if needed
				$new_parent ||= $self->_get_new_source($el);
				#one space to separate text on either side of nested element
				$new_parent->append_text(' ');
				# recursively extract
				$self->_extract_convert($child);
			}else{
				# break the text flow
				$new_parent = undef;
				# recursively extract
				$self->_extract_convert($child);
			}
		}
	}
	return;
}

# pass in the element which contains the text to be placed in a
# new source element. Create the source element and paste in
# inside a new trans-unit element.
sub _get_new_source {
	my ($self, $el) = @_;
	#copy element and atts, but not children
	my $source = $el->copy(0);
	$source->set_name('source');
	$source->set_namespace($XLIFF_NS);
	my $tu = new_element('trans-unit', {});
	$tu->set_namespace($XLIFF_NS);
	$source->paste($tu);
	push @{$self->{tu}}, $tu;
	$self->_convert_atts($source, $tu);
	# TODO: localize global rules
	return $source;
}

#create a new XLIFF mrk element to represent given element and paste
#is last in given parent
sub _get_new_mrk {
	my ($self, $el, $parent) = @_;
	#copy element and atts, but not children
	my $mrk = $el->copy(0);
	$mrk->set_name('mrk');
	$mrk->set_namespace($XLIFF_NS);
	$mrk->paste($parent);
	$self->_convert_atts($mrk);
	#TODO: localize global rules
	return $mrk;
}

#handle all attribute converting for the given element.
#$tu is containing trans-unit (not needed if $el is inline)
sub _convert_atts {
	my ($self, $el, $tu) = @_;

	my @atts = $el->get_xpath('@*');

	for my $att (@atts){
		# if not already removed while processing other atts
		if(!$att->doc_node){
			$self->_process_att($el, $att, $tu);
		}
	}
	return;
}

# process given attribute on given element;
# return the name of the element used to wrap the children, if any.
# $tu is containing trans-unit (not needed if $el is inline)
sub _process_att {
	my ($self, $el, $att, $tu) = @_;
	my $att_ns = $att->namespace_URI || '';
	my $att_name = $att->local_name;
	#TODO: there might be elements other than source and mrk someday
	my $inline = $el->local_name eq 'mrk' ? 1 : 0;
	if($att_ns eq its_ns()){
		if($att_name eq 'version'){
			$att->remove;
		}
		#need separate method to process all atts at once
		#If there's a locNoteType but no locNote then it
		#doesn't get processed (no reason to).
		if($att_name eq 'locNote'){
			_process_locNote($el, $inline);
		}elsif($att_name eq 'translate'){
			if($inline){
				$el->set_att('mtype',
					$att->value eq 'yes' ?
					'x-its-translate-yes' :
					'protected');
			}else{
				$tu->set_att('translate', $att->value);
			}
			$att->remove;
		}
	}elsif($att->name eq 'xml:id'){
		if(!$inline){

		}
		$att->remove;
		_process_xml_id($el, $inline);
	}
	return;
}

sub _process_locNote {
	my ($el, $inline) = @_;
	my $note = $el->att('locNote', its_ns());
	my $type = $el->att('locNoteType', its_ns()) || 'description';
	my $priority = $type eq 'alert' ? '1' : '2';

	if($inline){
		$el->set_att('comment', $note);
		$el->set_att('itsxlf:locNoteType', $type, $ITSXLF_NS);
	}else{
		my $note = new_element('note', {}, $note, $XLIFF_NS);
		$note->set_att('priority', $priority);
		$note->paste($el, 'after');
	}
	$el->remove_att('locNote', its_ns());
	$el->remove_att('locNoteType', its_ns());
}

# Place extracted translation units into an XLIFF skeleton, and
# standoff markup into header element.
# Single argument is the source of the original document.
# The XLIFF document is returned.
sub _xliff_structure {
	my ($self, $source) = @_;

	$log->debug('wrapping document in XLIFF structure')
		if $log->is_debug;

	#put its and itsxlf namespace declarations in root, and its:version
	my $xlf_doc = ITS::DOM->new(
		'xml', \("<xliff xmlns='$XLIFF_NS' xmlns:itsxlf='$ITSXLF_NS' " .
			'xmlns:its="' . its_ns() . q<" > .
		"its:version='2.0'/>"));
	my $root = $xlf_doc->get_root;

	my $file = new_element('file', {
		datatype => 'plaintext',
		original => $source,
		'source-language' => 'en'
		}
	);
	$file->set_namespace($XLIFF_NS);
	$file->paste($root);

	my $body = new_element('body');
	$body->set_namespace($XLIFF_NS);
	$body->paste($file);
	# paste all trans-unit elements
	$_->paste($body) for @{ $self->{tu} };

	if(@{ $self->{its_els} }){
		my $header = new_element('header');
		$header->set_namespace($XLIFF_NS);
		$header->paste($file);
		# paste all standoff markup
		$_->paste($header) for @{ $self->{its_els} };
	}

	return ($xlf_doc);
}
