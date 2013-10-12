package ITS::XML2XLIFF;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS);
use Log::Any qw($log);

use ITS qw(its_ns);
use ITS::DOM;
use ITS::DOM::Element qw(new_element);
use ITS::XML2XLIFF::LogUtils qw(node_log_id log_match);

our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';
our $ITSXLF_NS = 'http://www.w3.org/ns/its-xliff/';

# ABSTRACT: Extract ITS-decorated XML into XLIFF
# VERSION

#default: convert and print input
print ${ __PACKAGE__->new()->convert($ARGV[0]) } unless caller;

=head1 SYNOPSIS

    use ITS;
    use ITS::XML2XLIFF;
    my $converter = ITS::XML2XLIFF->new('Page Title');
    my $ITS = ITS->new('xml', doc => \'<xml>some text</xml>');
    my $result = $converter->convert($ITS);
    print $$result;

=head1 DESCRIPTION

This module extracts strings from an XML file to create an XLIFF file,
keeping the original ITS information intact.

=head1 CAVEATS

This module is very preliminary, and there are plenty of things to
implement still. Only a few ITS data categories are converted, and no
inherited ITS information is saved.

=head1 SEE ALSO

This module relies on the L<ITS> module for processing ITS markup and rules.

The ITS 2.0 specification for XML and HTML5: L<http://www.w3.org/TR/its20/>.

The spec for representing ITS in XLIFF:
L<http://www.w3.org/International/its/wiki/XLIFF_1.2_Mapping>.

ITS interest group mail archives:
L<http://lists.w3.org/Archives/Public/public-i18n-its-ig/>

=head1 METHODS

=head2 C<new>

Creates a new converter instance.

=cut
sub new {
	my ($class) = @_;
	return bless {}, $class;
}

=head2 C<convert>

Extracts strings from the input ITS object containing an XML document
into an XLIFF document, preserving ITS information.

Return value is a string pointer containing the output XLIFF string.

There are two segmentation schemes: the default behavior is to extract
all strings in the document, using ITS C<withinText> values (currently
only implemented with local markup) to decide which elements are inline
or structural.

You may also passing C<tu> and C<group> parameters after the ITS document
to get a different segmentation behavior. Each parameter should be an
array ref containing names of elements to be used for extracting
C<trans-unit>s and C<group>s, repsectively. Children of C<trans-unit>s are
placed inline. If no C<group> element names are specified, then C<trans-units>
for the whole document are placed in one C<group>.

For example, the following will extract C<para> elements and their children
as C<trans-units>, and place them in groups with other C<trans-units> extracted
from the same C<sec> elements:

	my $xliff = $XML2XLIFF->convert($ITS, group => ['sec'], tu => ['para']);

=cut

