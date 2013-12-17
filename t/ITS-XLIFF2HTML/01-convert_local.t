# Test HTMLization of local ITS markup
use strict;
use warnings;
use t::TestXLIFF2HTML;
plan tests => 1*blocks();
use Test::HTML::Differences;

filters {
  input => 'htmlize',
  output => [qw(normalize_html)]
};

for my $block(blocks()){
    my $html = $block->input;
    # print $html;
    eq_or_diff_html($html, $block->output, $block->name);
}

__DATA__
=== html skeleton
Tests basic conversion of root element into <div>, removing namespaces,
placing contents into an HTML skeleton, and creating default rules.
--- input
<xliff/>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
  <div title="xliff"></div>

=== correct div and span
inlines are <span>, source and target are <p>, everything else is <div>
--- input
<xliff>
  <trans-unit>
    <source>Some <mrk>stuff</mrk></source>
    <target>Some <mrk>stuff</mrk></target>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title=trans-unit>
        <p title=source>Some <span title=mrk>stuff</span></p>
        <p title=target>Some <span title=mrk>stuff</span></p>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xml">
      <div title="foo" id="bar"></div>
    </div>

=== its:version
should be removed, having no HTML equivalent
--- input
<xml
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0"/>
--- output
<!DOCTYPE html>
    <meta charset="utf-8">
    <title>WICS</title>
    <script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
        <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
        <its:dirRule selector="//@*" dir="ltr"/>
        <its:translateRule selector="//@*" translate="no"/>
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xml"></div>

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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="trans-unit" its-loc-note="Some note" its-loc-note-type="alert">
        <p title="source">foo</p>
        <div title="note">Some note</div>
      </div>
      <div title="trans-unit">
        <p title="source" its-loc-note="source note" its-loc-note-type="alert">foo</p>
        <div title="note">source note</div>
        <p title="target" its-loc-note="target note" its-loc-note-type="description">bar</p>
        <div title="note">target note</div>
      </div>
      <div title="trans-unit">
        <p title="source">
          <span its-loc-note="foo note" its-loc-note-type="description" title="mrk">
            foo</span></p>
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
  <mrk itsxlf:termInfo="Metasyntactic sugar">qux</mrk>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <span title="mrk" its-term="yes" its-term-confidence="5">foo</span>
      <span title="mrk" its-term="no">bar</span>
      <span title="mrk" its-term-info-ref="www.qux.com">qux</span>
      <span title="mrk" its-term-info-ref="#ITS_1">qux</span>
      <div id="ITS_1" title="termInfo">Metasyntactic sugar</div>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="foo" translate="no"></div>
      <span title="mrk" translate="no"></span>
      <span title="mrk" translate="yes"></span>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="trans-unit">
        <p title="source">
          <span title="it">
            <span title="sub" its-within-text="nested">foo
            </span>
          </span>
        </p>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
        <its:domainRule selector="id('ITS_1')" domainPointer="id('ITS_2')"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <span title="mrk" id="ITS_1">
        <span
            class="_ITS_ATT"
            id="ITS_2"
            its-within-text="no"
            title="itsxlf:domains">
          meta-syntactic variables
        </span>
        foo
      </span>
    </div>

=== text analysis ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <source its:annotatorsRef="text-analysis|http://enrycher.ijs.si">
    <mrk
        mtype="phrase"
        its:taClassRef="http://nerd.eurecom.fr/ontology#Place"
        its:taIdentRef="http://dbpedia.org/resource/Arizona"
        its:taConfidence="0.7">
      Arizona
    </mrk>
  </source>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <p title="source"
          its-annotators-ref="text-analysis|http://enrycher.ijs.si">
      <span
          title="mrk"
          its-ta-class-ref="http://nerd.eurecom.fr/ontology#Place"
          its-ta-ident-ref="http://dbpedia.org/resource/Arizona"
          its-ta-confidence="0.7">
        Arizona
      </span>
    </p>

=== locale filter ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <foo its:localeFilterList="ja">bar</foo>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="foo" its-locale-filter-list="ja">bar</div>
    </div>

=== locale filter ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <target its:person="John Doe"
     its:orgRef="http://www.legaltrans-ex.com/"
     its:revPerson="Tommy Atkins"
     its:revOrgRef="http://www.vistatec.com/"
     its:provRef="http://www.examplelsp.com/excontent987/legal/prov/e6354">Text</target>
  <mrk mtype="x-its" its:provenanceRecordsRef="#ph3"/>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <p title="target"
          its-person="John Doe"
          its-org-ref="http://www.legaltrans-ex.com/"
          its-rev-person="Tommy Atkins"
          its-rev-org-ref="http://www.vistatec.com/"
          its-prov-ref="http://www.examplelsp.com/excontent987/legal/prov/e6354">
        Text
      </p>
      <span title="mrk" its-provenance-records-ref="#ph3"></span>
    </div>

