#convert XML data to HTML and compare with expected

use strict;
use warnings;
use ITS::WICS qw(xml2html);
use Test::More;
plan tests => 4;
use Test::NoWarnings;
use Test::LongString;
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $xml_dir = path($Bin, 'corpus', 'inputXML');
my $html_dir = path($Bin, 'corpus', 'outputHTML');

my @xml_docs = $xml_dir->children;
for my $file(@xml_docs){
    next if $file =~ /_rules_XML/;
    my $twig = xml2html(file => $file);
    #get expected output HTML
    my $html_file = path($html_dir, $file->basename);
    $html_file =~ s/\.xml/\.htm/;
    my $expected = read_file($html_file, scalar_ref => 1);
    is_string_nows($twig->sprint, $$expected);
}