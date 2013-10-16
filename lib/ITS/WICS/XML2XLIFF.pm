#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::XML2XLIFF;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS);
use Log::Any qw($log);

use ITS qw(its_ns);
use ITS::DOM;
use ITS::DOM::Element qw(new_element);
use ITS::WICS::LogUtils qw(node_log_id log_match);
use ITS::WICS::XML2XLIFF::ITSProcessor qw(
	its_requires_inline
	convert_atts
	localize_rules
	transfer_inline_its
);
use ITS::WICS::XML2XLIFF::ITSSegmenter qw(extract_convert_its);
use ITS::WICS::XML2XLIFF::CustomSegmenter qw(extract_convert_custom);

our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';
our $ITSXLF_NS = 'http://www.w3.org/ns/its-xliff/';

# ABSTRACT: Extract ITS-decorated XML into XLIFF
our $VERSION = '0.01'; # VERSION

#default: convert and print input
print ${ __PACKAGE__->new()->convert($ARGV[0]) } unless caller;

sub new {
	my ($class) = @_;
	return bless {}, $class;
}

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

	$self->{match_index} = {};
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
	my ($self, $doc) = @_;

	# traverse every document element, extracting text for trans-units
	# and saving standoff/rules markup

	if($self->{seg} eq 'its'){
		$log->debug('Segmenting document using ITS metadata');
		($self->{tu}, $self->{its_els}) =
			extract_convert_its($doc->get_root, $self->{match_index});
	}else{
		$log->debug('Segmenting document using custom rules');
		($self->{tu}, $self->{its_els}) =
			extract_convert_custom(
				$doc->get_root,
				$self->{group_els},
				$self->{tu_els},
				$self->{match_index}
			);
	}
	return $self->_xliff_structure($doc->get_source);
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
	# paste all trans-unit/group elements
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

1;

__END__

=pod

=head1 NAME

ITS::WICS::XML2XLIFF - Extract ITS-decorated XML into XLIFF

=head1 VERSION

version 0.01

=head1 SYNOPSIS

    use ITS;
    use ITS::WICS::XML2XLIFF;
    my $converter = ITS::WICS::XML2XLIFF->new('Page Title');
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

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
