use strict;
use warnings;
use Test::More;
plan tests => 2;
use Log::Any::Test;
use Log::Any qw($log);
use ITS;
use ITS::WICS::Reduce qw(reduce);
use FindBin qw($Bin);
use Path::Tiny;
use Test::HTML::Differences;

my $html_path = path($Bin, 'corpus', 'test_param.html');

my $ITS = ITS->new('html', doc => "$html_path");

reduce($ITS);

my $html = $ITS->get_doc->string;
normalize(\$html);

my $expected = <<'EXPECTED';
<!DOCTYPE html>
  <head>
    <title>WICS</title>
    <meta charset="utf-8">
    <script type="application/its+xml" id="lq1">
      <its:locQualityIssues xml:id="lq1" xmlns:its="http://www.w3.org/2005/11/its">
        <its:locQualityIssue
          locQualityIssueType="misspelling"
          locQualityIssueComment="'c'es' is unknown. Could be 'c'est'"
          locQualityIssueSeverity="50"/>
      </its:locQualityIssues>
    </script>
    <script id="ext1container" type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xml:id="ext1container" version="2.0">
        <its:param name="title">Text</its:param>
        <its:param name="trmarkId">notran</its:param>
        <its:param name="foo">bar2</its:param>
        <its:param name="baz">qux</its:param>
      <!-- param 'foo' will override one from calling file -->
      <its:translateRule xml:id="ext_rule" selector="//*[@baz=$baz]" translate="yes"/>
</its:rules>
    </script>
    <script id="ext2container" type="application/its+xml">
      <its:rules xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:its="http://www.w3.org/2005/11/its" xml:id="ext2container" version="2.0" xlink:type="simple" xlink:href="external_param.xml">
        <its:param name="title">Text</its:param>
        <its:param name="trmarkId">notran</its:param>
        <its:param name="foo">bar1</its:param>
      </its:rules>
    </script>
    <script id="baseFileContainer" type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" xml:id="baseFileContainer" version="2.0">
        <its:param name="title">Text</its:param>
        <its:param name="trmarkId">notran</its:param>
        <its:param name="foo">bar1</its:param>
           <its:idValueRule xml:id="idValRule" selector="id($title)" idValue="bodyId"/>
           <its:locNoteRule xml:id="locNoteRule" selector="id($title)" locNotePointer="id($trmarkId)"/>
          </its:rules>
    </script>
  </head>
  <body>
    <p id="InvalidParameter">
      Invalid parameter
    </p>
  </body>
EXPECTED

#normalize to make comparing scripts easier
normalize(\$expected);

eq_or_diff_html($html, $expected, 'HTML output');
my @expected_logs = (
  'removing link to external_param_2.xml',
  'Rewriting rules container (ext1container) in <head>',
  'Rewriting rules container (ext2container) in <head>',
  'Rewriting rules container (baseFileContainer) in <head>',
);
my @actual_logs = map { $_->{message} } @{$log->msgs};

is_deeply(\@actual_logs, \@expected_logs, 'correct logs');

sub normalize {
  my ($html) = @_;

  #normalize to make processing scripts easier
  $$html =~ s/\n\s*\n/\n/g;
  $$html =~ s/ +/ /g;
  $$html =~ s/^ //gm;
  return;
}
