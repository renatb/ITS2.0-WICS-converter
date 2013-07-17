# Test DOM implementation
use strict;
use warnings;
use ITS::DOM qw(new_element);
use Test::More 0.88;
plan tests => 61;
use Test::Exception;
use Test::NoWarnings;
use Path::Tiny;
use FindBin qw($Bin);
my $corpus_dir = path($Bin, 'corpus');

my $dom_path = path($corpus_dir, 'dom_test.xml');
test_errors($dom_path);

my $dom = ITS::DOM->new( 'xml' => $dom_path );

test_dom_props($dom, $dom_path);
test_nodes($dom);
test_xpath($dom);
test_node_namespaces($dom);
test_node_creation();

# make sure that errors are thrown for bad input
# and that none are thrown for good input
sub test_errors {
    my ($dom_path) = @_;

    note 'testing exceptions';
    throws_ok {
        ITS::DOM->new(
            'xml' => path($corpus_dir, 'nonexistent.xml')
        )
    } qr/error parsing file.*No such file or directory/s,
        'dies for nonexistent file';
    throws_ok {
        ITS::DOM->new(
            'xml' => \'<xml>stuff</xlm>'
        )
    } qr/error parsing string:.*mismatch/s,
        'dies for bad XML';

    lives_ok{
        ITS::DOM->new(
            'xml' => \'<xml><first foo="bar"/></xml>'
        )
    } 'valid XML parses without error';

    lives_ok{
        $dom = ITS::DOM->new(
            'xml' => $dom_path,
            'rules' => $dom_path
        )
    } 'valid XML file parses without error' or
        BAIL_OUT "can't test with basic XML file";
}

#test properties of entire document
sub test_dom_props {
    my ($dom, $dom_path) = @_;

    note 'testing DOM properties';
    is($dom->get_base_uri, $dom_path->parent, 'Base URI');
    is($dom->get_source, $dom_path, 'Source name');
    is($dom->get_root->name, 'xml', 'root element');
}

# test methods of all types of nodes (which also requires
# testing quite a bit of XPath functionality)
sub test_nodes {
    my ($dom) = @_;
    note 'testing node methods';
    my @nodes = $dom->get_root->get_xpath('//*');
    is(scalar @nodes, 8, '8 nodes in doc');
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

#test node methods involving namespaces
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
    is(
        $nodes[0]->att('stuff', 'www.bar.com'),
        'junk',
        'Correct att retrieved via name and ns'
    );
}
