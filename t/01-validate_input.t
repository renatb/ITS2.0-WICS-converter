# Test that 1) certain ITS elements aren't allowed as the document root and
# 2) HTML documents are not accepted
use strict;
use warnings;
use Test::More 0.88;
plan tests => 4;
use Test::Exception;
use ITS::XML2XLIFF;
use Path::Tiny;
use FindBin qw($Bin);

throws_ok {
    my $converter = ITS::XML2XLIFF->new();
    $converter->convert(ITS->new('xml',
        doc => path($Bin, 'corpus', 'external_rules_XML3.xml')));
} qr/cannot process a file with ITS element as.*01-validate_input\.t/is,
    'dies with warning for trying to process file with rules as root';

throws_ok {
    my $converter = ITS::XML2XLIFF->new();
    $converter->convert(ITS->new('xml',
        doc => path($Bin, 'corpus', 'standoff_root.xml')));
} qr/cannot process a file with ITS element as.*01-validate_input\.t/is,
    'dies with warning for trying to process file with standoff as root';

lives_ok {
    my $converter = ITS::XML2XLIFF->new();
    return $converter->convert(ITS->new('xml',
        doc => path($Bin, 'corpus', 'span_root.xml')));
} 'Processing file with its:span as root is ok';

throws_ok {
    my $converter = ITS::XML2XLIFF->new();
    return $converter->convert(
        ITS->new('html', doc => \'<!DOCTYPE html><html>'));
} qr/Cannot process document of type.*01-validate_input\.t/is,
    'dies with warning for trying to HTML file';
