#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS;
use strict;
use warnings;
use autodie;
use Carp;
use ITS;
use ITS::WICS::XML2HTML;
use ITS::WICS::Reduce qw(reduce);
use ITS::WICS::XLIFF2HTML;
use ITS::WICS::XML2XLIFF;

use Exporter::Easy (
	OK => [qw(xml2html xliff2html reduceHtml xml2xliff)]
);
our $VERSION = '0.03'; # VERSION
# ABSTRACT: Work with ITS-decorated documents

sub xml2html {
    my ($doc) = @_;
    my $converter = ITS::WICS::XML2HTML->new();
    my $ITS = ITS->new('xml', doc => $doc);
    return $converter->convert($ITS);
}

sub xliff2html {
    my ($doc, $add_labels) = @_;
    my $converter = ITS::WICS::XLIFF2HTML->new();
    my $ITS = ITS->new('xml', doc => $doc);
    return $converter->convert($ITS, $add_labels);
}

sub xml2xliff {
    my ($doc) = @_;
    my $converter = ITS::WICS::XML2XLIFF->new();
    my $ITS = ITS->new('xml', doc => $doc);
    return $converter->convert(
        $ITS, group => ['sec'], tu => ['para']);
}

sub reduceHtml {
    my ($doc) = @_;
    my $ITS = ITS->new('html', doc => $doc);
    reduce($ITS);
    return \($ITS->get_doc->string);
}

1;

__END__

=pod

=head1 NAME

ITS::WICS - Work with ITS-decorated documents

=head1 VERSION

version 0.03

=head1 SYNOPSIS

    use ITS::WICS qw(xml2html);
    my $html = xml2html('path/to/file.xml');
    print $$html;

=head1 DESCRIPTION

WICS stands for Work In Context System. As a project, it is meant to make
Internationalization Tag Set (ITS) metadata contained in a document more
accessible to end-users via extraction and visualization.

This module provides access to the four WICS conversion tasks
(see the L</EXPORTS> section). Two standalone applications, a GUI and a CLI,
are also provided in this distribution (see WICS-GUI.pl and WICS.pl).

=head1 EXPORTS

The following subroutines may be exported:

=head2 C<xml2html>

Converts input XML data into HTML5 while keeping the ITS information
intact. See C<ITS::WICS::XML2HTML> for more details.

Argument is either a string containing an XML file name, a string pointer
containing actual XML data, or a filehandle for a file containing the data.

Return value is a pointer to a string containing the output HTML5 text.

=head2 C<xliff2html>

Converts input XLIFF data into HTML5 while keeping the ITS information
for C<source> and C<target> elements intact.

The first argument is either a string containing an XLIFF file name,
a string pointer containing actual XLIFF data, or a filehandle for a
file containing the data. The second argument is a boolean indicating whether
informative labels should be added (for empty or duplicate targets).

Return value is a pointer to a string containing the output HTML5 text.

=head2 C<xml2xliff>

Extracts translation units and ITS information from input XML data and
creates an XLIFF file. This function uses C<sec> elements to create
C<group>s, and C<para> elements to make C<trans-unit>s. Keep in mind that
this functionality is still highly immature.

The first argument is either a string containing an XML file name,
a string pointer containing actual XML data, or a filehandle for a
file containing the data.

Return value is a pointer to a string containing the output XLIFF text.

=head2 C<reduceHtml>

Consolidates ITS-decorated HTML5 by placing all external rules
in the head element.

The input and return values are the same as for C<xml2HTML>, except that
the input should refer to HTML5 data instead of XML.

=head1 SEE ALSO

This module relies on the L<ITS> module for processing ITS markup and rules.

The modules for the various ITS data conversion are included in this
distribution:

=over

=item L<ITS::WICS::XML2HTML>

=item L<ITS::WICS::XLIFF2HTML>

=item L<ITS::WICS::XML2XLIFF>

=item L<ITS::WICS::Reduce>

=back

The ITS 2.0 specification for XML and HTML5: L<http://www.w3.org/TR/its20/>.

The spec for representing ITS in XLIFF:
L<http://www.w3.org/International/its/wiki/XLIFF_1.2_Mapping>.

ITS interest group mail archives:
L<http://lists.w3.org/Archives/Public/public-i18n-its-ig/>

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
