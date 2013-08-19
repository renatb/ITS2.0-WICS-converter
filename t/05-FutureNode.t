#test correct operation of the FutureNode class
use strict;
use warnings;
use XML::ITS::DOM;
use Test::More 0.88;
use Test::Base;
use XML::ITS::WICS::LogUtils qw(reset_id);
use XML::ITS::WICS::XML2HTML::FutureNodeManager;
my $future_class = 'XML::ITS::WICS::XML2HTML::FutureNode';
use_ok($future_class);
plan tests => 1 + blocks();

for my $block(blocks()){
    reset_id;
    subtest $block->name => sub {
        my $num_tests = 5;
        $num_tests++ if($block->title);
        $num_tests++ if($block->contents);
        plan tests => $num_tests;

        my $manager = XML::ITS::WICS::XML2HTML::FutureNodeManager->new();
        my $dom = XML::ITS::DOM->new( xml => \($block->doc) );
        my ($node) = $dom->get_root->get_xpath($block->future);
        my $future = $future_class->new($manager, $node, $dom);
        my $new_node = $future->new_node;

        is(!!($future->creates_element),
            !!$block->creates_element, 'correct creates_element value');
        is($future->type, $block->type, 'future type');
        is($new_node->type, $block->new_type, 'type of returned node');
        is($future->new_path, $block->new_path, 'provided path for new node');
        is($new_node->path, $block->long_path, 'full path of new node');
        if($block->title){
            is($new_node->att('title'), $block->title, 'correct title attribute');
        }
        if($block->contents){
            is($new_node->text, $block->contents, 'correct element contents');
        }
    };
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
