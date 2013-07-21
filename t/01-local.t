# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXML2HTML;
plan tests => 0+blocks();
# use Test::XML;
use Test::LongString;
use Test::HTML::Differences;

filters {input => 'htmlize'};

for my $block(blocks()){
    eq_or_diff_html($block->input, $block->expected, $block->name);
    # print ${$block->input};
}

__DATA__
=== html skeleton
--- input
<xml/>
--- expected
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml"></div>
  </body>
</html>

=== correct div and span
--- input
<xml>
  <stuff/>
  <foo>Some <i>stuff</i></foo>
</xml>
--- expected
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="stuff"></div>
      <div title="foo">Some <span title="i">stuff</span></div>
    </div>
  </body>
</html>

=== namespaces stripped
--- input
<xml xmlns:bar="bar.io">
  <bar:foo bar:baz="gunk">
    <qux/>
  </bar:foo>
</xml>
--- expected
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="bar:foo[bar:baz='gunk']">
        <div title="qux"></div>
      </div>
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
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo[xml:id='bar']" id="bar"></div>
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
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo[xml:lang='lut']" lang="lut"></div>
    </div>
  </body>
</html>

=== its:translate
should be converted into translate
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <foo its:translate="no"/>
</xml>
--- expected
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo" translate="no"></div>
    </div>
  </body>
</html>

=== its:dir
ltr/rtl should be converted into a dir att, and
rlo/lro should create an inline bdo element
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <foo its:dir="rtl">foo</foo>
  <foo its:dir="ltr">foo</foo>
  <foo its:dir="lro">foo<bar/></foo>
  <foo its:dir="rlo">foo</foo>
</xml>
--- expected
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo" dir="rtl">foo</div>
      <div title="foo" dir="ltr">foo</div>
      <div title="foo"><bdo dir="lro">foo<span title="bar"></span></bdo></div>
      <div title="foo"><bdo dir="rlo">foo</bdo></div>
    </div>
  </body>
</html>
