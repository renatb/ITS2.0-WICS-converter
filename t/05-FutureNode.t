#test correct operation of the FutureNode class
use strict;
use warnings;
use Test::More 0.88;
use Test::Base;
plan tests => 14;
use Test::Exception;

use XML::ITS::DOM;
use XML::ITS::WICS::LogUtils;
use XML::ITS::WICS::XML2HTML::FutureNodeManager qw(new_manager);
use XML::ITS::DOM::Element qw(new_element);
use XML::ITS::WICS::XML2HTML::FutureNode qw(new_future);

#test the storage and retrieval of all 7 types of nodes in a FutureNode.
#use a new FutureNodeManager each time
for my $block(blocks()){
    subtest $block->name => sub {
        my $num_tests = 7;
        $num_tests++ if($block->title);
        $num_tests++ if($block->contents);
        $num_tests++ if($block->class);
        plan tests => $num_tests;

        my ($old_node, $future) = get_future($block);
        my $new_node = $future->new_node;

        my $dup_new_node = $future->new_node;
        ok($new_node->is_same_node($dup_new_node),
            'new_node always returns same node');

        is(!!($future->creates_element),
            !!$block->creates_element, 'correct creates_element value');
        is($future->type, $block->type, 'future type');
        is($new_node->type, $block->new_type, 'type of returned node');
        is($future->new_path, $block->new_path, 'provided path for new node');
        is($new_node->path, $block->long_path, 'full path of new node');
        if($block->title){
            is($new_node->att('title'), $block->title,
                'correct title attribute');
        }
        if($block->contents){
            is($new_node->text, $block->contents,
                'correct element contents');
        }
        if($block->class){
            is($new_node->att('class'), $block->class, 'correct class value');
        }

        $block->creates_element ?
            ok(!$new_node->is_same_node($old_node),
                'new created element is not same as old node')
            :
            ok($new_node->is_same_node($old_node),
                'new node is same as old node');
    };

    if($block->type eq 'ELT'){
        my ($old_node, $future) = get_future($block);
        my $other_node = new_element('foo');
        $future->replace_el($other_node);
        my $new_node = $future->new_node;

        ok($new_node->is_same_node($other_node),
            'replace_el works properly');
    }else{
        my ($old_node, $future) = get_future($block);
        my $msg = 'Attempt to replace element in FutureNode of type ' .
            $block->type;
        throws_ok {
            my $other_node = new_element('foo');
            $future->replace_el($other_node);
        } qr/$msg/s,
            'replace_el dies when given ' . $block->type . ' node';
    }
}

sub get_future {
    my ($block) = @_;
    my $dom = XML::ITS::DOM->new( xml => \($block->doc) );
    my $manager = new_manager($dom);
    my ($node) = $dom->get_root->get_xpath($block->future);
    my $future = new_future($manager, $node, $dom);
    return ($node, $future);
}

__DATA__
=== ELT node
--- type: ELT
--- new_type: ELT
--- doc: <xml/>
--- future: /xml
--- new_path: id('ITS_1')
--- long_path: /xml
--- creates_element: 0

=== ATT node
--- type: ATT
--- new_type: ELT
--- doc: <xml foo="bar"/>
--- future: /xml/@foo
--- new_path: id('ITS_1')
--- long_path: /xml/span
--- creates_element: 1
--- title: foo
--- contents: bar
--- class: _ITS_ATT

=== NS node
--- type: NS
--- new_type: ELT
--- doc
<xml>
    <foo>
        <bar xmlns:foo="www.bar.com"/>
    </foo>
</xml>
--- future: //namespace::*
--- new_path: id('ITS_1')
--- long_path: /xml/span
--- creates_element: 1
--- title: xmlns:foo
--- contents: www.bar.com
--- class: _ITS_NS

=== PI node
--- type: PI
--- new_type: ELT
--- doc
<xml>
    <foo>
        <?foo_pi some text?>
    </foo>
</xml>
--- future: //processing-instruction()
--- new_path: id('ITS_1')
--- long_path: /xml/foo/span
--- creates_element: 1
--- title: foo_pi
--- contents: some text
--- class: _ITS_PI

=== COM node
--- type: COM
--- new_type: COM
--- doc
<xml>
    <foo>
        <!--no comment-->
    </foo>
</xml>
--- future: //comment()
--- new_path: /xml/foo/comment()
--- long_path: /xml/foo/comment()
--- creates_element: 0

=== TXT node
--- type: TXT
--- new_type: TXT
--- doc
<xml>this text<foo>
        not this text!
    </foo>
</xml>
--- future: //text()
--- new_path: /xml/text()[1]
--- long_path: /xml/text()[1]
--- creates_element: 0
--- contents: this text

=== DOC node
--- type: DOC
--- new_type: DOC
--- doc
<xml/>
--- future: /
--- new_path: /
--- long_path: /
--- creates_element: 0
