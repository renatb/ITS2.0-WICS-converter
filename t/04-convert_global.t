# Test conversion of global ITS;
# The only global rule tested in the sample file is locNote
use strict;
use warnings;
use t::TestXML2XLIFF;
use Test::More 0.88;
use Test::NoWarnings;
plan tests => 1 + blocks();
use Test::XML;

filters {
  input => 'xlfize',
};

for my $block(blocks()){
    my $xliff = $block->input;
    # print $xliff;
    is_xml($block->input, $block->output, $block->name);
}

__DATA__
=== its:locNoteRule
--- input
<xml
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <its:rules version="2.0">
    <its:locNoteRule locNoteType="alert" selector="/xml">
      <its:locNote>Note 1</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="/xml/foo" locNotePointer="@note"/>
  </its:rules>
  stuff
  <foo its:withinText="yes" note="Note 2">starf</foo>
</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <trans-unit>
        <source>
          stuff
          <mrk
              comment="Note 2"
              itsxlf:locNoteType="description">
            starf
          </mrk>
        </source>
        <note priority="1">Note 1</note>
      </trans-unit>
    </body>
  </file>
</xliff>
