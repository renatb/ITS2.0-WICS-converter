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
--- input
<xml>
  <stuff/>
  <foo>Some <i>stuff</i></foo>
</xml>
--- expected
<html>
  <head>
    <title>WICS</title>
    <meta charset="utf-8"/>
  </head>
  <body>
    <div title="xml">
      <div title="stuff"/>
      <div title="foo">Some <span title="i">stuff</span></div>
    </div>
  </body>
</html>

=== xml:id
should be converted into id
--- input
<xml>
  <foo xml:id="bar"/>
</xml>
--- expected
<html>
  <head>
    <meta charset="utf-8"/>
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo[xml:id='bar']" id="bar"/>
    </div>
  </body>
</html>

=== xml:lang
should be converted into lang
--- input
<xml>
  <foo xml:lang="lut"/>
</xml>
--- expected
<html>
  <head>
    <meta charset="utf-8"/>
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo[xml:lang='lut']" lang="lut"/>
    </div>
  </body>
</html>