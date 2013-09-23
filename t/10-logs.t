# Test log output
use strict;
use warnings;
use t::TestXLIFF2HTML;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::HTML::Differences;

filters {
  input => 'html_log_with_labels',
  log => [qw(lines chomp array)],
  output => [qw(normalize_html)]
};

for my $block(blocks()){
    my ($html, $log) = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or note join "\n", @$log;
}

__DATA__
Just test logs for one document.

=== conversion with labels
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
  <trans-unit>
    <source>whatever</source>
    <target see="it's empty"></target>
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
      <its:dirRule selector="id('ITS_8')|id('ITS_9')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_8')|id('ITS_9')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')|id('ITS_3')|id('ITS_7')|id('ITS_8')|id('ITS_9')" translate="no"/>
      <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      <its:storageSizeRule selector="id('ITS_1')" storageSizePointer="id('ITS_2')" storageEncodingPointer="id('ITS_3')"/>
      <its:storageSizeRule selector="id('ITS_4')" storageSizePointer="id('ITS_3')" storageEncodingPointer="id('ITS_2')"/>
      <its:storageSizeRule selector="id('ITS_5')" storageSizePointer="id('ITS_2')" storageEncodingPointer="id('ITS_3')"/>
      <its:storageSizeRule selector="id('ITS_6')" storageSizePointer="id('ITS_2')" storageEncodingPointer="id('ITS_7')"/>
    </its:rules>
  </script>
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
    <div title=trans-unit>
      <p class="ITS_LABEL ITS_EMPTY_TARGET" id="ITS_9">Target is empty</p>
      <p title=source>whatever</p>
      <p title=target></p>
    </div>
  </div>

--- log
match: rule=<its:storageSizeRule>; storageSizePointer=@foo[bar]; selector=<source>; storageEncodingPointer=@qux[baz]
match: rule=<its:storageSizeRule>; storageSizePointer=@qux[baz]; selector=<target>; storageEncodingPointer=@foo[bar]
match: rule=<its:storageSizeRule>; storageSizePointer=@foo[bar]; selector=<source>; storageEncodingPointer=@qux[baz]
match: rule=<its:storageSizeRule>; storageSizePointer=@foo[bar]; selector=<target>; storageEncodingPointer=@buff[baz]
converting document elements into HTML
processing <xliff>
setting @title of <xliff> to 'xliff'
stripping namespaces from <xliff>
removing <its:rules>
processing <mrk xml:id="m1">
renaming @xml:id[m1] of <mrk xml:id="m1"> to @id
setting @title of <mrk id="m1"> to 'mrk'
stripping namespaces from <mrk id="m1">
renaming <mrk id="m1"> to <span>
processing <trans-unit>
setting @title of <trans-unit> to 'trans-unit'
stripping namespaces from <trans-unit>
processing <source>
setting @title of <source> to 'source'
stripping namespaces from <source>
renaming <source> to <p>
processing <target>
setting @title of <target> to 'target'
stripping namespaces from <target>
renaming <target> to <p>
renaming <trans-unit> to <div>
processing <trans-unit>
setting @title of <trans-unit> to 'trans-unit'
stripping namespaces from <trans-unit>
processing <source>
setting @title of <source> to 'source'
stripping namespaces from <source>
processing <mrk>
setting @title of <mrk> to 'mrk'
stripping namespaces from <mrk>
renaming <mrk> to <span>
renaming <source> to <p>
processing <target>
setting @title of <target> to 'target'
stripping namespaces from <target>
processing <mrk>
setting @title of <mrk> to 'mrk'
stripping namespaces from <mrk>
renaming <mrk> to <span>
renaming <target> to <p>
renaming <trans-unit> to <div>
processing <trans-unit>
setting @title of <trans-unit> to 'trans-unit'
stripping namespaces from <trans-unit>
processing <source>
setting @title of <source> to 'source'
stripping namespaces from <source>
renaming <source> to <p>
processing <target>
setting @title of <target> to 'target'
stripping namespaces from <target>
renaming <target> to <p>
renaming <trans-unit> to <div>
renaming <xliff> to <div>
wrapping document in HTML structure
Creating new <span> element to represent node of type ATT (buff)
Creating new <span> element to represent node of type ATT (foo)
Creating new <span> element to represent node of type ATT (qux)
marking <div>: Target is duplicate of source with the same ITS metadata inside
marking <div>: Target is empty
Creating new its:rules element to contain all rules
Setting id of <p> to ITS_1
Setting id of <span> to ITS_2
Setting id of <span> to ITS_3
Creating new rule <its:storageSizeRule> to match [selector=<p id="ITS_1">; storageSizePointer=<span id="ITS_2">; storageEncodingPointer=<span id="ITS_3">]
Setting id of <p> to ITS_4
Creating new rule <its:storageSizeRule> to match [selector=<p id="ITS_4">; storageSizePointer=<span id="ITS_3">; storageEncodingPointer=<span id="ITS_2">]
Setting id of <p> to ITS_5
Creating new rule <its:storageSizeRule> to match [selector=<p id="ITS_5">; storageSizePointer=<span id="ITS_2">; storageEncodingPointer=<span id="ITS_3">]
Setting id of <p> to ITS_6
Setting id of <span> to ITS_7
Creating new rule <its:storageSizeRule> to match [selector=<p id="ITS_6">; storageSizePointer=<span id="ITS_2">; storageEncodingPointer=<span id="ITS_7">]
Creating new rule <its:targetPointerRule> to match convert <source> and <target> elements
Setting id of <p> to ITS_8
Setting id of <p> to ITS_9
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance
Creating new rule <its:translateRule> to reset its:translateRule on new attributes
Creating new rule <its:dirRule> to reset its:dirRule on new attributes
Creating new rule <its:localeFilterRule> to reset its:localeFilterRule on new attributes
