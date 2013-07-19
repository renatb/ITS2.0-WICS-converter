# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXML2HTML;
plan tests => 0+blocks();
use Test::XML;

filters {input => 'htmlize'};

for my $block(blocks()){
    is_xml($block->input, $block->expected, $block->name);
    # print ${$block->input};
}

__DATA__
=== html skeleton
--- input
<xml/>
--- expected
<html>
  <head>
    <meta charset="utf-8"/>
    <title>WICS</title>
  </head>
  <body>
    <div title="xml"/>
  </body>
</html>
=== correct div and span
--- SKIP
--- input
<xml>
  <stuff/>
  <foo><i>some stuff</i></foo>
</xml>
--- expected
<div title="xml">
  <div title="stuff"/>
  <div title="foo"><span title="i">some stuff</span></div>
</div>
=== xml:id
should be converted into id
--- SKIP
--- input
<xml>
  <foo xml:id="bar"/>
</xml>
--- expected
<