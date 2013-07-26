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
        <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
          <its:translateRule selector="id('i1')" translate="yes"/>
        </its:rules>
    </script>
  </head>
  <body>
    <div title="xml">
        <div title="head"><div>
        <div title="para[xml:id='i1']" id="i1">Some text</div>
    </div>
  </body>
</html>
--- log
