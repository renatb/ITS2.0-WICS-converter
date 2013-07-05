# Test DOM implementation

use strict;
use warnings;
use ITS::DOM;
use Test::More 0.88;
plan tests => 26;
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
is(scalar @nodes, 5, '5 nodes in doc');
is($nodes[0]->name, 'xml', 'First element name is "xml"');
is($nodes[0]->type, 'ELT', 'XML node is an ELT');

is($nodes[1]->name, 'second', 'Second element is "second"');
is($nodes[1]->att('foo'), 'bar', 'value of "foo" is bar');

is($nodes[4]->name, 'fifth', 'Fifth element is "fifth"');
is_deeply(
    $nodes[4]->atts,
    {baz => 'qux', boo => 'far'},
    'attributes of fifth element');

@nodes = @{$nodes[0]->children};
is(scalar @nodes, 3, '3 children of root');
is($nodes[0]->name, 'second', 'first child of root is "second"');

@nodes = $dom->get_xpath('//@*');
is(scalar @nodes, 4, '4 attribute nodes in doc');
is($nodes[1]->type, 'ATT', 'Attribute type is "ATT"');
is($nodes[1]->name, 'foo', 'First attribute name is "foo"');
is($nodes[1]->value, 'bar', 'First attribute value is "bar"');

@nodes = $dom->get_xpath('//i/text()');
is(scalar @nodes, 1, '1 text node in <i>');
is($nodes[0]->type, 'TXT', 'Attribute type is "ATT"');
is($nodes[0]->value, 'italic', 'Text in <i> is "italic"');

@nodes = $dom->get_xpath('/');
is(scalar @nodes, 1, '1 document node in doc');
is($nodes[0]->type, 'DOC', 'Document type is "DOC"');

TODO: {
    local $TODO = 'XML::XPath doesn\'t implement processing-instruction axis';
    @nodes = $dom->get_xpath('//comment()');
    is(scalar @nodes, 1, '1 comment node in doc');
    # is($nodes[0]->type, 'COM', 'Comment type is "COM"');
    # is($nodes[0]->value, 'A comment...', 'Text in comment is "A comment..."');
};

TODO: {
    local $TODO = 'XML::XPath doesn\'t implement processing-instruction axis';
    @nodes = $dom->get_xpath('//processing-instruction()');
    is(scalar @nodes, 1, '1 PI node in doc');
    # is($nodes[0]->type, 'PI', 'PI type is "PI"');
    # is($nodes[0]->value, 'some content', 'Content of PI is "some content"');
};

TODO: {
    local $TODO = 'XML::Twig::XPath doesn\'t have a "getNamespaces" method';
    ok(0);
    # @nodes = $dom->get_xpath('/*/namespace::*[name()="foo"]');
    # is(scalar @nodes, 1, '1 namespace node in root');
    # is($nodes[0]->type, 'NS', 'Namespace type is "NS"');
    # is($nodes[0]->value, 'www.bar.com', 'Namespace value is URI');
};
