# Test that 1) a rules element is not allowed as the document root
# and 2) HTML ITS documents are not allowed
use strict;
use warnings;
use Test::More 0.88;
plan tests => 2;
use Test::Exception;
use ITS;
use ITS::XML2HTML;
use Path::Tiny;
use FindBin qw($Bin);

my $file = path($Bin, 'corpus', 'external_rules_XML3.xml');

throws_ok {
    my $converter = ITS::XML2HTML->new();
    return $converter->convert(ITS->new('xml', doc => $file));
} qr/cannot process a file containing only rules.*-file_reqs\.t/is,
    'dies with warning for trying to process rules-only file';

throws_ok {
    my $converter = ITS::XML2HTML->new();
    return $converter->convert(ITS->new('html', doc => \'<!DOCTYPE html><html>'));
} qr/Cannot process document of type.*-file_reqs\.t/is,
    'dies with warning for trying to process HTML file';
