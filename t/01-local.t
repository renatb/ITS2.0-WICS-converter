# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXML2HTML;
plan tests => 0+blocks();
use Test::HTML::Differences;

filters {input => 'htmlize'};

for my $block(blocks()){
    eq_or_diff_html($block->input, $block->expected, $block->name);
}

__DATA__
=== html skeleton
--- input
<xml/>
--- expected
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
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
  <bar>Some <b><i>real</i></b> stuff</bar>
</xml>
--- expected
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="stuff"></div>
      <div title="foo">Some <span title="i">stuff</span></div>
      <div title="bar">Some <div title="b"><div title="i">real</div></div> stuff</div>
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
<html xmlns="http://www.w3.org/1999/xhtml">
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
<html xmlns="http://www.w3.org/1999/xhtml">
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
<html xmlns="http://www.w3.org/1999/xhtml">
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
<html xmlns="http://www.w3.org/1999/xhtml">
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
  <foo its:dir="rlo"><foo>bar</foo></foo>
</xml>
--- expected
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo" dir="rtl">foo</div>
      <div title="foo" dir="ltr">foo</div>
      <div title="foo"><bdo dir="ltr">foo<span title="bar"></span></bdo></div>
      <div title="foo"><bdo dir="rtl">foo</bdo></div>
      <div title="foo"><bdo dir="rtl"><span title="foo">bar</span></bdo></div>
    </div>
  </body>
</html>

=== other its:* atts
prefix its- and use dashes instead of camelCasing
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <foo its:person="Boss">Pointy Hair</foo>
  <bar its:locNote="foo">Elbonian</bar>
  <baz its:blahBlahFooBar="qux">that's not a thing...</baz>
</xml>
--- expected
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
  </head>
  <body>
    <div title="xml">
      <div title="foo" its-person="Boss">Pointy Hair</div>
      <div title="bar" its-loc-note="foo">Elbonian</div>
      <div title="baz" its-blah-blah-foo-bar="qux">that's not a thing...</div>
    </div>
  </body>
</html>

=== standoff markup
<script> tags are treated as text, so to ease testing we remove all whitespace
from standoff markup.
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:locQualityIssues xml:id="lq1" xmlns:its="http://www.w3.org/2005/11/its"><its:locQualityIssue locQualityIssueType="misspelling"/></its:locQualityIssues>
  <its:provenanceRecords xml:id="pr1" xmlns:its="http://www.w3.org/2005/11/its"><its:provenanceRecord org="acme-CAT-v2.3"/></its:provenanceRecords>
</xml>
--- expected
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script id="lq1" type="application/its+xml"><its:locQualityIssues xmlns:its="http://www.w3.org/2005/11/its" xml:id="lq1"><its:locQualityIssue locQualityIssueType="misspelling"></its:locQualityIssue></its:locQualityIssues></script>
    <script id="pr1" type="application/its+xml"><its:provenanceRecords xmlns:its="http://www.w3.org/2005/11/its" xml:id="pr1"><its:provenanceRecord org="acme-CAT-v2.3"></its:provenanceRecord></its:provenanceRecords></script>
  </head>
  <body>
    <div title="xml"></div>
  </body>
</html>
