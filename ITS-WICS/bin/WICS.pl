#!/usr/bin/env perl
use strict;
use warnings;

use Log::Any::Adapter;
use Log::Any::Adapter qw(Stdout);
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");
use Path::Tiny;
use Try::Tiny;
use ITS::WICS qw(xml2html xliff2html reduceHtml xml2xliff);
use Getopt::Lucid qw( :all );
# PODNAME: WICS.pl
# VERSION
# ABSTRACT: Convert ITS-decorated data

=head1 DESCRIPTION

This is a command-line application for altering ITS-decorated
data. The currently supported operations are XML->HTML5 conversion
and HTML5 file consolidation.

=head1 USAGE

  WICS.pl [options] -[i|input] <file>

=head1 REQUIRED ARGUMENTS

=over

=item -i | --input <file>...

Specify the XML file or files to be converted into HTML.

=item --xml2html, --xliff2html, --xml2xliff or --reduceHtml

Specifies which operation is to be carried out on the input file. The first
converts an ITS-decorated XML file into an HTML5 file for displaying the
contents. The second converts an XLIFF file into HTML5, with the goal of
displaying ITS information on C<source> and C<target> elements. The third
extracts translation units with ITS information and creates an XLIFF file.
The last one consolidates an ITS-decorated HTML5 file and its external
resources into one HTML5 file.

=back

=head1 OPTIONS

=over

=item -w | --overwrite

Specifies that the script may overwrite existing files when creating
converted output. Filenames are created by stripping the extension from
the input file and replacing it with the extension for the target format
(html, xliff, etc.). If overwriting existing files is not permitted,
additional numbers (-1, -2, etc.) will be appended to the filename to
insure uniqueness.

This script will never write over the input file.

=back

=head1 STANDALONE EXECUTABLE

To create a standalone executable of this script, you will follow the same
procedure as described in WICS-GUI.pl, but since this is not a GUI
application you will not have to install C<Wx::Perl::Packager> or use C<wxpar>.

Here is an example command used to create a standalone executable. Run in a
Windows CMD, this should all be one line; I have broken it into several
lines for display purposes.

  pp -o WICS.exe -l C:/strawberry/c/bin/libxml2-2__.dll
  -l C:/strawberry/c/bin/libiconv-2__.dll -l C:/strawberry/c/bin/libz__.dll
  -I ITS-0.04/lib -I ITS-WICS-0.01/lib ITS-XML2HTML-0.05/bin/WICS.pl
  -I ITS-XLIFF2HTML-0.02/lib -I ITS-XML2XLIFF-0.01/lib -I ITS-Reduce-0.01/lib

=cut

my @specs = (
    Switch('xml2html')->anycase,
    Switch('xliff2html')->anycase,
    Switch('xml2xliff')->anycase,
    Switch('reduceHtml')->anycase,
    Switch('overwrite|w')->anycase,
    List('input|i')->anycase,
);
my $opt;
try {
    $opt = Getopt::Lucid->getopt( \@specs )->
        validate({requires => ['input']});
    if(!($opt->get_reduceHtml || $opt->get_xml2html ||
        $opt->get_xliff2html || $opt->get_xml2xliff)){
        die 'must provide either --xml2html, --xml2xliff, ' .
            '--xliff2html or --reducehHtml';
    }
}catch{
    my $msg = "\nWICS ITS document processor\n";
    $msg .= "$_\n";
    $msg .= 'Usage: WICS --(xml2html|xliff2html|xml2xliff|reduceHtml) ' .
        "[-w] -i <file> [-i <file>...]\n";
    $msg .= "  --xml2html: convert ITS-decorated XML to HTML5\n";
    $msg .= "  --xliff2html: convert ITS-decorated XLIFF to HTML5\n";
    $msg .= "  --reduceHtml: reduce ITS-decorated HTML5 to single file\n";
    $msg .= "  -w or --overwrite: overwrite existing files during conversion\n";
    $msg .= "  -i or --input: convert given XML file\n";
    die $msg;
};

my ($processor, $output_ext);
if($opt->get_xml2html){
    $processor = sub { xml2html($_[0]) };
    $output_ext = 'html';
}elsif($opt->get_reduceHtml){
    $processor = sub { reduceHtml($_[0]) };
    $output_ext = 'html';
}elsif($opt->get_xliff2html){
    # the 1 is to add labels
    $processor = sub { xliff2html($_[0], 1) };
    $output_ext = 'html';
}elsif($opt->get_xml2xliff){
    $processor = sub { xml2xliff($_[0]) };
    $output_ext = 'xlf';
}
#TODO: XML2XLIFF

my @files = $opt->get_input;
my $overwrite = $opt->get_overwrite;

for my $path (@files){
    # make the path a Path::Tiny object
    $path = path($path);
    print "\n----------\n$path\n----------\n";
    try{
        my $html = $processor->( $path );
        my $new_path = _get_new_path($path, $overwrite, $output_ext);
        my $out_fh = $new_path->filehandle('>:encoding(UTF-8)');
        print $out_fh ${ $html };
        print "wrote $new_path\n";
    }catch{
        print STDERR $_;
    };
}

#input: Path::Tiny object for input file path
sub _get_new_path {
    my ($old_path, $overwrite, $output_ext) = @_;
    my $name = $old_path->basename;
    my $dir = $old_path->dirname;

    #new file will have html extension instead of whatever there was before
    $name =~ s/(\.[^.]+)?$/.$output_ext/;
    # if other file with same name exists, just iterate numbers to get a new,
    # unused file name
    my $new_path = path($dir, $name);
    if($name eq $old_path->basename ||
        (!$overwrite && $new_path->exists)){
        $name =~ s/\.$output_ext$//;
        $new_path = path($dir, $name . "-1.$output_ext");
        if(!$overwrite){
            my $counter = 1;
            while($new_path->exists){
                $counter++;
                $new_path = path($dir, $name . "-$counter.$output_ext");
            }
        }
    }
    return $new_path;
}
