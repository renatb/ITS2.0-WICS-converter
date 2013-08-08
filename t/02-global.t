# Test matching elements globally
use strict;
use warnings;
use t::TestXML2HTML;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::HTML::Differences;

filters {input => 'htmlize', log => [qw(lines chomp array)]};

for my $block(blocks()){
    my ($html, $log) = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or note join "\n", @$log;
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
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
        <its:translateRule selector="id('i1')" translate="yes"></its:translateRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para[xml:id='i1']" id="i1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:translateRule>; selector=<para xml:id="i1">
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para xml:id="i1">
renaming @xml:id of <para xml:id="i1"> to @id
setting @title of <para id="i1"> to 'para[xml:id='i1']'
renaming <para id="i1"> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Creating new rule <its:translateRule> to match [selector=<div id="i1">]

=== single selector of element without id
--- input
<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:translateRule selector="//para" translate="yes"/>
    </its:rules>
  </head>
  <para>Some text</para>
</xml>
--- output
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
        <its:translateRule selector="id('ITS_1')" translate="yes"></its:translateRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:translateRule>; selector=<para>
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new rule <its:translateRule> to match [selector=<div id="ITS_1">]

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
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
        <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"></its:domainRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
        <div title="content" id="ITS_2">foo</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:domainRule>; selector=<para>; domainPointer=<content>
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
processing <content>
setting @title of <content> to 'content'
renaming <content> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Setting id of <div> to ITS_2
Creating new rule <its:domainRule> to match [selector=<div id="ITS_1">; domainPointer=<div id="ITS_2">]

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
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
        <its:idValueRule selector="id('ITS_1')" idValue="'p1'"></its:idValueRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"></div>
        <div title="para" id="ITS_1">Some text</div>
    </div>
  </body>
</html>
--- log
match: rule=<its:idValueRule>; selector=<para>; idValue=p1
converting document elements into HTML
processing <xml>
setting @title of <xml> to 'xml'
processing <head>
setting @title of <head> to 'head'
removing <its:rules>
renaming <head> to <div>
processing <para>
setting @title of <para> to 'para'
renaming <para> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Setting id of <div> to ITS_1
Creating new rule <its:idValueRule> to match [selector=<div id="ITS_1">; idValue='p1']
