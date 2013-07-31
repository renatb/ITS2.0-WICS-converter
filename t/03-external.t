# Test HTMLization of a document with external rules.
use strict;
use warnings;
use t::TestXML2HTML;
# use Test::More 0.88;
plan tests => 2;
use Path::Tiny;
use FindBin qw($Bin);
use Test::HTML::Differences;
use XML::ITS::WICS::XML2HTML;

use Log::Any::Test;
use Log::Any qw($log);

use Data::Section::Simple qw(get_data_section);
my $all_data = get_data_section();

my $file = path($Bin, 'corpus', 'test_external_internal.xml');

$log->clear();
my $wics = XML::ITS::WICS::XML2HTML->new();
my $converted = ${ $wics->convert("$file") };

# print $converted;

eq_or_diff_html($converted, $all_data->{html}, 'HTML structure');
# print $all_data->{log};
is_deeply(
  [map { $_->{message} } @{$log->msgs()}],
  [split /[\n\r]+/, $all_data->{log}],
  'Logs'
);
  # or print join "\n", map { $_->{message} } @{$log->msgs()};

__DATA__
@@ html
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
    <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
        <its:translateRule xml:id="ext3rule" selector="id('root')" translate="yes"></its:translateRule>
      <foo:translateRule xmlns:foo="http://www.w3.org/2005/11/its" xml:id="ext2rule" selector="id('trmark')" translate="yes"></foo:translateRule>
      <its:translateRule xml:id="ext1rule" selector="id('par')" translate="yes"></its:translateRule>
      <its:idValueRule xml:id="baseFileRule" selector="id('body')" idValue="'bodyId'"></its:idValueRule>
    </its:rules>
    </script>
  </head>
  <body>
    <div id="root" title="myDoc[xml:id='root']">
     <div title="head">

     </div>
     <div id="body" title="body[xml:id='body']">
      <div id="par" title="par[xml:id='par',title='Text']">The <span id="trmark" title="trmark[xml:id='trmark']">World Wide Web Consortium</span> is making the World Wide Web worldwide!</div>
     </div>
    </div>
  </body>
</html>

@@ log
match: rule=<its:translateRule xml:id="ext3rule">; selector=<myDoc xml:id="root">
match: rule=<foo:translateRule xml:id="ext2rule">; selector=<trmark xml:id="trmark">
match: rule=<its:translateRule xml:id="ext1rule">; selector=<par xml:id="par">
match: rule=<its:idValueRule xml:id="baseFileRule">; selector=<body xml:id="body">; idValue=bodyId
converting document elements into HTML
processing <myDoc xml:id="root">
renaming @xml:id of <myDoc xml:id="root"> to @id
setting @title of <myDoc id="root"> to 'myDoc[xml:id='root']'
processing <head>
setting @title of <head> to 'head'
removing <its:rules xml:id="baseFileContainer">
renaming <head> to <div>
processing <body xml:id="body">
renaming @xml:id of <body xml:id="body"> to @id
setting @title of <body id="body"> to 'body[xml:id='body']'
processing <par xml:id="par">
renaming @xml:id of <par xml:id="par"> to @id
setting @title of <par id="par"> to 'par[xml:id='par',title='Text']'
processing <trmark xml:id="trmark">
renaming @xml:id of <trmark xml:id="trmark"> to @id
setting @title of <trmark id="trmark"> to 'trmark[xml:id='trmark']'
renaming <trmark id="trmark"> to <span>
renaming <par id="par"> to <div>
renaming <body id="body"> to <div>
renaming <myDoc id="root"> to <div>
wrapping document in HTML structure
Creating new its:rules element to contain all rules
Creating new rule <its:translateRule xml:id="ext3rule"> to match [selector=<div id="root">]
Creating new rule <foo:translateRule xml:id="ext2rule"> to match [selector=<span id="trmark">]
Creating new rule <its:translateRule xml:id="ext1rule"> to match [selector=<div id="par">]
Creating new rule <its:idValueRule xml:id="baseFileRule"> to match [selector=<div id="body">; idValue='bodyId']
