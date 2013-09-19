# Test log output
use strict;
use warnings;
use t::TestXLIFF2HTML;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::HTML::Differences;

filters {
  input => 'html_log',
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
      <its:dirRule selector="id('ITS_2')" dir="ltr"/>
      <its:localeFilterRule localeFilterList="*" selector="id('ITS_2')" localeFilterType="include"/>
      <its:translateRule selector="id('ITS_2')" translate="no"/>
      <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
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
--- log
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=[namespace: xmlns:foo]
match: rule=<its:domainRule>; selector=<foo:para>; domainPointer=[namespace: xmlns:foo]
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <foo:para>
setting @title of <foo:para> to 'foo:para'
stripping namespaces from <foo:para>
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new <span> element to represent node of type NS (xmlns:foo)
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <span> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<span id="ITS_2">]
Creating new rule <its:targetPointerRule> to match convert <source> and <target> elements
Creating new rule <its:translateRule> to prevent false inheritance
Creating new rule <its:dirRule> to prevent false inheritance
Creating new rule <its:localeFilterRule> to prevent false inheritance
Creating new rule <its:translateRule> to reset its:translateRule on new attributes
Creating new rule <its:dirRule> to reset its:dirRule on new attributes
Creating new rule <its:localeFilterRule> to reset its:localeFilterRule on new attributes
