# test the creation of warning labels in the output document
use strict;
use warnings;
use t::TestXLIFF2HTML;
use Test::More 0.88;
plan tests => 1*blocks();
use Test::HTML::Differences;

filters {
  input => 'htmlize_with_labels',
  log => [qw(lines chomp array)],
  output => [qw(normalize_html)]
};

for my $block(blocks()){
    my ($html) = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name);
}

__DATA__
=== empty <target> element
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <trans-unit>
    <source>foo</source>
    <target></target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:dirRule selector="id('ITS_1')" dir="ltr"/>
        <its:localeFilterRule localeFilterList="*" selector="id('ITS_1')" localeFilterType="include"/>
        <its:translateRule selector="id('ITS_1')" translate="no"/>
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="trans-unit">
        <p class="ITS_LABEL ITS_EMPTY_TARGET" id="ITS_1">Target is empty</p>
        <p title="source">foo</p>
        <p title="target"></p>
      </div>
    </div>

=== duplicate <target> element with same local ITS metadata
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <trans-unit>
    <source translate="no">foo</source>
    <target>foo</target>
  </trans-unit>
  <trans-unit>
    <source translate="no">foo<mrk translate="yes">stuff</mrk></source>
    <target translate="no">foo<mrk translate="yes">stuff</mrk></target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
    <meta charset=utf-8>
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
      <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
      <its:dirRule selector="//@*" dir="ltr"/>
      <its:translateRule selector="//@*" translate="no"/>
      <its:dirRule selector="id('ITS_1')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_1')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_1')" translate="no"/>
      <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title=xliff>
    <div title=trans-unit>
        <p title=source translate="no">foo</p>
        <p title=target>foo</p>
    </div>
    <div title=trans-unit>
        <p class="ITS_LABEL ITS_DUP_TARGET" id=ITS_1>
            Target is duplicate of source with the same ITS metadata inside</p>
        <p title=source translate="no">foo
            <span title=mrk translate="yes">stuff</span></p>
        <p title=target translate="no">foo
            <span title=mrk translate="yes">stuff</span></p>
    </div>
    </div>

=== duplicate <target> element with same global ITS metadata (rule values)
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <its:rules
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:xlf="urn:oasis:names:tc:xliff:document:1.2"
        version="2.0">

    <!--Rules to make source and target differ-->
    <its:translateRule selector="/*/xlf:trans-unit[1]/xlf:source" translate="yes"/>
    <its:translateRule selector="/*/xlf:trans-unit[1]/xlf:target" translate="no"/>
    <!--Rules to make source and target the same-->
    <its:translateRule selector="/*/xlf:trans-unit[2]/xlf:source" translate="yes"/>
    <its:translateRule selector="/*/xlf:trans-unit[2]/xlf:target" translate="yes"/>

    <!--Rules to make source and target differ-->
    <its:translateRule selector="/*/xlf:trans-unit[3]/xlf:source/@foo" translate="yes"/>
    <!--Rules to make source and target the same-->
    <its:translateRule selector="/*/xlf:trans-unit[4]/xlf:source/@foo" translate="yes"/>
    <its:translateRule selector="/*/xlf:trans-unit[4]/xlf:target/@foo" translate="yes"/>
  </its:rules>
  <trans-unit>
    <source>foo</source>
    <target>foo</target>
  </trans-unit>
  <trans-unit>
    <source>foo<mrk>stuff</mrk></source>
    <target>foo<mrk>stuff</mrk></target>
  </trans-unit>
  <trans-unit>
    <source foo="bar">foo</source>
    <target foo="bar">foo</target>
  </trans-unit>
  <trans-unit>
    <source foo="bar">foo</source>
    <target foo="bar">foo</target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:dirRule selector="id('ITS_8')|id('ITS_9')" dir="ltr"/>
        <its:localeFilterRule localeFilterList="*" selector="id('ITS_8')|id('ITS_9')" localeFilterType="include"/>
        <its:translateRule selector="id('ITS_5')|id('ITS_6')|id('ITS_7')|id('ITS_8')|id('ITS_9')" translate="no"/>
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
        <its:translateRule selector="id('ITS_1')" translate="yes"/>
        <its:translateRule selector="id('ITS_2')" translate="no"/>
        <its:translateRule selector="id('ITS_3')" translate="yes"/>
        <its:translateRule selector="id('ITS_4')" translate="yes"/>
        <its:translateRule selector="id('ITS_5')" translate="yes"/>
        <its:translateRule selector="id('ITS_6')" translate="yes"/>
        <its:translateRule selector="id('ITS_7')" translate="yes"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title=xliff>
      <div title=trans-unit>
        <p id="ITS_1" title=source>foo</p>
        <p id="ITS_2" title=target>foo</p>
      </div>
      <div title=trans-unit>
        <p class="ITS_LABEL ITS_DUP_TARGET" id=ITS_8>
          Target is duplicate of source with the same ITS metadata inside</p>
        <p id="ITS_3" title=source>foo<span title=mrk>stuff</span></p>
        <p id="ITS_4" title=target>foo<span title=mrk>stuff</span></p>
      </div>
      <div title=trans-unit>
        <p title=source>
          <span class=_ITS_ATT id=ITS_5 its-within-text=no title=foo>bar</span>
          foo
        </p>
        <p title=target>foo</p>
      </div>
      <div title=trans-unit>
        <p class="ITS_LABEL ITS_DUP_TARGET" id=ITS_9>
          Target is duplicate of source with the same ITS metadata inside</p>
        <p title=source>
          <span class=_ITS_ATT id=ITS_6 its-within-text=no title=foo>bar</span>
            foo</p>
        <p title=target>
          <span class=_ITS_ATT id=ITS_7 its-within-text=no title=foo>bar</span>
          foo</p>
      </div>
    </div>

