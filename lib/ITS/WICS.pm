package ITS::WICS;
use strict;
use warnings;
use autodie;
use Carp;
use ITS::XML2HTML;
use Exporter::Easy (
	OK => ['xml2html']
);
# VERSION
# ABSTRACT: Convert a document while preserving the ITS information

=head1 SYNOPSIS

	my $obj = ITS::WICS->new();
	$obj->message();

=head1 DESCRIPTION

This module allows one to convert various forms of ITS-decorated XML into HTML with equivalent ITS markup.

=cut

# __PACKAGE__->new->_run unless caller;

=head1 METHODS

=head2 C<xml2html>

Converts input XML data into HTML5 while keeping the ITS information
intact. See C<ITS::XML2HTML> for more details.

Argument is either a string containing an XML file name, a string pointer
containing actual XML data, or a filehandle for a file containing the data.

=cut

sub xml2html {
    my ($doc) = @_;
    my $converter = ITS::XML2HTML->new();
    return $converter->convert($doc);
}

1;

