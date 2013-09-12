# Test Element methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 51;
use Test::NoWarnings;

use ITS::DOM;
use ITS::DOM::Element qw(new_element);

use Path::Tiny;
use FindBin qw($Bin);

my $dom_path = path($Bin, 'corpus', 'XML', 'dom_test.xml');
my $dom = ITS::DOM->new( 'xml' => $dom_path );

test_atts($dom);
test_equality($dom);
test_namespaces($dom);
test_inlininess($dom);
test_element_editing();

# test element attribute methods
sub test_atts {
    my ($dom) = @_;
    my @nodes = $dom->get_root->get_xpath('//*');

    is($nodes[1]->name, 'second', 'Working with "second" element');
    is($nodes[1]->att('foo'), 'bar', 'value of "foo" is bar');

    $nodes[1]->remove_att('foo');
    is($nodes[1]->att('foo'), undef, 'foo attribute removed');
    $nodes[1]->set_att('foo', 'bar');
    is($nodes[1]->att('foo'), 'bar', 'value of "foo" set to bar');


    is($nodes[4]->name, 'fifth', 'Working with "fifth" element');
    is_deeply(
        $nodes[4]->atts,
        {baz => 'qux', boo => 'far'},
        'attributes of fifth element')
        or note explain $nodes[4]->atts;

    my $bar_ns = 'www.bar.com';
    is($nodes[5]->name, 'foo:sixth', 'Working with "foo:sixth" element');
    is_deeply(
        $nodes[5]->atts,
        {'foo:stuff' => 'junk'},
        'attributes of sixth element')
        or note explain $nodes[5]->atts;

    is($nodes[5]->att('stuff', $bar_ns),
        'junk', 'attribute retrieved via name and namespace');

    $nodes[5]->remove_att('stuff', $bar_ns);
    is($nodes[5]->att('stuff', $bar_ns),
        undef, 'attribute removed via name and namespace');

    $nodes[5]->set_att('stuff', 'junk', $bar_ns);
    is($nodes[5]->att('stuff', $bar_ns),
        'junk', 'attribute set via name and namespace');
    return;
}

sub test_equality {
    my ($dom) = @_;

    my ($el) = $dom->get_root->get_xpath('//i');
    my ($el2) = $dom->get_root->get_xpath('//third');

    ok(!$el->is_same_node($el2), 'two elements are different');
    ok($el->is_same_node($el), 'element is equal to itself');
}

#test node methods involving namespaces
sub test_namespaces {
    my ($dom) = @_;

    my ($el) = $dom->get_root->get_xpath('//seventh');
    is($el->name, 'seventh', 'working with "seventh" node');
    is_deeply(
        $el->get_ns_declarations,
        {
            bar => 'www.foo.com',
        },
        'found namespace declaration on element'
    ) or note explain $el->get_namespace_decl;
    my $new_el = $el->strip_ns;
    ok(!$el->is_same_node($new_el),
        'new element created for element with ns declaration');

    ($el) = $dom->get_root->get_xpath('//third');
    $new_el = $el->strip_ns;
    ok($el->is_same_node($new_el),
        'no element created for element without ns declaration');


    ($el) = $dom->get_root->get_xpath('//foo:sixth');
    is(
        $el->att('stuff', 'www.bar.com'),
        'junk',
        'Correct att retrieved via name and ns'
    );

    $dom = ITS::DOM->new( 'xml' =>
        \'<foo:xml foo:bar="qux" xmlns:foo="foo.io">
            <foo:baz/>
            stuff
            # <?pi foo?>
            <!--foo-->
            </foo:xml>' );
    my $root = $dom->get_root;
    my $changed;
    ($root, $changed) = $root->strip_ns;
    is($root->name, 'xml', 'namespace stripped from name');
    is_deeply(
        $root->atts,
        {
            bar => 'qux'
        }, 'namespaces removed from attributes'
    ) or note explain $root->atts;
    ($el) = $root->get_xpath('foo:baz', namespaces => {foo => 'foo.io'});
    ok($el, 'baz still prefixed');
    is_deeply(
        $el->atts,
        {
            'xmlns:foo' => 'foo.io'
        }, 'namespace declaration moved to foo:baz'
    ) or note explain $el->atts;
    return;
}

sub test_inlininess {
    my ($dom) = @_;
    my ($el) = $dom->get_root->get_xpath('//i');
    ok($el->is_inline, '<i> is inline');

    ($el) = $dom->get_root->get_xpath('//third');
    ok($el->is_inline, '<third> is inline');

    ($el) = $dom->get_root->get_xpath('//fifth');
    ok($el->is_inline, '<fifth> is inline');

    ($el) = $dom->get_root->get_xpath('//second');
    ok(!$el->is_inline, '<second> is not inline');
}

# paste is technically a node method,
# but it's easiest to test with elements
sub test_element_editing {
    my $atts = {foo => 'bar', baz => 'qux'};
    my $text = 'some text';
    my $el = new_element('a', $atts, $text);
    is(ref $el, 'ITS::DOM::Element', 'Created Element object');
    is($el->name, 'a', 'Correct element name');
    is_deeply($el->atts, $atts, 'Correct element attributes');
    is($el->text, $text, 'Correct element text');

    # test append_text
    my $new_text = 'new text';
    # default (last_child)
    $el->append_text($new_text);
    is($el->text, "$text$new_text",
        'append_text default (last_child)');
    # last_child
    $el->append_text($new_text, 'last_child');
    is($el->text, "$text$new_text$new_text",
        'append_text last_child');
    # first_child
    $el->append_text($new_text, 'first_child');
    is($el->text, "$new_text$text$new_text$new_text",
        'append_text first_child');

    # create new child and paste it
    my $child = new_element('b');
    $child->paste($el);
    my @nodes = @{$el->child_els};
    is(scalar @nodes, 1, 'Pasted child present in parent');
    is($nodes[0]->name, 'b', 'Child has correct name');

    # finish testing append_text (before and after)
    my $txt_node = $child->append_text($new_text, 'before');
    is($child->prev_sibling->value, "$new_text",
        'text placed before <b>');
    ok($child->prev_sibling->is_same_node($txt_node),
        'created text node is returned');
    $child->append_text($new_text, 'after');
    is($child->next_sibling->value, "$new_text",
        'text placed after <b>');

    # test all positions for paste
    new_element('c')->paste($el);
    is(${$el->child_els}[1]->name, 'c', 'default paste location is last_child');

    new_element('d')->paste($el, 'last_child');
    is(${$el->child_els}[2]->name, 'd', 'paste last_child');

    new_element('e')->paste($el, 'first_child');
    is(${$el->child_els}[0]->name, 'e', 'paste first_child');

    new_element('f')->paste($child, 'before');
    is(${$el->child_els}[1]->name, 'f', 'paste before');

    new_element('g')->paste($child, 'after');
    is(${$el->child_els}[3]->name, 'g', 'paste after');

    is(@{$el->child_els}, 6, '6 children');
    $child->remove;
    is(@{$el->child_els}, 5, '...and then 5 (one removed)');

    $el->set_name('x');
    is($el->name, 'x', 'element name changed to "x"');

    $el = new_element('x');
    $el->set_namespace('foo.com');
    is($el->namespace_URI, 'foo.com', 'set element namespace');
    is($el->name, 'x', 'no namespace prefix added');

    $el->set_namespace('bar.com', 'bar');
    is($el->namespace_URI, 'bar.com', 'set element namespace');
    is($el->name, 'bar:x', 'namespace prefix added');
    return;
}