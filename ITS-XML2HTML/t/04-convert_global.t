# Test matching elements globally
use strict;
use warnings;
use t::TestXML2HTML;
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
    eq_or_diff_html($html, $block->output, $block->name);
}

__DATA__
=== single selector of element with id
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:translateRule selector="id('i1')" translate="yes"/>
    </its:rules>
  </head>
  <para xml:id="i1">Some text</para>
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
        <its:translateRule selector="id('i1')" translate="yes"/>
      </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="i1">Some text</div>
    </div>

=== single selector of element without id
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:its="http://www.w3.org/2005/11/its">
      <its:translateRule selector="//para" translate="yes"/>
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
        <its:translateRule selector="id('ITS_1')" translate="yes"/>
      </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>

=== Rule and contents are copied as needed
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:locNoteRule selector="//para" translate="yes">
        <its:locNote>Some note</its:locNote>
      </its:locNoteRule>
    </its:rules>
  </head>
  <para>Some text</para>
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
        <its:locNoteRule selector="id('ITS_1')" translate="yes">
        <its:locNote>Some note</its:locNote>
        </its:locNoteRule>
        <its:locNoteRule selector="id('ITS_2')" translate="yes">
        <its:locNote>Some note</its:locNote>
        </its:locNoteRule>
      </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
        <div title="para" id="ITS_2">Some text</div>
    </div>

=== multiple selectors
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//para"
        domainPointer="//content"/>
    </its:rules>
  </head>
  <para>Some text</para>
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
        <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
      </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
        <div title="content" id="ITS_2">foo</div>
    </div>

=== pointer that matches 0 nodes
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:termRule selector="//para"
        termInfoPointer="//def"
        term="yes"/>
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
        <its:termRule selector="id('ITS_1')" term="yes"/>
      </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>

=== preserveSpaceRule is ignored
preserveSpaceRule has no meaning in HTML, and thus it is not output.
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:preserveSpaceRule selector="//para"
        space="preserve"/>
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
      </its:rules>
    </script>
    <div title="xml">
        <div title="head"></div>
        <div title="para">Some text</div>
    </div>
