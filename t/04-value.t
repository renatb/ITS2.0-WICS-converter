# Test Node methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 17;
use Test::NoWarnings;

use XML::ITS::DOM;

my $dom = XML::ITS::DOM->new( 'xml' => \'<xml/>' );

my $el = $dom->get_root;

my ($val) = $dom->get_root->get_xpath('"foo-bar"');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'LIT', '...is a text value');
is($val->value, 'foo-bar', '...with the correct value');
is($val->as_xpath, q{'foo-bar'}, '...with the correct XPath representation');

($val) = $dom->get_root->get_xpath('not(1)');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'BOOL', '...is a boolean node');
ok(!$val->value, '...with a false value');
is($val->as_xpath, 'false()', '...with the correct XPath representation');

($val) = $dom->get_root->get_xpath('true()');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'BOOL', '...is a boolean node');
ok($val->value, '...with a true value');
is($val->as_xpath, 'true()', '...with the correct XPath representation');

($val) = $dom->get_root->get_xpath('52');
is(ref $val, 'XML::ITS::DOM::Value',
    'Value created from literal XPath');
is($val->type, 'NUM', '...is a text node');
is($val->value, 52, '...with the correct value');
is($val->as_xpath, '52', '...with the correct XPath representation');