sub convert {
	my ($self, $ITS, %seg) = @_;

	if($ITS->get_doc_type ne 'xml'){
		croak 'Cannot process document of type ' . $ITS->get_doc_type;
	}
	my $doc = $ITS->get_doc;

	if(!_is_legal_doc($doc)){
		croak 'cannot process a file with ITS element ' .
			'as root (except span). Include this file within ' .
			'another ITS document instead.';
	}

	#TODO: obvious sign that this method should just be the constructor...
	delete $self->{match_index};

	# Check if segmentation rules were provided
	# TODO: check input a little better
	if(keys %seg){
		$self->{group_els} = $seg{group} or
			$log->info('Group elements not specified');
		$self->{tu_els} = $seg{tu} or
			croak 'Trans-unit elements not specified';
		$self->{seg} = 'custom';
	}else{
		$self->{seg} = 'its';
	}

	#iterate all document rules and their matches, indexing each one
	for my $rule (@{ $ITS->get_rules }){
		my $matches = $ITS->get_matches($rule);
		$self->_index_match($rule, $_) for @$matches;
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

# index a single set of rule matches
# This sub saves ITS info in $self like so:
# $self->{match_index}->{$node->unique_key}->{its name} = "its value"
sub _index_match {
	my ($self, $rule, $matches) = @_;
	log_match($rule, $matches, $log);

	my $node = $matches->{selector};
	delete $matches->{selector};

	# create a hash containing all ITS info given to the selected node
	my $its_info = {};
	for my $att (@{ $rule->value_atts }){
		$its_info->{$att} = $rule->element->att($att);
	}
	#for <its:locNote> or similar (in future ITS standards)
	if(my @children = @{ $rule->element->child_els }){
		for (@children){
			$its_info->{$_->local_name} = $_->text;
		}
	}

	# $name is 'selector', 'locNotePointer', etc.
	# Store string its_info for all pointer matches
	while (my ($name, $match) = each %$matches) {
		$name =~ s/Pointer$//;
		if((ref $match) =~ /Value$/){
			$its_info->{$name} = $match->value;
		}elsif($match->type eq 'ELT'){
			$its_info->{$name} = $match->text;
		}else{
			$its_info->{$name} = $match->value;
		}
	}
	# merge the new ITS info with whatever ITS info may already exist
	# for the given node
	@{ $self->{match_index}->{$node->unique_key} }{keys %$its_info} =
		values %$its_info;
	return;
}

# Pass in document to be the source of an XLIFF file and segmentation arguments
# return the new XLIFF document
sub _xlfize {
	my ($self, $doc, %seg) = @_;

	# traverse every document element, extracting text for trans-units
	# and saving standoff/rules markup
	$self->{its_els} = [];
	$self->{tu} = [];

	#TODO: manage groups of translation-units
	#This will contain arrays of trans-units
	$self->{groups} = [];
	if($self->{seg} eq 'its'){
		$log->debug('Segmenting document using ITS metadata');
		$self->_extract_convert_its($doc->get_root);
		#todo: distribute into some other method
		$self->_copy_source_to_target;
	}else{
		$log->debug('Segmenting document using custom rules');
		if(@{$self->{group_els}}){
			$self->_extract_convert_groups($doc->get_root);
		}else{
			$self->{current_group} = new_element('group');
			$self->{current_group}->set_namespace($XLIFF_NS);
			$self->_extract_convert_units($doc->get_root);
			#if the current group has trans-units, assign an id and save it
			if(@{$self->{current_group}->child_els}){
				$self->{current_group}->set_att('id', ++$self->{group_num});
				push $self->{groups}, $self->{current_group};
			}
		}
	}
	return $self->_xliff_structure($doc->get_source);
}

# Extract translation units from the given element, placing them in
# the given new parent element. If newParent is undef, a new translation
# unit is created. This extraction method uses ITS to determine segmentation.
sub _extract_convert_its {
	my ($self, $el, $new_parent) = @_;

	#check if element should be source or mrk inside of source
	my $place_inline;
	#no need to place inline if it already is inline
	if($new_parent && $new_parent->name eq 'mrk'){
		$place_inline = 0;
	}else{
		$place_inline = $self->_its_requires_inline($el);
	}

	for my $child ($el->children){
		# extract non-empty text nodes
		if($child->type eq 'TXT' && $child->text =~ /\S/){
			# create a new source element if needed
			$new_parent ||= $self->_get_new_source($el);
			$child->paste($new_parent);
		}elsif($child->type eq 'ELT'){
			#ITS standoff and rules need special processing
			if($child->namespace_URI &&
				($child->namespace_URI eq its_ns() ) &&
				$child->local_name !~ 'span'){
				#ignore its:rules and save standoff for later pasting
				if($child->local_name ne 'rules'){
					# save standoff markup for pasting in the head
					push @{ $self->{its_els} }, $child;
					if($log->is_debug){
						$log->debug('placing ' . node_log_id($child) .
							' (standoff markup) as-is in XLIFF document');
					}
				}
				next;
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
				$self->_extract_convert_its($child,
					$self->_get_new_mrk($child, $new_parent));
			}elsif($within_text eq 'nested'){
				# create a new source element if needed
				$new_parent ||= $self->_get_new_source($el);
				#one space to separate text on either side of nested element
				$new_parent->append_text(' ');
				# recursively extract
				$self->_extract_convert_its($child);
			}else{
				# break the text flow
				$new_parent = undef;
				# recursively extract
				$self->_extract_convert_its($child);
			}
		}
	}

	#ITS may require wrapping children in mrk and moving some markup
	if($place_inline){
		my $mrk = new_element('mrk');
		$mrk->set_namespace($XLIFF_NS);
		for my $child ($new_parent->children){
			$child->paste($mrk);
		}
		$mrk->paste($new_parent);
		_transfer_inline_its($new_parent, $mrk);
	}

	return;
}

#extract groups and translation units according to elements specified as
#group or trans-unit containers
sub _extract_convert_groups {
	my ($self, $el) = @_;
	return if $self->_check_standoff($el);

	my $name = $el->local_name;
	# if this element is a group separator,
	# then make a group out of the TUs it contains
	if(grep {$_ eq $name} @{ $self->{group_els} }){
		$self->{current_group} = new_element('group');
		$self->{current_group}->set_namespace($XLIFF_NS);
		$self->_extract_convert_units($el);
		#if the current group has trans-units, assign an id and save it
		if(@{$self->{current_group}->child_els}){
			$self->{current_group}->set_att('id', ++$self->{group_num});
			push @{$self->{groups}}, $self->{current_group};
		}
	#otherwise, search for groups in its children
	}else{
		for my $child (@{$el->child_els}){
			$self->_extract_convert_groups($child);
		}
	}
	return;
}

#return true if markup should be ignored (ITS standoff or rules)
sub _check_standoff {
	my ($self, $el) = @_;

	my $name = $el->local_name;
	#ignore ITS rules and save standoff;
	#let its:span through (could possibly be used for holding segments)
	if($el->namespace_URI eq its_ns()){
		if($name eq 'rules'){
			return 1;
		}elsif($name ne 'span'){
			push @{$self->{its_els}}, $el;
			return 1;
		}
	}
	return 0;
}

# find and return TUs in current element
sub _extract_convert_units {
	my ($self, $el) = @_;
	return if $self->_check_standoff($el);

	my $name = $el->local_name;
	# if this element is contains a translation unit,
	# then make a trans-unit element out of it and its children
	if(grep {$_ eq $name} @{ $self->{tu_els} }){
		#don't extract empty elements
		if($el->text =~ /\S/){
			$self->_extract_convert_tu($el);
		}
	#otherwise, search for TUs in its children
	}else{
		for my $child (@{$el->child_els}){
			$self->_extract_convert_units($child);
		}
	}
	return;
}

#create and a single TU from $original, pasting it in the current group
sub _extract_convert_tu {
	my ($self, $original) = @_;

	if($log->is_debug){
		$log->debug('Creating new trans-unit with '
			. node_log_id($original) . ' as source');
	}

	#check if element should be source or mrk inside of source
	my $place_inline = $self->_its_requires_inline($original);

	#create new trans-unit to hold element contents
	my $tu = new_element('trans-unit', {});
	$tu->set_namespace($XLIFF_NS);

	#copy element as a new source
	my $source = $original->copy(1);
	$source->set_name('source');
	$source->set_namespace($XLIFF_NS);
	$source->paste($tu);

	# attributes get added while localizing rules; so save the ones
	# that need to be processed by convert_atts first
	my @atts = $source->get_xpath('@*');
	$self->_localize_rules($original, $source, $tu);
	$self->_convert_atts($source, \@atts, $tu);

	#process children as inline elements
	for my $child(@{$source->child_els}){
		$self->_process_inline($child, $tu);
	}

	#ITS may require wrapping children in mrk and moving markup
	if($place_inline){
		my $mrk = new_element('mrk');
		$mrk->set_namespace($XLIFF_NS);
		for my $child ($source->children){
			$child->paste($mrk);
		}
		$mrk->paste($source);
		_transfer_inline_its($source, $mrk);
	}

	my $target = $source->copy(1);
	$target->set_name('target');
	$target->set_att('state', 'new');
	$target->paste($source, 'after');

	$tu->set_att('id', , ++$self->{tu_num});
	$tu->paste($self->{current_group});
	return;
}

#convert a child into an inline XLIFF element
sub _process_inline {
	my ($self, $el, $tu) = @_;

	$el->set_name('mrk');
	$el->set_namespace($XLIFF_NS);

	# attributes get added while localizing rules; so save the ones
	# that need to be processed by convert_atts first
	my @atts = $el->get_xpath('@*');
	$self->_localize_rules($el, $el, $tu);
	$self->_convert_atts($el, \@atts);

	#default value for required 'mtype' attribute is 'x-its',
	#indicating some kind of ITS usage
	if(!$el->att('mtype')){
		$el->set_att('mtype', 'x-its');
	}
	return;
}

# return true if converting the ITS info on the given element
# requires that it be rendered inline (as mrk) instead of structural
# (as its own source)
sub _its_requires_inline {
	my ($self, $el) = @_;

	# any terminology information requires inlining
	if($el->att('term', its_ns())){
		return 1;
	}
	my $global = $self->{match_index}->{$el->unique_key};
	return 0 unless $global;
	if(exists $global->{term}){
		return 1;
	}
	return 0;
}

# transfer ITS that is required to be on a mrk (not on a source) from $from
# to $to
sub _transfer_inline_its {
	my ($from, $to) = @_;

	#all of the terminology information has to be moved
	my $mtype = $from->att('mtype');
	if($mtype =~ /term/){
		$to->set_att('mtype', $from->att('mtype'));
		$from->remove_att('mtype');
		my @term_atts = qw(
			termInfo
			termInfoRef
			termConfidence
		);

		for my $att (@term_atts){
			if (my $value = $from->att($att, $ITSXLF_NS)){
				$from->remove_att($att, $ITSXLF_NS);
				$to->set_att("itsxlf:$att", $value, $ITSXLF_NS);
			}
		}
	}
	return;
}

#copy the source element in each TU and rename it target; add
#state="new" to each one.
sub _copy_source_to_target {
	my ($self) = @_;
	for my $tu(@{ $self->{tu} }){
		my ($source) = @{ $tu->child_els('source') };
		my $target = $source->copy(1);
		$target->set_name('target');
		$target->set_att('state', 'new');
		$target->paste($tu);
	}
	$log->debug('Copying sources to targets');
	return;
}

# pass in the element which contains the text to be placed in a
# new source element. Create the source element and paste in
# inside a new trans-unit element.
sub _get_new_source {
	my ($self, $el) = @_;

	if($log->is_debug){
		$log->debug('Creating new trans-unit with ' . node_log_id($el) .
			' as source');
	}
	#create new trans-unit to hold element contents
	my $tu = new_element('trans-unit', {});
	$tu->set_namespace($XLIFF_NS);
	push @{$self->{tu}}, $tu;

	#copy element and atts, but not children
	my $new_el = $el->copy(0);
	$new_el->set_name('source');
	$new_el->set_namespace($XLIFF_NS);
	$new_el->paste($tu);

	# attributes get added while localizing rules; so save the ones
	# that need to be processed by convert_atts first
	my @atts = $new_el->get_xpath('@*');
	$self->_localize_rules($el, $new_el, $tu);
	$self->_convert_atts($new_el, \@atts, $tu);

	return $new_el;
}

#create a new XLIFF mrk element to represent given element and paste
#is last in given parent
sub _get_new_mrk {
	my ($self, $el, $parent) = @_;

	if($log->is_debug){
		$log->debug('Creating inline <mrk> from ' . node_log_id($el));
	}
	#copy element and atts, but not children
	my $mrk = $el->copy(0);
	$mrk->set_name('mrk');
	$mrk->set_namespace($XLIFF_NS);
	$mrk->paste($parent);

	# attributes get added while localizing rules; so save the ones
	# that need to be processed by convert_atts first
	my @atts = $mrk->get_xpath('@*');
	$self->_localize_rules($el, $mrk, $parent);
	$self->_convert_atts($mrk, \@atts);

	#default value for required 'mtype' attribute is 'x-its',
	#indicating some kind of ITS usage
	if(!$mrk->att('mtype')){
		$mrk->set_att('mtype', 'x-its');
	}
	return $mrk;
}

#convert ITS info from global rules matching $old_el into local markup
#on $new_el or $tu (containing trans-unit)
sub _localize_rules {
	my ($self, $old_el, $new_el, $tu) = @_;

	my $its_info = $self->{match_index}->{$old_el->unique_key};
	if(!$its_info){
		return;
	}

	#TODO: there might be elements other than source and mrk someday
	my $inline = $new_el->local_name eq 'mrk' ? 1 : 0;

	#each of these is a check that 1) the category is selected in a global
	#rule and 2) there is no local selection. TODO: clean this up?
	while (my ($name, $value) = each %$its_info){
		if($name eq 'locNote' &&
				!defined $new_el->att('locNote', its_ns())){
			my $type = $its_info->{locNoteType} || 'description';
			_process_locNote($new_el, $value, $type, $tu, $inline)
		}elsif($name eq 'translate' &&
				!defined $new_el->att('translate', its_ns())){
			_process_translate($new_el, $value, $tu, $inline);
		}elsif($name eq 'idValue' &&
				!defined $new_el->att('xml:id')){
			_process_idValue($value, $tu, $inline);
		}elsif($name eq 'term' &&
				!defined $new_el->att('term', its_ns())){
			my %termHash;
			my @term_atts = qw(
				term
				termInfo
				termInfoRef
				termConfidence
			);
			@termHash{@term_atts} = @$its_info{@term_atts};
			_process_term($new_el, %termHash);
		}
	}
	return;
}

# handle all attribute converting for the given element.
# $atts is array of att nodes to be processed
# $tu is containing trans-unit (not needed if $el is inline)
sub _convert_atts {
	my ($self, $el, $atts, $tu) = @_;

	#TODO: there might be elements other than source and mrk someday
	my $inline = $el->local_name eq 'mrk' ? 1 : 0;

	for my $att (@$atts){
		# if not already removed while processing other atts
		if($att->parent){
			$self->_process_att($el, $att, $tu, $inline);
		}
	}
	return;
}

# process given attribute on given element;
# return the name of the element used to wrap the children, if any.
# $tu is containing trans-unit (not needed if $el is inline)
sub _process_att {
	my ($self, $el, $att, $tu, $inline) = @_;
	my $att_ns = $att->namespace_URI || '';
	my $att_name = $att->local_name;
	if($att_ns eq its_ns()){
		if($att_name eq 'version'){
			$att->remove;
		}
		# If there's a locNoteType but no locNote, then it
		# doesn't get processed (no reason to).
		if($att_name eq 'locNote'){
			my $type = $el->att('locNoteType', its_ns()) || 'description';
			_process_locNote($el, $att->value, $type, $tu, $inline);
			$el->remove_att('locNote', its_ns());
			$el->remove_att('locNoteType', its_ns());
		}elsif($att_name eq 'translate'){
			_process_translate($el, $att->value, $tu, $inline);
			$att->remove;
		# If there's a term* but no term, then it
		# doesn't get processed (no reason to).
		}elsif($att_name eq 'term'){
			_process_term(
				$el,
				term => $att->value,
				termInfoRef => $el->att('termInfoRef', its_ns()),
				termConfidence => $el->att('termConfidence', its_ns()),
			);
			$att->remove;
			$el->remove_att('termInfoRef', its_ns());
			$el->remove_att('termConfidence', its_ns());
		}
		#default for ITS atts: leave them there
	}elsif($att->name eq 'xml:id'){
		_process_idValue($att->value, $tu, $inline);
		$att->remove;
	}else{
		$att->remove;
	}
	return;
}

# pass in an element to be annotated, locNote and locNoteType values,
# and whether the element is inline or not
sub _process_locNote {
	my ($el, $note, $type, $tu, $inline) = @_;
	my $priority = $type eq 'alert' ? '1' : '2';
	if($inline){
		$el->set_att('comment', $note);
		$el->set_att('itsxlf:locNoteType', $type, $ITSXLF_NS);
	}else{
		my $note = new_element('note', {}, $note, $XLIFF_NS);
		$note->set_att('priority', $priority);
		$note->paste($tu);
	}
	return;
}

# input element and it's ITS translate value, containing TU, and whether
# it's inline
sub _process_translate {
	my ($el, $translate, $tu, $inline) = @_;
	if($inline){
		$el->set_att('mtype',
			$translate eq 'yes' ?
			'x-its-translate-yes' :
			'protected');
	}else{
		$tu->set_att('translate', $translate);
	}
	return;
}

sub _process_term {
	my ($el, %termInfo) = @_;
	$termInfo{term} eq 'yes' ?
		$el->set_att('mtype', 'term') :
		$el->set_att('mtype', 'x-its-term-no');

	for my $name(qw(termInfoRef termConfidence termInfo)){
		if (my $val = $termInfo{$name}){
			$el->set_att("itsxlf:$name", $val, $ITSXLF_NS);
		}
	}
	return;
}

sub _process_idValue {
	my ($id, $tu, $inline) = @_;
	#this att is ignored on inline elements
	if(!$inline){
		$tu->set_att('resname', $id);
	}
	return;
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
	$_->paste($body) for @{ $self->{groups} };

	if(@{ $self->{its_els} }){
		my $header = new_element('header');
		$header->set_namespace($XLIFF_NS);
		$header->paste($file);
		# paste all standoff markup
		$_->paste($header) for @{ $self->{its_els} };
	}

	return ($xlf_doc);
}

1;