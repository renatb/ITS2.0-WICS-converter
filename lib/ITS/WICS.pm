package ITS::WICS;
use strict;
use warnings;
use autodie;
use Carp;
use ITS;
use ITS::XML2HTML;
use ITS::Reduce qw(reduce);

use Exporter::Easy (
	OK => [qw(xml2html reduceHtml)]
);
# VERSION
# ABSTRACT: Work with ITS-decorated documents

=head1 SYNOPSIS

    use ITS::WICS qw(xml2html);
    my $html = xml2html('path/to/file.xml');
    print $$html;

=head1 DESCRIPTION

WICS stands for Work In Context System. It is a way to make
Internationalization Tag Set information more accessible. This module wraps
up the functionality of several others into one package and provides a couple
of standalone applications.

=head1 EXPORTS

The following subroutines may be exported:

=head2 C<xml2html>

Converts input XML data into HTML5 while keeping the ITS information
intact. See C<ITS::XML2HTML> for more details.

Argument is either a string containing an XML file name, a string pointer
containing actual XML data, or a filehandle for a file containing the data.

Return value is a pointer to a string containing the output HTML5 text.

=cut
sub xml2html {
    my ($doc) = @_;
    my $converter = ITS::XML2HTML->new();
    return $converter->convert($doc);
}

=head2 C<reduceHtml>

Consolidates ITS-decorated HTML5 by placing all external rules
in the head element.

The input and return values are the same as for C<xml2HTML>, except that
the input should refer to HTML5 data instead of XML.

=cut
sub reduceHtml {
    my ($doc) = @_;
    my $ITS = ITS->new('html', doc => $doc);
    reduce($ITS);
    return \($ITS->get_doc->string);
}

1;

