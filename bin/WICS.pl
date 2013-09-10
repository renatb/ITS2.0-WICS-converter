#!/usr/bin/env perl
use strict;
use warnings;

use Log::Any::Adapter;
use Log::Any::Adapter qw(Stdout);
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");
use Path::Tiny;
use Try::Tiny;
use ITS::WICS qw(xml2html);
use Getopt::Lucid qw( :all );
# PODNAME: WICS.pl
# VERSION
# ABSTRACT: Convert ITS-decorated data

=head1 DESCRIPTION

This is a script for converting ITS-decorated
data into other formats. Currently it only supports XML->HTML
conversion.

=head1 USAGE

  WICS.pl [options] -[i|input] <file>

=head1 REQUIRED ARGUMENTS

=over

=item -i | --input <file>...

Specify the XML file or files to be converted into HTML.

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

=back

=head1 STANDALONE EXECUTABLE

To create a standalone executable of this script, you will follow the same
procedure as described in WICS-GUI.pl, but since this is not a GUI
application you will not have to install C<Wx::Perl::Packager> or use C<wxpar>.

Here is an example command used to create a standalone executable. Run in a
Windows CMD, this should all be one line; I have broken it into three
lines for display purposes.

  pp -o WICS.exe -l C:/strawberry/c/bin/libxml2-2__.dll
  -l C:/strawberry/c/bin/libiconv-2__.dll -l C:/strawberry/c/bin/libz__.dll
  -I XML-ITS-0.02/lib -I XML-ITS-WICS-0.02/lib XML-ITS-WICS-0.02/bin/WICS.pl

NOTE: running the exe may fail the first time with an error message with
"Archive.pm line 192". Just run it again and it should be fine.

=head1 TODO

This script should support unicode filenames; however, it doesn't
decode CMD input, so unicode input gets garbled. One way to do this
is to use the Encode::Locale module to decode input. Creating the
standalone executable would then require the inclusion of the Unicode
modules directory. However, this poses problems because at best the
executable could only decode whatever it could decode on the computer
with which it was made. This problem needs further investigation.

Fixing the Archive.pm error for the standalone would also be nice.

=cut

my @specs = (
    Switch("overwrite|w"),
    List("input|i"),
);
my $opt;
try {
    $opt = Getopt::Lucid->getopt( \@specs )->
        validate({requires => ['input']});
}catch{
    my $msg = "\nWICS XML2HTML converter\n";
    $msg .= "$_\n";
    $msg .= "Usage: WICS [-w] -i <file> [-i <file>...]\n";
    $msg .= "  -w or --overwrite: overwrite existing files during conversion\n";
    $msg .= "  -i or --input: convert given XML file\n";
    die $msg;
};

my @files = $opt->get_input;
my $overwrite = $opt->get_overwrite;

for my $path (@files){
    # make the path a Path::Tiny object
    $path = path($path);
    print "\n----------\n$path\n----------\n";
    try{
        my $html = xml2html( $path );
        my $new_path = _get_new_path($path, $overwrite);
        my $out_fh = $new_path->filehandle('>:encoding(UTF-8)');
        print $out_fh ${ $html };
        print "wrote $new_path\n";
    }catch{
        print STDERR $_;
    };
}

#input: Path::Tiny object for input file path
sub _get_new_path {
    my ($old_path, $overwrite) = @_;
    my $name = $old_path->basename;
    my $dir = $old_path->dirname;

    #new file will have html extension instead of whatever there was before
    $name =~ s/(\.[^.]+)?$/.html/;
    # if other file with same name exists, just iterate numbers to get a new,
    # unused file name
    my $new_path = path($dir, $name);
    if(!$overwrite && $new_path->exists){
        $name =~ s/\.html$//;
        $new_path = path($dir, $name . '-1.html');
        my $counter = 1;
        while($new_path->exists){
            $counter++;
            $new_path = path($dir, $name . "-$counter.html");
        }
    }
    return $new_path;
}
