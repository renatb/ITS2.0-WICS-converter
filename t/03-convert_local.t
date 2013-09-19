# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXLIFF2HTML;
use Test::More 0.88;
plan tests => 1*blocks();
use Test::HTML::Differences;

filters {
  input => 'htmlize',
  log => [qw(lines chomp array)],
  output => [qw(normalize_html)]
};

for my $block(blocks()){
    my $html = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name . ' (HTML output)');
}

__DATA__
=== html skeleton
Tests basic conversion of root element into <div>, placing contents into an
HTML skeleton, and creating default rules.
--- input
<xml/>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
      </its:rules>
    </script>
  <div title="xml"></div>

=== correct div and span
--- input
<xml>
  <stuff/>
  <foo>Some <i>stuff</i></foo>
  <bar>Some <b><i>real</i></b> stuff</bar>
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
      </its:rules>
    </script>
    <div title="xml">
      <div title="stuff"></div>
      <div title="foo">Some <span title="i">stuff</span></div>
      <div title="bar">Some <span title="b"><span title="i">real</span></span> stuff</div>
    </div>

=== namespaces stripped
--- input
<xml xmlns:bar="bar.io">
  <bar:foo>
    <qux/>
  </bar:foo>
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
      </its:rules>
    </script>
    <div title="xml">
      <div title="bar:foo">
        <div title="qux"></div>
      </div>
    </div>

=== xml:id
should be converted into id
--- input
<xml>
  <foo xml:id="bar"/>
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
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo" id="bar"></div>
    </div>

=== xml:space
should be converted removed, having no HTML equivalent
--- input
<xml>
  <foo xml:space="preserve"/>
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
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo"></div>
    </div>

=== xml:lang
should be converted into lang
--- input
<xml>
  <foo xml:lang="lut"/>
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
      </its:rules>
    </script>
    <div title="xml">
      <div title="foo" lang="lut"></div>
    </div>

=== translate ITS
translate att is converted as is;
mtype value of 'protected' is 'no' and 'x-its-translate-yes' is 'yes'
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <foo translate="no"/>
  <mrk mtype="protected"/>
  <mrk mtype="x-its-translate-yes"/>
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
      </its:rules>
    </script>
    <div title="xliff">
      <div title="foo" translate="no"></div>
      <div title="mrk" translate="no"></div>
      <div title="mrk" translate="yes"></div>
    </div>

=== localization note ITS
child <note> for trans-units
sibling <note annotates="source|target"> for sources and targets
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <trans-unit>
    <source>foo</source>
    <note>Some note</note>
  </trans-unit>
  <trans-unit>
    <source>foo</source>
    <note annotates="source" priority="1">source note</note>
    <target>bar</target>
    <note annotates="target" priority="2">target note</note>
  </trans-unit>
  <trans-unit>
    <source><mrk
        xmlns:itsxlf="http://www.w3.org/ns/its-xliff/"
        comment="foo note"
        itsxlf:locNoteType="description">
      foo</mrk></source>
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
      </its:rules>
    </script>
    <div title="xliff">
      <div title="trans-unit" its-loc-note="Some note" its-loc-note-type="alert">
        <div title="source">foo</div>
        <div title="note">Some note</div>
      </div>
      <div title="trans-unit">
        <div title="source" its-loc-note="source note" its-loc-note-type="alert">foo</div>
        <div title="note">source note</div>
        <div title="target" its-loc-note="target note" its-loc-note-type="description">bar</div>
        <div title="note">target note</div>
      </div>
      <div title="trans-unit">
        <div title="source">
          <span its-loc-note="foo note" its-loc-note-type="description" title="mrk">
            foo</span></div>
      </div>
    </div>

=== terminology ITS
mtype value of 'term' sets its-term='yes'
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/">
  <mrk mtype="term" itsxlf:termConfidence="5">foo</mrk>
  <mrk mtype="x-its-term-no">bar</mrk>
  <mrk itsxlf:termInfoRef="www.qux.com">qux</mrk>
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
      </its:rules>
    </script>
    <div title="xliff">
      <div title="mrk" its-term="yes" its-term-confidence="5">foo</div>
      <div title="mrk" its-term="no">bar</div>
      <div title="mrk" its-term-info-ref="www.qux.com">qux</div>
    </div>

=== withinText ITS
'nested' for sub; trans-unit is 'no' and other inlines are 'yes', but these
will translate as the default for div and span in HTML anyway.
--- input
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <trans-unit>
    <source><it><sub>foo</sub></it></source>
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
      </its:rules>
    </script>
    <div title="xliff">
      <div title="trans-unit">
        <div title="source">
          <span title="it">
            <span title="sub" its-within-text="nested">foo
            </span>
          </span>
        </div>
      </div>
    </div>

=== domain ITS
requires the creation of a global rule
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/">
  <mrk itsxlf:domains="meta-syntactic variables">foo</mrk>
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
        <its:translateRule selector="id('ITS_2')" translate="no"/>
        <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
      </its:rules>
    </script>
    <div title="xliff">
      <div title="mrk" id="ITS_1">
        <span
            class="_ITS_ATT"
            id="ITS_2"
            its-within-text="no"
            title="itsxlf:domains">
          meta-syntactic variables
        </span>
        foo
      </div>
    </div>

=== standoff markup
<script> tags are treated as text, so to ease testing we remove all whitespace
from standoff markup.
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:locQualityIssues xml:id="lq1" xmlns:its="http://www.w3.org/2005/11/its"><its:locQualityIssue locQualityIssueType="misspelling"/></its:locQualityIssues>
  <its:provenanceRecords xml:id="pr1" xmlns:its="http://www.w3.org/2005/11/its"><its:provenanceRecord org="acme-CAT-v2.3"/></its:provenanceRecords>
</xml>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script id="lq1" type="application/its+xml"><its:locQualityIssues xmlns:its="http://www.w3.org/2005/11/its" xml:id="lq1"><its:locQualityIssue locQualityIssueType="misspelling"/></its:locQualityIssues></script>
    <script id="pr1" type="application/its+xml"><its:provenanceRecords xmlns:its="http://www.w3.org/2005/11/its" xml:id="pr1"><its:provenanceRecord org="acme-CAT-v2.3"/></its:provenanceRecords></script>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
      </its:rules>
    </script>
    <div title="xml"></div>
