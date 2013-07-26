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
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or do{
        my $string = 'expected:';
        $string .= "$_->{message}\n" for (@$log);
        note $string;
      };
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
    <script type="application/its+xml"><its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
      <its:translateRule selector="id('i1')" translate="yes"></its:translateRule>
    </its:rules></script>
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
placing <its:rules> in script element
renaming <head> to <div>
processing <para xml:id="i1">
renaming @xml:id of <para xml:id="i1"> to @id
setting @title of <para xml:id="i1"> to 'para[xml:id='i1']'
renaming <para xml:id="i1"> to <div>
renaming <xml> to <div>
wrapping document in HTML structure
