# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXML2HTML;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::HTML::Differences;

filters {input => 'htmlize', log => [qw(lines chomp array)]};

for my $block(blocks()){
    my ($html, $log) = $block->input;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or note join "\n", @$log;
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
--- input
<xml xmlns:bar="bar.io">
  <bar:foo>
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
      <div title="bar:foo">
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
setting @title of <bar:foo> to 'bar:foo'
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
      <div title="foo" id="bar"></div>
    </div>
  </body>
</html>
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <foo xml:id="bar">
renaming @xml:id of <foo xml:id="bar"> to @id
setting @title of <foo id="bar"> to 'foo'
renaming <foo id="bar"> to <div>
renaming <xml> to <div>
wrapping document in HTML structure

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
      <div title="foo" lang="lut"></div>
    </div>
  </body>
</html>
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <foo>
renaming @xml:lang of <foo> to @lang
setting @title of <foo> to 'foo'
renaming <foo> to <div>
renaming <xml> to <div>
wrapping document in HTML structure

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
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
stripping namespaces from <xml>
processing <foo>
renaming @its:translate of <foo> to @translate
setting @title of <foo> to 'foo'
stripping namespaces from <foo>
renaming <foo> to <div>
renaming <xml> to <div>
wrapping document in HTML structure

=== its:dir
ltr/rtl should be converted into a dir att, and
rlo/lro should create an inline bdo element
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <foo xml:id="i1" its:dir="rtl">foo</foo>
  <foo xml:id="i2" its:dir="ltr">foo</foo>
  <foo xml:id="i3" its:dir="lro">foo<bar/></foo>
  <foo xml:id="i4" its:dir="rlo">foo</foo>
  <foo xml:id="i5" its:dir="rlo"><bar>bar</bar></foo>
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
      <div id="i1" title="foo" dir="rtl">foo</div>
      <div id="i2" title="foo" dir="ltr">foo</div>
      <bdo id="i3" title="foo" dir="ltr">foo<span title="bar"></span></bdo>
      <bdo id="i4" title="foo" dir="rtl">foo</bdo>
      <bdo id="i5" title="foo" dir="rtl"><span title="bar">bar</span></bdo>
    </div>
  </body>
</html>
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
stripping namespaces from <xml>
processing <foo xml:id="i1">
renaming @xml:id of <foo xml:id="i1"> to @id
renaming @its:dir of <foo id="i1"> to @dir
setting @title of <foo id="i1"> to 'foo'
stripping namespaces from <foo id="i1">
renaming <foo id="i1"> to <div>
processing <foo xml:id="i2">
renaming @xml:id of <foo xml:id="i2"> to @id
renaming @its:dir of <foo id="i2"> to @dir
setting @title of <foo id="i2"> to 'foo'
stripping namespaces from <foo id="i2">
renaming <foo id="i2"> to <div>
processing <foo xml:id="i3">
renaming @xml:id of <foo xml:id="i3"> to @id
found its:dir=lro; renaming <foo id="i3"> to bdo and adding @dir=ltr
setting @title of <bdo id="i3"> to 'foo'
stripping namespaces from <bdo id="i3">
processing <bar>
setting @title of <bar> to 'bar'
renaming <bar> to <span>
processing <foo xml:id="i4">
renaming @xml:id of <foo xml:id="i4"> to @id
found its:dir=rlo; renaming <foo id="i4"> to bdo and adding @dir=rtl
setting @title of <bdo id="i4"> to 'foo'
stripping namespaces from <bdo id="i4">
processing <foo xml:id="i5">
renaming @xml:id of <foo xml:id="i5"> to @id
found its:dir=rlo; renaming <foo id="i5"> to bdo and adding @dir=rtl
setting @title of <bdo id="i5"> to 'foo'
stripping namespaces from <bdo id="i5">
processing <bar>
setting @title of <bar> to 'bar'
renaming <bar> to <span>
renaming <xml> to <div>
wrapping document in HTML structure

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
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
stripping namespaces from <xml>
processing <foo>
Replacing @its:person of <foo> with its-person
setting @title of <foo> to 'foo'
stripping namespaces from <foo>
renaming <foo> to <div>
processing <bar>
Replacing @its:locNote of <bar> with its-loc-Note
setting @title of <bar> to 'bar'
stripping namespaces from <bar>
renaming <bar> to <div>
processing <baz>
Replacing @its:blahBlahFooBar of <baz> with its-blah-Blah-Foo-Bar
setting @title of <baz> to 'baz'
stripping namespaces from <baz>
renaming <baz> to <div>
renaming <xml> to <div>
wrapping document in HTML structure

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
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
stripping namespaces from <xml>
placing <its:locQualityIssues xml:id="lq1"> in script element
placing <its:provenanceRecords xml:id="pr1"> in script element
renaming <xml> to <div>
wrapping document in HTML structure

=== its:span
<its:span> are just converted to <span>
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:span its:person="Boss">Pointy Hair</its:span>
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
      <span title="its:span" its-person="Boss">Pointy Hair</span>
    </div>
  </body>
</html>
--- log
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
stripping namespaces from <xml>
processing <its:span>
Replacing @its:person of <its:span> with its-person
setting @title of <its:span> to 'its:span'
stripping namespaces from <its:span>
renaming <xml> to <div>
wrapping document in HTML structure
