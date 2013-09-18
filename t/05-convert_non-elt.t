# Test matching non-elements, which requires the usage of FutureNodes
use strict;
use warnings;
use t::TestXLIFF2HTML;
use Test::More 0.88;
plan tests => 1*blocks();
use Test::HTML::Differences;

filters {
  input => 'htmlize',
  log => [qw(lines chomp array)],
  output => [qw(normalize_html)]
};

for my $block(blocks()){
    my $html = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
}

__DATA__
FutureNode management is used to remember matches and match locations,
even when elements are replaced or nodes are deleted

=== namespaced element match handled properly
Elements are all renamed, so XPaths change accordingly.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//foo:para"
        domainPointer="//content" xmlns:foo="www.foo.com"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
  <content>foo</content>
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
      <its:domainRule xmlns:foo="www.foo.com" selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">Some text</div>
        <div title="content" id="ITS_2">foo</div>
    </div>

=== attribute match handled correctly
All attributes, match or not, are turned into child elements (just testing
match here). This also triggers anti-inheritance rules.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="@content"/>
    </its:rules>
  </head>
  <para content="foo">Some text</para>
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
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          <span
              title="content"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_ATT">
            foo
          </span>
          Some text
        </div>
    </div>

=== multiple matches on one attribute handled correctly
Multiple matches of one attribute should only create one new element.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="@content"/>
      <its:domainRule selector="//para"
        domainPointer="@content"/>
    </its:rules>
  </head>
  <para content="foo">Some text</para>
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
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          <span
              title="content"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_ATT">
            foo
          </span>
          Some text
        </div>
    </div>

=== attribute match on namespaced element handled correctly
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
      xmlns:its="http://www.w3.org/2005/11/its"
      xmlns:foo="foo.com">
      <its:translateRule selector="//foo:para/@content"
        translate="yes"/>
    </its:rules>
  </head>
  <foo:para content="foo" xmlns:foo="foo.com">Some text</foo:para>
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
      <its:translateRule selector="id('ITS_1')" translate="no"/>
      <its:translateRule selector="id('ITS_1')" translate="yes"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para">
          <span
              title="content"
              id="ITS_1"
              its-within-text="no"
              class="_ITS_ATT">
            foo
          </span>
          Some text
        </div>
    </div>

=== comment match handled correctly
Nothing is done to comments. Just need a new XPath for the new document.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="comment()"/>
    </its:rules>
  </head>
  <para>Some text<!--foo--></para>
  <para>Some text<!--foo-->more text</para>
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
      <its:domainRule selector="id('ITS_1')" domainPointer="/*/*[2]/*/*[2]/comment()"/>
      <its:domainRule selector="id('ITS_2')" domainPointer="/*/*[2]/*/*[3]/comment()"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <!--foo-->
        </div>
        <div title="para" id="ITS_2">
          Some text
          <!--foo-->
          more text
        </div>
    </div>

=== PI match handled correctly
PIs are illegal in HTML. They should all be removed. Matched PIs are turned
into child elements, which also triggers anti-inheritance rules.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="processing-instruction()"/>
    </its:rules>
  </head>
  <para>Some text<?foo_pi some content?></para>
  <?bar_pi junk?>
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <span
              title="foo_pi"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_PI">
            some content
          </span>
        </div>
    </div>

=== multiple matches on one PI handled correctly
Multiple matches for one node should only create one new element.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="processing-instruction()"/>
      <its:domainRule selector="//para"
        domainPointer="processing-instruction()"/>
    </its:rules>
  </head>
  <para>Some text<?foo_pi some content?></para>
  <?bar_pi junk?>
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
          <span
              title="foo_pi"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_PI">
            some content
          </span>
        </div>
    </div>

=== PI match handled correctly inside namespaced node
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="processing-instruction()"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com"><?foo_pi some content?></foo:para>
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          <span
              title="foo_pi"
              id="ITS_2"
              its-within-text="no"
              class="_ITS_PI">
            some content
          </span>
        </div>
    </div>

=== text node match handled correctly
Nothing is done to these. Just need a new XPath.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="text()"/>
    </its:rules>
  </head>
  <para>Some text</para>
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
      <its:domainRule selector="id('ITS_1')" domainPointer="/*/*[2]/*/*[2]/text()"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
        </div>
    </div>

=== namespace matches handled correctly
Namespace matches are turned into elements in the document root, which also
triggers anti-inheritance rules.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <span
          title="xmlns:foo"
          class="_ITS_NS"
          its-within-text="no"
          id="ITS_2">www.foo.com</span>
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          Some text
        </div>
    </div>

=== multiple matches on same namespace handled correctly
Multiple matches of same namespace should only create one new element.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0"
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="xml">
        <span
          title="xmlns:foo"
          class="_ITS_NS"
          its-within-text="no"
          id="ITS_2">www.foo.com</span>
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          Some text
        </div>
    </div>

=== namespace match inside namespaced node is handled correctly
Not really sure that namespaced parent makes a difference, but just to be safe,
test it.
--- input
<?xml version="1.0"?>
<bar:xml xmlns:bar="www.bar.com">
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its" xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="namespace::*[name()='foo']"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
</bar:xml>
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
    </its:rules>
    </script>
    <div title="bar:xml">
        <span
          title="xmlns:foo"
          class="_ITS_NS"
          its-within-text="no"
          id="ITS_2">www.foo.com</span>
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">Some text</div>
    </div>

=== document matches handled correctly
Document match stays the same ("/").
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its" xmlns:foo="www.foo.com">
      <its:domainRule selector="//foo:para"
        domainPointer="/"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
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
      <its:domainRule selector="id('ITS_1')" domainPointer="/"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="foo:para" id="ITS_1">
          Some text
        </div>
    </div>

=== namespaced document matches handled correctly
Namespacing probably doesn't make a difference here; just covering the bases.
--- input
<?xml version="1.0"?>
<foo:xml xmlns:foo="www.foo.com">
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="/"/>
    </its:rules>
  </head>
  <para xmlns:foo="www.foo.com">Some text</para>
</foo:xml>
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
      <its:domainRule selector="id('ITS_1')" domainPointer="/"/>
    </its:rules>
    </script>
    <div title="foo:xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">
          Some text
        </div>
    </div>

=== non-ITS, non-xmlns attributes are saved
All document attributes are saved as elements, which also
triggers anti-inheritance rules.
--- input
<?xml version="1.0"?>
<xml>
  <para foo="bar" xmlns="blah">Some text</para>
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
      <its:translateRule selector="id('ITS_1')" translate="no"/>
      </its:rules>
    </script>
    <div title="xml">
        <div title="para">
          <span
            id="ITS_1"
            class="_ITS_ATT"
            its-within-text="no"
            title="foo">bar</span>
          Some text
        </div>
    </div>

=== DOM value match handled correctly
Below idValue is a literal string;
it should just be copied to the final rule.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:idValueRule selector="//para"
        idValue="'p1'"/>
    </its:rules>
  </head>
  <para>Some text</para>
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
      <its:idValueRule selector="id('ITS_1')" idValue="'p1'"/>
    </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>
