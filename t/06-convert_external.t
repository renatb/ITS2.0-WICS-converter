# Test conversion of a document with external rules.
use strict;
use warnings;
use t::TestXLIFF2HTML;
plan tests => 1;
use Path::Tiny;
use FindBin qw($Bin);
use Test::HTML::Differences;
use ITS::XLIFF2HTML;
use t::TestXLIFF2HTML;

use Data::Section::Simple qw(get_data_section);
my $all_data = get_data_section();

my $file = path($Bin, 'corpus', 'test_external_internal.xml');

my $wics = ITS::XLIFF2HTML->new();
my $converted = ${ $wics->convert("$file") };
$converted = t::TestXLIFF2HTML::Filter->normalize_html($converted);
my $expected = t::TestXLIFF2HTML::Filter->normalize_html($all_data->{html});

eq_or_diff_html($converted, $expected, 'HTML structure');

__DATA__
@@ html
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
      <its:translateRule xml:id="ext3rule" selector="id('root')" translate="yes"/>
      <foo:translateRule xmlns:foo="http://www.w3.org/2005/11/its" xml:id="ext2rule" selector="id('trmark')" translate="yes"/>
      <its:translateRule xml:id="ext1rule" selector="id('par')" translate="yes"/>
      <its:idValueRule xml:id="baseFileRule" selector="id('body')" idValue="'bodyId'"/>
    </its:rules>
    </script>
    <div id="root" title="myDoc">
    <div title="head"></div>
    <div id="body" title="body">
      <div id="par" title="par">
        <span class="_ITS_ATT"
            title="title"
            its-within-text="no"
            id="ITS_1">
          Text
        </span>
        The
        <span id="trmark" title="trmark">
          World Wide Web Consortium
        </span>
        is making the World Wide Web worldwide!
      </div>
    </div>
  </div>
