# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXML2HTML;
plan tests => 1*blocks();
use Test::HTML::Differences;

filters {
  input => 'htmlize',
  output => [qw(normalize_html)]
};

for my $block(blocks()){
    my $html = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name);
}

__DATA__
=== html skeleton
Tests basic conversion of root element into <div>, placing contents into an
HTML skeleton, and creating default rules.
--- input
<xml/>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
  <div title="xml"></div>

=== correct div and span
--- input
<xml>
  <stuff/>
  <foo>Some <i>stuff</i></foo>
  <bar>Some <b><i>real</i></b> stuff</bar>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="stuff"></div>
      <div title="foo">Some <span title="i">stuff</span></div>
      <div title="bar">Some <span title="b"><span title="i">real</span></span> stuff</div>
    </div>

=== namespaces stripped
--- input
<xml xmlns:bar="bar.io">
  <bar:foo>
    <qux/>
  </bar:foo>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="bar:foo">
        <div title="qux"></div>
      </div>
    </div>

=== xml:id
should be converted into id
--- input
<xml>
  <foo xml:id="bar"/>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo" id="bar"></div>
    </div>

=== xml:space
should be removed, having no HTML equivalent
--- input
<xml>
  <foo xml:space="preserve"/>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo"></div>
    </div>

=== xml:lang
should be converted into lang
--- input
<xml>
  <foo xml:lang="lut"/>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo" lang="lut"></div>
    </div>

=== its:translate
should be converted into translate
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <foo its:translate="no"/>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo" translate="no"></div>
    </div>

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
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div id="i1" title="foo" dir="rtl">foo</div>
      <div id="i2" title="foo" dir="ltr">foo</div>
      <bdo id="i3" title="foo" dir="ltr">foo<span title="bar"></span></bdo>
      <bdo id="i4" title="foo" dir="rtl">foo</bdo>
      <bdo id="i5" title="foo" dir="rtl"><span title="bar">bar</span></bdo>
    </div>

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
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo" its-person="Boss">Pointy Hair</div>
      <div title="bar" its-loc-note="foo">Elbonian</div>
      <div title="baz" its-blah-blah-foo-bar="qux">that's not a thing...</div>
    </div>

=== standoff markup
Test that standoff markup is pasted into a <script> element
in the head.
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:locQualityIssues xml:id="lq1" xmlns:its="http://www.w3.org/2005/11/its"><its:locQualityIssue locQualityIssueType="misspelling"/></its:locQualityIssues>
  <its:provenanceRecords xml:id="pr1" xmlns:its="http://www.w3.org/2005/11/its"><its:provenanceRecord org="acme-CAT-v2.3"/></its:provenanceRecords>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script id="lq1" type="application/its+xml"><its:locQualityIssues xmlns:its="http://www.w3.org/2005/11/its" xml:id="lq1"><its:locQualityIssue locQualityIssueType="misspelling"/></its:locQualityIssues></script>
    <script id="pr1" type="application/its+xml"><its:provenanceRecords xmlns:its="http://www.w3.org/2005/11/its" xml:id="pr1"><its:provenanceRecord org="acme-CAT-v2.3"/></its:provenanceRecords></script>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml"></div>

=== its:span
<its:span> are just converted to <span>; attributes need
special handling, though, because all of them are ITS
but don't have the namespace associated with them.
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:span
      person="Boss"
      locNote="foo"
      xml:id="a"
      translate="no"
      dir="ltr"
      >Pointy Hair</its:span>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
      <span
          title="its:span"
          its-person="Boss"
          its-loc-note="foo"
          translate="no"
          id="a"
          dir="ltr">
        Pointy Hair</span>
    </div>

=== its:version
its:version should be deleted (doesn't exist in its HTML)
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  hello
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:withinTextRule selector="//h:span" withinText="no"/>
      </its:rules>
    </script>
    <div title="xml">
     hello
    </div>