=== external resource ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/">
  <source>Image: <x itsxlf:externalResourceRef="example.png"/></source>
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
        <its:translateRule selector="id('ITS_1')" translate="no"/>
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
        <its:externalResourceRefRule selector="id('ITS_2')" externalResourceRefPointer="id('ITS_1')"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <p title="source">
        Image:
        <span id="ITS_2" title="x">
          <span
              class="_ITS_ATT"
              id="ITS_1"
              its-within-text="no"
              title="itsxlf:externalResourceRef">
            example.png
          </span>
        </span>
      </p>
    </div>

=== ID value ITS
requires the creation of a global rule
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <trans-unit resname="foo_res">foo</trans-unit>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
        <its:idValueRule selector="id('ITS_1')" idValue="'foo_res'"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="trans-unit" id="ITS_1">
        foo
      </div>
    </div>

=== preserve space ITS
xml:space should be removed, having no HTML equivalent
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xml">
      <div title="foo"></div>
    </div>

=== localization quality issue ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <trans-unit>
   <source>This is the content</source>
   <target its:locQualityIssuesRef="#lqi1">c'es le contenu</target>
  </trans-unit>
  <trans-unit>
   <source>This is the content</source>
   <target its:locQualityIssueType="misspelling"
           its:locQualityIssueComment="'c'es' is unknown."
           its:locQualityIssueSeverity="50">c'es le contenu</target>
  </trans-unit>
</xliff>
--- output
<!DOCTYPE html>
    <meta charset=utf-8><title>WICS</title><script type="application/its+xml">
      <its:rules xmlns:its="http://www.w3.org/2005/11/its" xmlns:h="http://www.w3.org/1999/xhtml" version="2.0">
      <its:localeFilterRule localeFilterList="*" selector="//@*" localeFilterType="include"/>
      <its:dirRule selector="//@*" dir="ltr"/>
      <its:translateRule selector="//@*" translate="no"/>
      <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title=xliff>
      <div title=trans-unit>
        <p title=source>This is the content</p>
        <p
            its-loc-quality-issues-ref="#lqi1"
            title="target">
          c'es le contenu
        </p>
      </div>
      <div title=trans-unit>
        <p title=source>This is the content</p>
        <p
            its-loc-quality-issue-comment="'c'es' is unknown."
            its-loc-quality-issue-severity="50"
            its-loc-quality-issue-type="misspelling"
            title="target">
          c'es le contenu
        </p>
      </div>
    </div>

=== localization quality rating ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <trans-unit id="1" its:locQualityRatingScore="100"
   its:locQualityRatingScoreThreshold="95"
   its:locQualityRatingProfileRef="http://example.org/qaModel/v13">
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div
          its-loc-quality-rating-profile-ref="http://example.org/qaModel/v13"
          its-loc-quality-rating-score="100"
          its-loc-quality-rating-score-threshold="95"
          title="trans-unit"></div>
    </div>

=== MT confidence ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:annotatorsRef="mt-confidence|MTServices-XYZ">
  <source its:mtConfidence="0.8982">Texte</source>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff" its-annotators-ref="mt-confidence|MTServices-XYZ">
      <p title="source" its-mt-confidence="0.8982">Texte</p>
    </div>

=== allowed characters ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <source its:allowedCharacters="[a-z]">text</source>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <p title="source" its-allowed-characters="[a-z]">text</p>
    </div>

=== storage size ITS
--- input
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its">
  <trans-unit id="1">
    <source
        its:storageSize="12"
        its:storageEncoding="UTF-16"
        its:lineBreakType="crlf">Text</source>
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xliff">
      <div title="trans-unit">
        <p
            title="source"
            its-storage-size="12"
            its-storage-encoding="UTF-16"
            its-line-break-type="crlf">
          Text
        </p>
      </div>
    </div>

=== standoff markup
Test that standoff markup is pasted into a <script> element
in the head.
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
        <its:targetPointerRule selector="//*[@title='source']" targetPointer="../*[@title='target']"/>
      </its:rules>
    </script>
    <style>body {visibility:hidden} p {visibility: visible}</style>
    <div title="xml"></div>
