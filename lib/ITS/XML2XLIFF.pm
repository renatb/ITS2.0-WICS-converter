package ITS::XML2XLIFF;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS);
use Log::Any qw($log);

use ITS qw(its_ns);
use ITS::DOM;
use ITS::DOM::Element qw(new_element);

our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';

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
	# TODO: traverse every document element, extracting text for trans-units

	return $self->_xliff_structure($doc->get_source);
}

# Place extracted translation units into an XLIFF skeleton.
# TODO: standoff markup
# Single argument is the source of the original document.
# The XLIFF document is returned.
sub _xliff_structure {
	my ($self, $source) = @_;

	$log->debug('wrapping document in XLIFF structure')
		if $log->is_debug;

	my $xlf_doc = ITS::DOM->new(
		'xml', \("<xliff xmlns='$XLIFF_NS' xmlns:its='" . its_ns() .
		"' its:version='2.0'/>"));
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

	return ($xlf_doc);
}
