#test correct operation of the FutureNode class
use strict;
use warnings;
use XML::ITS::DOM;
use Test::More 0.88;
use Test::Base;
use XML::ITS::WICS::XML2HTML::FutureNodeManager;
my $future_class = 'XML::ITS::WICS::XML2HTML::FutureNode';
use_ok($future_class);
plan tests => 1 + blocks();

for my $block(blocks()){
    subtest $block => sub {
        plan tests => 3;

        my $manager = XML::ITS::WICS::XML2HTML::FutureNodeManager->new();
        my $dom = XML::ITS::DOM->new( xml => \($block->doc) );
        my ($node) = $dom->get_root->get_xpath($block->future);
        my $future = $future_class->new($manager, $node, $dom);
        my $new_node = $future->new_node;

        is($future->type, $block->type, 'future type');
        is($new_node->type, $block->new_type, 'type of returned node');
        is($future->new_path, $block->new_path, 'path of new node');
    };
}

__DATA__
=== ELT node
--- type: ELT
--- new_type: ELT
--- doc
<xml/>
--- future chomp
/xml
--- new_path chomp
id('ITS_1')
