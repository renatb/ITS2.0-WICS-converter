# test correct operation of FutureNodeManager class
#test correct operation of the FutureNode class
use strict;
use warnings;
use XML::ITS::DOM;
use Test::More 0.88;
use XML::ITS::WICS::XML2HTML::FutureNodeManager;
use XML::ITS::WICS::XML2HTML::FutureNode;
plan tests => 11;

my $manager = XML::ITS::WICS::XML2HTML::FutureNodeManager->new();

is_deeply([$manager->elementals], [], 'no elemental elements after construction');
is($manager->total_futures, 0, 'no FutureNodes after construction');

my $dom = XML::ITS::DOM->new( xml => \<<'END_XML' );
<xml>
Some text
<foo qux="baz"><!--comment--></foo>
<bar xmlns:foo="www.foo.com">
    <?foo_pi some text?>
</bar>
</xml>
END_XML

my $root = $dom->get_root;
my $doc_future = $manager->create_future($root->get_xpath('/'), $dom);
my $elt_future = $manager->create_future($root->get_xpath('/*'));
my $att_future = $manager->create_future($root->get_xpath('//@*'));
my $com_future = $manager->create_future($root->get_xpath('//comment()'));
my $pi_future = $manager->create_future($root->get_xpath('//processing-instruction()'));
my $txt_future = $manager->create_future($root->get_xpath('/xml/text()[1]'));
my $ns_future = $manager->create_future($root->get_xpath('//namespace::*'), $dom);

#we created 7, and two of those store parents as FutureNodes
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
}