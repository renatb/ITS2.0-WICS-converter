#!/usr/bin/env perl
use strict;
use warnings;

#special handling of paths on Windows
BEGIN {
    if ($^O eq "MSWin32"){
        require Win32::LongPath;
        Win32::LongPath->import();
    }
}
use Encode;
use Encode::Locale;
use Log::Any::Adapter;
use Log::Any::Adapter qw(Stdout);
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");
use Path::Tiny;
use Try::Tiny;
use XML::ITS::WICS qw(xml2html);
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

=cut

my @specs = (
    Switch("overwrite|w"),
    List("input|i"),
);
my $opt = Getopt::Lucid->getopt( \@specs )->validate;

my @files = $opt->get_input;
my $overwrite = $opt->get_overwrite;

for my $path (@files){
    #decode weird characters in the path,
    $path = decode(locale => $path, 1);
    # then make it a Path::Tiny object
    $path = path($path);
    print STDOUT "\n----------\n$path\n----------\n";
    try{
        my $html = xml2html(_get_fh($path, '<:encoding(UTF-8)'));
        my $new_path = _get_new_path($path);
        my $out_fh = _get_fh($new_path, '>:encoding(UTF-8)');
        print $out_fh ${ $html };
    }catch{
        print STDERR $_;
    };
}

# either return whatever Path::Tiny returns, or
# use Win32::LongPath if on Windows
sub _get_fh {
    my ($path, $rw_string) = @_;
    if ($^O eq "MSWin32"){
        my $fh;
        openL \$fh, $rw_string, $path
            or die $!;
        return $fh;
    }
    return path->filehandle($rw_string);
}

sub _get_new_path {
    my ($old_path) = @_;
    my $name = $old_path->basename;
    my $dir = $old_path->dirname;

    #new file will have html extension instead of whatever there was before
    $name =~ s/(\.[^.]+)?$/.html/;
    # if we shouldn't overwrite a file, and another file with same name
    # exists, just iterate numbers to get a new, unused file name
    if(!$overwrite && path($dir, $name)->exists){
        my $counter = 1;
        $name =~ s/\.html$//;
        while(path($dir, $name . "-$counter.html")->exists){
            $counter++;
        }
        return path($dir, $name . "-$counter.html");
    }
    return path($dir, $name);
}