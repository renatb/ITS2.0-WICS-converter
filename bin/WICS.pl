#!/usr/bin/env perl
use strict;
use warnings;
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
    $path = path($path);
    print STDOUT "\n----------\n$path\n----------\n";
    try{
        my $html = xml2html($path);
        my $new_path = _get_new_path($path);
        my $fh = path($new_path)->
            filehandle('>:utf8');
        print $fh ${ $html };
    }catch{
        print STDERR $_;
    };
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