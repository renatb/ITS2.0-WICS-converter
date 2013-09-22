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
    my $html = $block->input;
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
    <div title="xliff">
      <div title="trans-unit">
        <p class="ITS_LABEL ITS_EMPTY_TARGET" id="ITS_1">Target is empty</p>
        <p title="source">foo</p>
        <p title="target"></p>
      </div>
    </div>

=== duplicate <target> element with same ITS metadata
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <trans-unit>
    <source translate="no">foo</source>
    <target>foo</target>
  </trans-unit>
  <trans-unit>
    <source>foo<mrk translate="yes">stuff</mrk></source>
    <target>foo<mrk translate="yes">stuff</mrk></target>
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
    <div title="xliff">
      <div title="trans-unit">
        <p title="source" translate="no">foo</p>
        <p title="target">foo</p>
      </div>
      <div title="trans-unit">
        <p class="ITS_LABEL ITS_DUP_TARGET" id="ITS_1">
            Target is duplicate of source with the same ITS metadata inside</p>
        <p title="source">
            foo
            <span title="mrk" translate="yes">stuff</span>
        </p>
        <p title="target">
            foo
            <span title="mrk" translate="yes">stuff</span>
        </p>
      </div>
    </div>
