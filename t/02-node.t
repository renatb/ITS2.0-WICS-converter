# Test Node methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 44;

use XML::ITS::DOM;
use Test::Exception;
use Test::NoWarnings;

use Path::Tiny;
use FindBin qw($Bin);

my $corpus_dir = path($Bin, 'corpus');
my $dom_path = path($corpus_dir, 'dom_test.xml');
my $dom = XML::ITS::DOM->new( 'xml' => $dom_path );

test_type_name_value($dom);
test_xpath($dom);
test_node_namespaces($dom);

# test types, names and values of all types of nodes
# (and test quite a bit of XPath functionality in the process)
sub test_type_name_value {
    my ($dom) = @_;
    note 'testing node methods';
    my @nodes = $dom->get_root->get_xpath('//*');
    is(scalar @nodes, 8, '8 nodes in doc');
    is($nodes[0]->name, 'xml', 'First element name is "xml"');
    is($nodes[0]->type, 'ELT', 'XML node is an ELT');

    is($nodes[1]->name, 'second', 'Second element is "second"');

    is($nodes[5]->name, 'foo:sixth', 'Sixth element is "foo:sixth"');

    @nodes = @{$nodes[0]->children};
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

    #node testing file
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
    return;
}

#test specifics of XPath context setting
sub test_xpath {
    my ($dom) = @_;
    note 'testing XPath context creation';
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

    @nodes = $dom->get_root->get_xpath('//foo:sixth');
    is($nodes[0]->namespaceURI, 'www.bar.com', 'Correct namespace');
    return;
}