=== duplicate <target> element with same global ITS metadata (locNote element)
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <its:rules
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:xlf="urn:oasis:names:tc:xliff:document:1.2"
        version="2.0">

    <!--Rules to make source and target differ-->
    <its:locNoteRule selector="/*/xlf:trans-unit[1]/xlf:source">
      <its:locNote>note1</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="/*/xlf:trans-unit[1]/xlf:target">
      <its:locNote>note2</its:locNote>
    </its:locNoteRule>

    <!--Rules to make source and target the same-->
    <its:locNoteRule selector="/*/xlf:trans-unit[2]/xlf:source">
      <its:locNote>note1</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="/*/xlf:trans-unit[2]/xlf:target">
      <its:locNote>note1</its:locNote>
    </its:locNoteRule>
  </its:rules>
  <trans-unit>
    <source>foo</source>
    <target>foo</target>
  </trans-unit>
  <trans-unit>
    <source>foo<mrk>stuff</mrk></source>
    <target>foo<mrk>stuff</mrk></target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
<meta charset=utf-8>
<title>WICS</title>
<script type="application/its+xml">
  <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
    <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
    <its:dirRule selector="//@*" dir="ltr"/>
    <its:translateRule selector="//@*" translate="no"/>
    <its:dirRule selector="id('ITS_5')" dir="ltr"/>
    <its:localeFilterRule localeFilterList="*" selector="id('ITS_5')" localeFilterType="include"/>
    <its:translateRule selector="id('ITS_5')" translate="no"/>
    <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
    <its:locNoteRule selector="id('ITS_1')">
      <its:locNote>note1</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="id('ITS_2')">
      <its:locNote>note2</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="id('ITS_3')">
      <its:locNote>note1</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="id('ITS_4')">
      <its:locNote>note1</its:locNote>
    </its:locNoteRule>
  </its:rules>
</script>
<style>body {visibility:hidden} p {visibility: visible}</style>
<div title=xliff>
  <div title=trans-unit>
    <p id=ITS_1 title=source>foo</p>
    <p id=ITS_2 title=target>foo</p>
  </div>
  <div title=trans-unit><p class="ITS_LABEL ITS_DUP_TARGET" id=ITS_5>Target is duplicate of source with the same ITS metadata inside</p>
    <p id=ITS_3 title=source>foo<span title=mrk>stuff</span></p>
    <p id=ITS_4 title=target>foo<span title=mrk>stuff</span></p>
  </div>
</div>

