# Test DOM implementation

use strict;
use warnings;
use ITS::DOM qw(new_element);
use Test::More 0.88;
plan tests => 57;
use Test::Exception;
use Test::NoWarnings;
use Path::Tiny;
use FindBin qw($Bin);
my $corpus_dir = path($Bin, 'corpus');

test_errors();

my $dom_path = path($corpus_dir, 'dom_test.xml');
my $dom;
lives_ok{$dom = ITS::DOM->new(
    'xml' => $dom_path )}
    'valid XML parses without error';

test_dom_queries($dom);

is($dom->get_base_uri, '' . $dom_path->parent, 'Base URI');

is($dom->get_source, '' . $dom_path, 'Source name');

is($dom->get_root->name, 'xml', 'document root element is "xml"');

test_namespaces($dom);

test_node_creation();

#make sure that errors are thrown for bad input
sub test_errors {
    throws_ok
        {ITS::DOM->new(
            'xml' => path($corpus_dir, 'nonexistent.xml') ) }
        qr/error parsing file.*No such file or directory/s,
        'dies for nonexistent file';
    throws_ok
        {ITS::DOM->new(
            'xml' => \'<xml>stuff</xlm>')}
        qr/error parsing string:.*mismatch/s,
        'dies for bad XML';

    lives_ok{ITS::DOM->new(
        'xml' => \<<'ENDXML')} 'valid XML parses without error';
<xml>
    <first foo="bar"/>
</xml>
ENDXML
}

#test xpath querying and names/values/types of nodes
sub test_dom_queries {
    my ($dom) = @_;
    my @nodes = $dom->get_root->get_xpath('//*');
    is(scalar @nodes, 7, '7 nodes in doc');
    is($nodes[0]->name, 'xml', 'First element name is "xml"');
    is($nodes[0]->type, 'ELT', 'XML node is an ELT');

    is($nodes[1]->name, 'second', 'Second element is "second"');
    is($nodes[1]->att('foo'), 'bar', 'value of "foo" is bar');

    is($nodes[4]->name, 'fifth', 'Fifth element is "fifth"');
    is_deeply(
        $nodes[4]->atts,
        {baz => 'qux', boo => 'far'},
        'attributes of fifth element')
        or note explain $nodes[4]->atts;

    is($nodes[5]->name, 'foo:sixth', 'Sixth element is "foo:sixth"');
    is_deeply(
        $nodes[5]->atts,
        {'foo:stuff' => 'junk'},
        'attributes of sixth element')
        or note explain $nodes[5]->atts;

    @nodes = @{$nodes[0]->children};
    is(scalar @nodes, 5, '5 children of root');
    is($nodes[0]->name, 'second', 'first child of root is "second"');

    @nodes = $dom->get_root->get_xpath('//@*');
    is(scalar @nodes, 4, '4 (non-namespace) attribute nodes in doc')
        or note explain \@nodes;
    is($nodes[0]->type, 'ATT', 'Attribute type is "ATT"');
    is($nodes[0]->name, 'foo', 'First attribute name is "foo"');
    is($nodes[0]->value, 'bar', 'First attribute value is "bar"');

    @nodes = $dom->get_root->get_xpath('//i/text()');
    is(scalar @nodes, 1, '1 text node in <i>');
    is($nodes[0]->type, 'TXT', 'Attribute type is "ATT"');
    is($nodes[0]->value, 'italic', 'Text in <i> is "italic"');

    @nodes = $dom->get_root->get_xpath('/');
    is(scalar @nodes, 1, '1 document node in doc');
    is($nodes[0]->type, 'DOC', 'Document type is "DOC"');

    @nodes = $dom->get_root->get_xpath('//comment()');
    is(scalar @nodes, 1, '1 comment node in doc');
    is($nodes[0]->type, 'COM', 'Comment type is "COM"');
    is($nodes[0]->value, 'A comment...', 'Text in comment is "A comment..."');

    @nodes = $dom->get_root->get_xpath('//processing-instruction()');
    is(scalar @nodes, 1, '1 PI node in doc');
    is($nodes[0]->type, 'PI', 'PI type is "PI"');
    is($nodes[0]->value, 'some content', 'Content of PI is "some content"');

    @nodes = $dom->get_root->get_xpath('/*/namespace::*[name()="foo"]');
    is(scalar @nodes, 1, '1 namespace node in root');
    is($nodes[0]->type, 'NS', 'Namespace type is "NS"');
    is($nodes[0]->value, 'www.bar.com', 'Namespace value is URI');

    todo:{
        local $TODO = 'LibXML cannot remove namespaces in context node scope';
        @nodes = $dom->get_root->get_xpath('//foo:sixth', namespaces => {});
        is(scalar @nodes, 0, 'no foo: element found when no namespaces provided');
    }

    @nodes = $dom->get_root->get_xpath('"foo-bar"');
    is(scalar @nodes, 1, '1 node returned');
    is($nodes[0]->type, 'LIT', '...is a text value');
    is($nodes[0]->value, 'foo-bar', '...with the correct value');

    @nodes = $dom->get_root->get_xpath('not(1)');
    is(scalar @nodes, 1, '1 node returned');
    is($nodes[0]->type, 'BOOL', '...is a boolean node');
    ok(!$nodes[0]->value, '...with the correct value');

    @nodes = $dom->get_root->get_xpath('52');
    is(scalar @nodes, 1, '1 node returned');
    is($nodes[0]->type, 'NUM', '...is a text node');
    is($nodes[0]->value, 52, '...with the correct value');

    #TODO: test XPath parameters
}

sub test_node_creation {
    my $atts = {foo => 'bar', baz => 'qux'};
    my $text = 'some text';
    my $el = new_element('a', $atts, $text);
    is($el->type, 'ELT', 'Successfully created new element');
    is($el->name, 'a', 'Correct element name');
    is_deeply($el->atts, $atts, 'Correct element attributes');
    is($el->text, $text, 'Correct element text');

    my $child = new_element('b');
    $child->paste($el);
    my @nodes = @{$el->children};
    is(scalar @nodes, 1, 'Pasted child present in parent');
    is($nodes[0]->name, 'b', 'Child has correct name');
}

sub test_namespaces {
    my ($dom) = @_;
    my @nodes = $dom->get_root->get_xpath('//seventh');
    is($nodes[0]->name, 'seventh', 'got seventh node');
    is_deeply(
        $nodes[0]->get_namespaces,
        {
            foo   => 'www.bar.com',
            bar   => 'www.foo.com',
        },
        'found namespaces in scope'
    ) or note explain $nodes[0]->get_namespaces;

    @nodes = $dom->get_root->get_xpath('//foo:sixth');
    is($nodes[0]->namespaceURI, 'www.bar.com', 'Correct namespace');
    is(
        $nodes[0]->att('stuff', 'www.bar.com'),
        'junk',
        'Correct att retrieved via name and ns'
    );
}
