# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXML2HTML;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::HTML::Differences;

filters {input => 'htmlize', log => [qw(lines chomp debug_log_entries)]};

for my $block(blocks()){
    my ($html, $log) = $block->input;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or note explain $log;
}

__DATA__
=== html skeleton
--- input
<xml/>
--- output
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
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
renaming <xml> to <div>
wrapping document in HTML structure

=== correct div and span
--- input
<xml>
  <stuff/>
  <foo>Some <i>stuff</i></foo>
  <bar>Some <b><i>real</i></b> stuff</bar>
</xml>
--- output
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
      <div title="bar">Some <span title="b"><span title="i">real</span></span> stuff</div>
    </div>
  </body>
</html>
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <stuff>
setting @title of <stuff> to 'stuff'
renaming <stuff> to <div>
processing <foo>
setting @title of <foo> to 'foo'
processing <i>
setting @title of <i> to 'i'
renaming <i> to <span>
renaming <foo> to <div>
processing <bar>
setting @title of <bar> to 'bar'
processing <b>
setting @title of <b> to 'b'
processing <i>
setting @title of <i> to 'i'
renaming <i> to <span>
renaming <b> to <span>
renaming <bar> to <div>
renaming <xml> to <div>
wrapping document in HTML structure

=== namespaces stripped
--- LAST
--- input
<xml xmlns:bar="bar.io">
  <bar:foo bar:baz="gunk">
    <qux/>
  </bar:foo>
</xml>
--- output
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
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
stripping namespaces from <xml>
processing <bar:foo>
setting @title of <bar:foo> to 'bar:foo[bar:baz='gunk']'
stripping namespaces from <bar:foo>
processing <qux>
setting @title of <qux> to 'qux'
renaming <qux> to <div>
renaming <foo> to <div>
renaming <xml> to <div>
wrapping document in HTML structure

=== xml:id
should be converted into id
--- input
<xml>
  <foo xml:id="bar"/>
</xml>
--- output
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
--- output
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
--- output
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
--- output
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
--- output
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
--- output
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
