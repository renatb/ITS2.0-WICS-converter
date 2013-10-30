# Test extraction of translation units, using ITS segmentation scheme
use strict;
use warnings;
use t::TestXML2XLIFF;
use Test::NoWarnings;
plan tests => 1 + blocks();
use Test::XML;

filters {
  input => 'xlfize',
};

for my $block(blocks()){
    my $xliff = $block->input;
    # print $xliff;
    is_xml($xliff, $block->output, $block->name);
}

__DATA__
=== XLIFF skeleton
Tests creation of basic XLIFF skeleton
--- input
<xml/>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body></body>
  </file>
</xliff>

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
<xml>stuff</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <trans-unit>
        <source>stuff</source>
        <target state="new">stuff</target>
      </trans-unit>
    </body>
  </file>
</xliff>

=== whitespace not extracted
--- input
<xml>

  </xml>
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
<xml>stuff<foo>really<bar>Raleigh</bar>Raley</foo>stoof</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <trans-unit>
        <source>stuff</source>
        <target state="new">stuff</target>
      </trans-unit>
      <trans-unit>
        <source>really</source>
        <target state="new">really</target>
      </trans-unit>
      <trans-unit>
        <source>Raleigh</source>
        <target state="new">Raleigh</target>
      </trans-unit>
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
