# test correct operation of FutureNodeManager class
#test correct operation of the FutureNode class
use strict;
use warnings;
use XML::ITS::DOM;
use Test::More 0.88;
use XML::ITS::WICS::XML2HTML::FutureNodeManager qw(new_manager);
use XML::ITS::WICS::XML2HTML::FutureNode;
plan tests => 13;

my $dom = XML::ITS::DOM->new( xml => \<<'END_XML' );
<xml>
Some text
<foo qux="baz"><!--comment--></foo>
<fuz/>
<bar xmlns:foo="www.foo.com">
    <?foo_pi some text?>
</bar>
</xml>
END_XML

my $manager = new_manager($dom);
is_deeply([$manager->elementals], [], 'no elemental elements after construction');
is($manager->total_futures, 0, 'no FutureNodes after construction');

my $root = $dom->get_root;
my $doc_future = $manager->create_future($root->get_xpath('/'));
my $elt_future = $manager->create_future($root->get_xpath('/*'));
my $com_future = $manager->create_future($root->get_xpath('//comment()'));
my $txt_future = $manager->create_future($root->get_xpath('/xml/text()[1]'));
my $att_future = $manager->create_future($root->get_xpath('//@*'));
my $pi_future = $manager->create_future($root->get_xpath('//processing-instruction()'));
my $ns_future = $manager->create_future($root->get_xpath('//namespace::*'));

# we created 7, but some of them may have stored location information via
# additional new FutureNodes
ok($manager->total_futures >= 9, 'at least futures tracked in manager');

my @futures = (
    $doc_future, $elt_future, $att_future, $com_future,
    $pi_future, $txt_future, $ns_future);

isa_ok($_, 'XML::ITS::WICS::XML2HTML::FutureNode', 'create_future returns a FutureNode')
    for @futures;

my @elementals = $manager->elementals;
subtest 'correct FutureNodes are marked as elemental' => sub {
    plan tests => 4;
    is(scalar @elementals, 3, 'three nodes marked elemental');
    {
        for my $node($pi_future, $ns_future, $att_future){
            ok((grep {$_ == $node } @elementals),
                $node->type . ' FutureNode saved as elemental');
        }

    }
};

#this should do nothing at all, since fuz was never made into a FutureNode
my ($fuz_elt) = $root->get_xpath('//fuz');
$manager->replace_el_future($fuz_elt, $root->get_xpath('//bar'));

# replace the future representing the root element with one representing the foo
# element
my ($foo_elt) = $root->get_xpath('//foo');
$manager->replace_el_future($root->get_xpath('/*'), $foo_elt);
ok($foo_elt->is_same_node($elt_future->new_node), 'replace_el_future works');

subtest 'realize_all method' => sub {
    plan tests => 3;
    $manager->realize_all;
    # make sure that the elemental FutureNodes really created elements in the DOM
    ok($root->get_xpath('//*[@class="_ITS_ATT"]'),
        'element representing attribute was pasted in DOM');
    ok($root->get_xpath('//*[@class="_ITS_PI"]'),
        'element representing processing instruction was pasted in DOM');
    ok($root->get_xpath('//*[@class="_ITS_NS"]'),
        'element representing namespace was pasted in DOM');
}
