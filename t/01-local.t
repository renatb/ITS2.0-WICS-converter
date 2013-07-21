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
      <div title="foo"><bdo dir="ltr">foo<span title="bar"></span></bdo></div>
      <div title="foo"><bdo dir="rtl">foo</bdo></div>
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
<html>
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
prefix its- and use dashes instead of camelCasing
--- ONLY
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:locQualityIssues xml:id="lq1" xmlns:its="http://www.w3.org/2005/11/its">
    <its:locQualityIssue locQualityIssueType="misspelling"/>
  </its:locQualityIssues>
  <its:provenanceRecords xml:id="pr1" xmlns:its="http://www.w3.org/2005/11/its">
    <its:provenanceRecord
     org="acme-CAT-v2.3"/>
  </its:provenanceRecords>
</xml>
--- expected
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type=application/its+xml id=lq1>
      <its:locQualityIssues xml:id="lq1">
        <its:locQualityIssue locQualityIssueType="misspelling"/>
      </its:locQualityIssues>
    </script>
    <script type=application/its+xml id=lq1>
      <its:provenanceRecords xml:id="pr1">
        <its:provenanceRecord
         org="acme-CAT-v2.3"/>
      </its:provenanceRecords>
    </script>
  </head>
  <body>
    <div title="xml"></div>
  </body>
</html>