=== duplicate <target> element with same global ITS metadata (Value pointers)
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <its:rules
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:xlf="urn:oasis:names:tc:xliff:document:1.2"
        version="2.0">
    <!--Rules to make source and target differ-->
    <its:idValueRule selector="/*/xlf:trans-unit[1]/xlf:source" idValue="'foo'"/>
    <its:idValueRule selector="/*/xlf:trans-unit[1]/xlf:target" idValue="'bar'"/>
    <!--Rules to make source and target the same-->
    <its:idValueRule selector="/*/xlf:trans-unit[2]/xlf:source" idValue="'foo'"/>
    <its:idValueRule selector="/*/xlf:trans-unit[2]/xlf:target" idValue="'foo'"/>
  </its:rules>
  <trans-unit>
    <source>foo</source>
    <target>foo</target>
  </trans-unit>
  <trans-unit>
    <source>foo<mrk>stuff</mrk></source>
    <target>foo<mrk>stuff</mrk></target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:dirRule selector="id('ITS_5')" dir="ltr"/>
        <its:localeFilterRule localeFilterList="*" selector="id('ITS_5')" localeFilterType="include"/>
        <its:translateRule selector="id('ITS_5')" translate="no"/>
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
        <its:idValueRule selector="id('ITS_1')" idValue="'foo'"/>
        <its:idValueRule selector="id('ITS_2')" idValue="'bar'"/>
        <its:idValueRule selector="id('ITS_3')" idValue="'foo'"/>
        <its:idValueRule selector="id('ITS_4')" idValue="'foo'"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title=xliff>
      <div title=trans-unit>
        <p id="ITS_1" title=source>foo</p>
        <p id="ITS_2" title=target>foo</p>
      </div>
      <div title=trans-unit>
        <p class="ITS_LABEL ITS_DUP_TARGET" id=ITS_5>
          Target is duplicate of source with the same ITS metadata inside</p>
        <p id="ITS_3" title=source>foo<span title=mrk>stuff</span></p>
        <p id="ITS_4" title=target>foo<span title=mrk>stuff</span></p>
      </div>
    </div>

=== duplicate <target> element with same global ITS metadata (node pointers)
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <its:rules
        xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:xlf="urn:oasis:names:tc:xliff:document:1.2"
        version="2.0">

    <!--Rules to make source and target differ slightly-->
    <its:storageSizeRule selector="/*/xlf:trans-unit[1]/xlf:source"
        storageSizePointer="id('m1')/@foo"
        storageEncodingPointer="id('m1')/@qux"/>
    <its:storageSizeRule selector="/*/xlf:trans-unit[1]/xlf:target"
        storageSizePointer="id('m1')/@qux"
        storageEncodingPointer="id('m1')/@foo"/>

    <!--Rules to make source and target ITS the same-->
    <its:storageSizeRule selector="/*/xlf:trans-unit[2]/xlf:source"
        storageSizePointer="id('m1')/@foo"
        storageEncodingPointer="id('m1')/@qux"/>
    <its:storageSizeRule selector="/*/xlf:trans-unit[2]/xlf:target"
        storageSizePointer="id('m1')/@foo"
        storageEncodingPointer="id('m1')/@buff"/>

  </its:rules>
  <mrk foo="bar" qux="baz" buff="baz" xml:id="m1"/>
  <trans-unit>
    <source>foo</source>
    <target>foo</target>
  </trans-unit>
  <trans-unit>
    <source>foo<mrk>stuff</mrk></source>
    <target>foo<mrk>stuff</mrk></target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
  <meta charset=utf-8>
  <title>WICS</title>
  <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
      <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
      <its:dirRule selector="//@*" dir="ltr"/>
      <its:translateRule selector="//@*" translate="no"/>
      <its:dirRule selector="id('ITS_8')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_8')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')|id('ITS_3')|id('ITS_7')|id('ITS_8')" translate="no"/>
      <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      <its:storageSizeRule selector="id('ITS_1')" storageSizePointer="id('ITS_2')" storageEncodingPointer="id('ITS_3')"/>
      <its:storageSizeRule selector="id('ITS_4')" storageSizePointer="id('ITS_3')" storageEncodingPointer="id('ITS_2')"/>
      <its:storageSizeRule selector="id('ITS_5')" storageSizePointer="id('ITS_2')" storageEncodingPointer="id('ITS_3')"/>
      <its:storageSizeRule selector="id('ITS_6')" storageSizePointer="id('ITS_2')" storageEncodingPointer="id('ITS_7')"/>
    </its:rules>
  </script>
  <style>body {visibility:hidden} p {visibility: visible}</style>
  <div title=xliff>
    <span id="m1" title="mrk">
      <span class=_ITS_ATT id=ITS_3 its-within-text=no title=qux>baz</span>
      <span class=_ITS_ATT id=ITS_2 its-within-text=no title=foo>bar</span>
      <span class=_ITS_ATT id=ITS_7 its-within-text=no title=buff>baz</span>
    </span>
    <div title=trans-unit>
      <p id=ITS_1 title=source>foo</p>
      <p id=ITS_4 title=target>foo</p>
    </div>
    <div title=trans-unit>
      <p class="ITS_LABEL ITS_DUP_TARGET" id=ITS_8>
        Target is duplicate of source with the same ITS metadata inside</p>
      <p id=ITS_5 title=source>foo<span title=mrk>stuff</span></p>
      <p id=ITS_6 title=target>foo<span title=mrk>stuff</span></p>
    </div>
  </div>
