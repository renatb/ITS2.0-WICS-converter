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
    <title>WICS</title>
  </head>
  <body>
    <div title="xml"/>
  </body>
</html>
=== paragraph elements
--- SKIP
--- input
<xml>
  <stuff/>
</xml>
--- expected
<div title="xml">
  <div title="stuff"/>
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