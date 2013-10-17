# Test extraction of translation units using the custom extraction parameters
use strict;
use warnings;
use t::TestXML2XLIFF;
use Test::NoWarnings;
plan tests => 1 + blocks();
use Test::XML;

filters {
  input => 'xlfize_custom=sec|para',
};

for my $block(blocks()){
    #use either of input or input_special; just different filters
    my $xliff = $block->input || $block->input_special;
    # print $xliff;
    is_xml($xliff, $block->output, $block->name);
}

__DATA__
=== standoff markup
Test that standoff markup is pasted into XLIFF body
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:locQualityIssues xml:id="lq1">
    <its:locQualityIssue locQualityIssueType="misspelling"/>
  </its:locQualityIssues>
  <its:provenanceRecords xml:id="pr1"/>
</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <header>
      <its:locQualityIssues xml:id="lq1">
        <its:locQualityIssue locQualityIssueType="misspelling"/>
      </its:locQualityIssues>
      <its:provenanceRecords xml:id="pr1"/>
    </header>
    <body>
    </body>
  </file>
</xliff>

=== single TU
--- input
<sec>
nothin' here
<para>stuff</para>
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>stuff</source>
          <target state="new">stuff</target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== whitespace not extracted
--- input
<sec>
<para>

  </para>
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body/>
  </file>
</xliff>

=== several TUs
--- input
<sec>
  stuff
  <para>Raley</para>
  <para>stoof</para>
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>Raley</source>
          <target state="new">Raley</target>
        </trans-unit>
        <trans-unit id="2">
          <source>stoof</source>
          <target state="new">stoof</target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== several groups
--- input
<xml>
  <sec>
    <para>Raley</para>
    <para>Really</para>
  </sec>
  <sec>
    <para>stuff</para>
    <para>stoof</para>
  </sec>
</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:itsxlf="http://www.w3.org/ns/its-xliff/" xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>Raley</source>
          <target state="new">Raley</target>
        </trans-unit>
        <trans-unit id="2">
          <source>Really</source>
          <target state="new">Really</target>
        </trans-unit>
      </group>
      <group id="2">
        <trans-unit id="3">
          <source>stuff</source>
          <target state="new">stuff</target>
        </trans-unit>
        <trans-unit id="4">
          <source>stoof</source>
          <target state="new">stoof</target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== inline element
Every child element inside the TUs is escaped and inlined
--- input
<sec>
  stuff
  <para>starf<foo>guff</foo>poof</para>
  stoof
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>
            starf
            <ph id="1">
              &lt;foo&gt;guff&lt;/foo&gt;
            </ph>
            poof
          </source>
          <target state="new">
            starf
            <ph id="1">
              &lt;foo&gt;guff&lt;/foo&gt;
            </ph>
            poof
          </target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== multiple inline elements
ph element id's should be incremented
--- input
<sec>
  stuff
  <para>starf<foo>guff</foo><foo>duff</foo>poof</para>
  stoof
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:itsxlf="http://www.w3.org/ns/its-xliff/" xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>starf<ph id="1">&lt;foo&gt;guff&lt;/foo&gt;</ph><ph id="2">&lt;foo&gt;duff&lt;/foo&gt;</ph>poof</source>
          <target state="new">starf<ph id="1">&lt;foo&gt;guff&lt;/foo&gt;</ph><ph id="2">&lt;foo&gt;duff&lt;/foo&gt;</ph>poof</target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== Children of ph are escaped and printed
--- input
<sec>
  stuff
  <para>starf<foo>guff<bar>duff</bar></foo></para>
  stoof
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:itsxlf="http://www.w3.org/ns/its-xliff/" xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>starf<ph id="1">&lt;foo&gt;guff&lt;bar&gt;duff&lt;/bar&gt;&lt;/foo&gt;</ph></source>
          <target state="new">starf<ph id="1">&lt;foo&gt;guff&lt;bar&gt;duff&lt;/bar&gt;&lt;/foo&gt;</ph></target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== TU without groups specified
Everything goes in one group
--- input_special xlfize_custom=|para
<xml>
  stuff
  <para>starf<foo>guff</foo>poof</para>
  stoof
</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>starf<ph id="1">&lt;foo&gt;guff&lt;/foo&gt;</ph>poof</source>
          <target state="new">starf<ph id="1">&lt;foo&gt;guff&lt;/foo&gt;</ph>poof</target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>
