# Test Node methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 61;
use Test::NoWarnings;
use Test::Exception;

use ITS::DOM;

use Path::Tiny;
use FindBin qw($Bin);

my $dom_path = path($Bin, 'corpus', 'XML', 'dom_test.xml');
my $dom = ITS::DOM->new( 'xml' => $dom_path );

test_type_name_value($dom);
test_path($dom);
test_xpath($dom);
test_node_namespaces($dom);
test_unique_key($dom);
test_copy($dom);
test_family($dom);

# test types, names and values of all types of nodes
# (and test quite a bit of XPath functionality in the process)
sub test_type_name_value {
    my ($dom) = @_;
    note 'testing type, name and value';
    my @nodes = $dom->get_root->get_xpath('//*');
    is(scalar @nodes, 8, '8 nodes in doc');
    is($nodes[0]->name, 'xml', 'First element name is "xml"');
    is($nodes[0]->type, 'ELT', 'XML node is an ELT');

    is($nodes[1]->name, 'second', 'Second element is "second"');

    is($nodes[5]->name, 'foo:sixth', 'Sixth element is "foo:sixth"');

    @nodes = $nodes[0]->children;
    is(scalar @nodes, 15, '15 children of root');
    is($nodes[0]->name, '#text', 'first child of root is text');
    is($nodes[1]->name, 'second', 'second child of root is "second"');

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
    return;
}

#test generated xpath values
sub test_path {
    my ($dom) = @_;

    is($dom->get_root->doc_node->path, '/', 'path to document node');

    my ($root) = $dom->get_root->get_xpath('/*');
    my @nodes = $root->children;
    is($nodes[0]->path, '/xml/text()[1]', 'path to first text');
    is($nodes[1]->path, '/xml/second', 'path to "second" element');
    my ($comment) = $dom->get_root->get_xpath('//comment()');
    is($comment->path, '/xml/comment()', 'path to comment')
}

#test specifics of XPath context setting along with error handling
sub test_xpath {
    my ($dom) = @_;
    note 'testing XPath context and error handling';

    # check that error message contains this file (02-node.t), but
    # not Node.pm
    throws_ok {
        $dom->get_root->get_xpath(
            '$foo');
    } qr/Failed evaluating XPath:.*evaluation failed at (?:(?!Node.pm).)*02-node.t/s,
        'dies for non-existent variable';

    subtest 'string parameters' => sub {
        plan tests => 3;
        my @nodes = $dom->get_root->get_xpath(
            '$foo', params => {foo => 'foo-bar'} );
        is(scalar @nodes, 1, '1 node returned');
        is($nodes[0]->type, 'LIT', '...is a text value');
        is($nodes[0]->value, 'foo-bar', '...with the correct value');
    };

    subtest 'position' => sub {
        plan tests => 3;
        my @nodes = $dom->get_root->get_xpath(
            'position()', position => 3 , size=> 4 );
        is(scalar @nodes, 1, '1 node returned');
        is($nodes[0]->type, 'NUM', '...is a number');
        is($nodes[0]->value, 3, '...with the correct value');
    };

    subtest 'size' => sub {
        plan tests => 3;
        my @nodes = $dom->get_root->get_xpath(
            'last()', size=> 4 );
        is(scalar @nodes, 1, '1 node returned');
        is($nodes[0]->type, 'NUM', '...is a number');
        is($nodes[0]->value, 4, '...with the correct value');
    };

    subtest 'namespace' => sub {
        plan tests => 2;
        my @nodes = $dom->get_root->get_xpath(
            '//xyz:eighth',
            namespaces => { xyz => 'www.foo.com' }
        );
        is(scalar @nodes, 1, '1 node returned');
        is($nodes[0]->name, 'bar:eighth', '...named "bar:eighth"');
    };

    todo:{
        local $TODO = 'LibXML cannot remove namespaces in context node scope';
        my @nodes = $dom->get_root->get_xpath('//foo:sixth', namespaces => {});
        is(scalar @nodes, 0, 'no foo: element found when no namespaces provided');
    }
    return;
}

# test node methods involving namespaces
sub test_node_namespaces {
    my ($dom) = @_;

    note 'Testing node namespace methods';
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

    is($dom->get_root->namespace_URI, '',
        'empty namespace returned as empty string');

    @nodes = $dom->get_root->get_xpath('//foo:sixth');
    is($nodes[0]->namespace_URI, 'www.bar.com', 'Correct namespace');
    return;
}

sub test_unique_key {
    my ($dom) = @_;

    note 'testing unique_key';
    my $third = ($dom->get_root->get_xpath('//third'))[0];
    my $third_2 = ($dom->get_root->get_xpath('//third'))[0];
    ok($third != $third_2, 'two separate objects to represent the same node');
    is($third->unique_key, $third_2->unique_key, '...have the same unique key');

    my ($ns_1) = $dom->get_root->get_xpath('/*/namespace::*[name()="foo"]');
    my ($ns_2) = $dom->get_root->get_xpath('/*/namespace::*[name()="foo"]');
    ok($ns_1 != $ns_2, 'two separate objects to represent the same namespace');
    is($ns_1->unique_key, $ns_2->unique_key, '...have the same unique key');
}

sub test_copy {
    my ($dom) = @_;

    note 'testing copy';
    my $third = ($dom->get_root->get_xpath('//third'))[0];

    my $copy = $third->copy(0);
    ok($third->unique_key != $copy->unique_key, 'new node created');
    ok($copy->name eq 'third', 'new node has correct name');
    ok($copy->children == 0, 'no children copied');

    $copy = $third->copy();
    ok($third->unique_key != $copy->unique_key, 'new node created');
    ok($copy->name eq 'third', 'new node has correct name');
    ok($copy->children == 0, 'no children copied (default behavior)');

    $copy = $third->copy(1);
    ok($third->unique_key != $copy->unique_key, 'new node created');
    ok($copy->name eq 'third', 'new node has correct name');
    ok($copy->children != 0, 'children also copied');
}

sub test_family {
    my ($dom) = @_;
    note 'testing parent, siblings, and owning document';
    my $third = ($dom->get_root->get_xpath('//third'))[0];

    is($third->parent->name, 'xml', 'element parent retrieved');
    is($third->prev_sibling->name, '#text', 'previous sibling retrieved');
    is($third->next_sibling->name, '#text', 'next sibling retrieved');

    my $root = $dom->get_root;
    #first parent is DOC node, which has no parent
    is($root->parent->parent, undef, 'no parent of document');
    is($root->prev_sibling, undef, 'no previous sibling of root');
    is($root->next_sibling, undef, 'no next sibling of root');

    my $doc_node = $third->doc_node;
    is($doc_node->type, 'DOC', 'Retrieved owning document');
}
