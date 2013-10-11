# Test extraction of translation units
use strict;
use warnings;
use t::TestXML2XLIFF;
use Test::More 0.88;
use Test::NoWarnings;
plan tests => 1 + blocks();
use Test::XML;

filters {
  input => 'xlfize_custom',
};

for my $block(blocks()){
    my $xliff = $block->input;
    # print $xliff;
    is_xml($block->input, $block->output, $block->name);
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
      <trans-unit>
        <source>Raley</source>
        <target state="new">Raley</target>
      </trans-unit>
      <trans-unit>
        <source>stoof</source>
        <target state="new">stoof</target>
      </trans-unit>
    </body>
  </file>
</xliff>

=== TU with inline element
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  stuff
  <foo its:withinText="yes">starf<bar>guff</bar></foo>
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
      <trans-unit>
        <source>stuff<mrk mtype="x-its">starf</mrk>stoof</source>
        <target state="new">stuff<mrk mtype="x-its">starf</mrk>stoof</target>
      </trans-unit>
      <trans-unit>
        <source>guff</source>
        <target state="new">guff</target>
      </trans-unit>
    </body>
  </file>
</xliff>

=== TU with nested element
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  stuff
  <foo its:withinText="nested">starf</foo>
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
      <trans-unit>
        <source>stuff stoof</source>
        <target state="new">stuff stoof</target>
      </trans-unit>
      <trans-unit>
        <source>starf</source>
        <target state="new">starf</target>
      </trans-unit>
    </body>
  </file>
</xliff>
