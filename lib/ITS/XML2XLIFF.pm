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
use ITS::XML2XLIFF::ITSProcessor qw(
	its_requires_inline
	convert_atts
	localize_rules
	transfer_inline_its
);
use ITS::XML2XLIFF::ITSSegmenter qw(extract_convert_its);

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
		($self->{tu}, $self->{its_els}) =
			extract_convert_its($doc->get_root, $self->{match_index});
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
	my $place_inline = its_requires_inline(
			$original, $self->{match_index}->{$original->unique_key});;

	#create new trans-unit to hold element contents
	my $tu = new_element('trans-unit', {});
	$tu->set_namespace($XLIFF_NS);

	#copy element as a new source
	my $source = $original->copy(0);
	$source->set_name('source');
	$source->set_namespace($XLIFF_NS);
	$source->paste($tu);

	# attributes get added while localizing rules; so save the ones
	# that need to be processed by convert_atts first
	my @atts = $source->get_xpath('@*');
	localize_rules(
		$source, $tu, $self->{match_index}->{$original->unique_key});
	#segmentation scheme determines withinText, so these should be removed
	$source->remove_att('withinText', its_ns());
	convert_atts($source, \@atts, $tu);

	# process children as inline elements
	for my $child($original->children){
		$child->paste($source);
		if($child->type eq 'ELT'){
			$self->_process_inline($child, $tu);
		}
	}

	#ITS may require wrapping children in mrk and moving markup
	if($place_inline){
		my $mrk = new_element('mrk');
		$mrk->set_namespace($XLIFF_NS);
		for my $child ($source->children){
			$child->paste($mrk);
		}
		$mrk->paste($source);
		transfer_inline_its($source, $mrk);
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
	localize_rules(
		$el, $tu, $self->{match_index}->{$el->unique_key});
	#segmentation scheme determines withinText, so these should be removed
	$el->remove_att('withinText', its_ns());
	convert_atts($el, \@atts);

	#default value for required 'mtype' attribute is 'x-its',
	#indicating some kind of ITS usage
	if(!$el->att('mtype')){
		$el->set_att('mtype', 'x-its');
	}

	# recursively process children
	for my $child($el->children){
		if($child->type eq 'ELT'){
			$self->_process_inline($child, $tu);
		}
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