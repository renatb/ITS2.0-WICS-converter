# Test Element methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 31;
use Test::NoWarnings;

use XML::ITS::DOM;
use XML::ITS::DOM::Element qw(new_element);

use Path::Tiny;
use FindBin qw($Bin);

my $dom_path = path($Bin, 'corpus', 'dom_test.xml');
my $dom = XML::ITS::DOM->new( 'xml' => $dom_path );

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

    is($nodes[4]->name, 'fifth', 'Working with "fifth" element');
    is_deeply(
        $nodes[4]->atts,
        {baz => 'qux', boo => 'far'},
        'attributes of fifth element')
        or note explain $nodes[4]->atts;

    is($nodes[5]->name, 'foo:sixth', 'Working with "foo:sixth" element');
    is_deeply(
        $nodes[5]->atts,
        {'foo:stuff' => 'junk'},
        'attributes of sixth element')
        or note explain $nodes[5]->atts;
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

    $dom = XML::ITS::DOM->new( 'xml' =>
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

sub test_element_editing {
    my $atts = {foo => 'bar', baz => 'qux'};
    my $text = 'some text';
    my $el = new_element('a', $atts, $text);
    is(ref $el, 'XML::ITS::DOM::Element', 'Created Element object');
    is($el->name, 'a', 'Correct element name');
    is_deeply($el->atts, $atts, 'Correct element attributes');
    is($el->text, $text, 'Correct element text');

    my $new_text = 'new text';
    $el->append_text($new_text);
    is($el->text, "$text$new_text", 'text appended properly');

    $el->set_name('x');
    is($el->name, 'x', 'element name changed to "x"');

    my $child = new_element('b');
    $child->paste($el);
    my @nodes = @{$el->child_els};
    is(scalar @nodes, 1, 'Pasted child present in parent');
    is($nodes[0]->name, 'b', 'Child has correct name');

    $child->remove;
    @nodes = @{$el->child_els};
    is(scalar @nodes, 0, 'Child removed');
    return;
}