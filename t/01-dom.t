# Test DOM implementation

use strict;
use warnings;
use ITS::DOM;
use Test::More 0.88;
plan tests => 6;
use Test::Exception;
use Test::NoWarnings;
use Path::Tiny;
use FindBin qw($Bin);
my $corpus_dir = path($Bin, 'corpus');

throws_ok
    {ITS::DOM->new(
        'xml' => path($corpus_dir, 'nonexistent.xml') ) }
    qr/error parsing file.*No such file or directory/s,
    'dies for nonexistent file';
throws_ok
    {ITS::DOM->new(
        'xml' => \'<xml>stuff</xlm>')}
    qr/error parsing string:.*mismatched tag/s,
    'dies for bad XML';

lives_ok{ITS::DOM->new(
    'xml' => \<<'ENDXML')} 'valid XML parses without error';
<xml>
    <first foo="bar"/>
</xml>
ENDXML

my $dom;
lives_ok{$dom = ITS::DOM->new(
    'xml' => path($corpus_dir, 'dom_test.xml') )}
    'valid XML parses without error';

my @nodes = $dom->get_xpath('//*');
is(scalar @nodes, 5, '5 nodes in dom_test.xml');
# use Data::Dumper;
# print Dumper \@nodes;