# Test Node methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 10;
use Test::NoWarnings;

use XML::ITS::DOM;

my $dom = XML::ITS::DOM->new( 'xml' => \'<xml/>' );

my $el = $dom->get_root;

my ($val) = $dom->get_root->get_xpath('"foo-bar"');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'LIT', '...is a text value');
is($val->value, 'foo-bar', '...with the correct value');

($val) = $dom->get_root->get_xpath('not(1)');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'BOOL', '...is a boolean node');
ok(!$val->value, '...with the correct value');

($val) = $dom->get_root->get_xpath('52');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'NUM', '...is a text node');
is($val->value, 52, '...with the correct value');
