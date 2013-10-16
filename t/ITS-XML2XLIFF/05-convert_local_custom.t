# Test conversion of local ITS when using custom extraction parameters;
# The local markup used in the sample is:
# xml:id, its:[locNote*|translate|term*|version]
use strict;
use warnings;
use t::TestXML2XLIFF;
use Test::NoWarnings;
plan tests => 1 + blocks();
use Test::XML;

filters {
  input => 'xlfize_custom=sec|para',
};

for my $block(blocks()){;
    my $xliff = $block->input;
    # print $xliff;
    is_xml($xliff, $block->output, $block->name);
}

__DATA__
There is no need to test the conversions of all supported categories here,
since they are tested in the convert_local tests. Just make sure that
conversion still happens when using a custom segmentation scheme.

=== its:locNote*
--- input
<sec xmlns:its="http://www.w3.org/2005/11/its">
  <para
      its:locNoteType="alert"
      its:locNote="note1">
    stuff
    <foo
        its:locNoteType="description"
        its:locNote="note2">starf</foo>
  </para>
  <para
      its:locNoteType="description"
      its:locNote="note1">
    stuff
    <foo
        its:locNoteType="alert"
        its:locNote="note2">starf</foo>
  </para>
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>stuff
            <mrk
                mtype="x-its"
                comment="note2"
                itsxlf:locNoteType="description">
              starf
            </mrk>
          </source>
          <target state="new">stuff
            <mrk
                mtype="x-its"
                comment="note2"
                itsxlf:locNoteType="description">
              starf
            </mrk>
          </target>
          <note priority="1">note1</note>
        </trans-unit>
        <trans-unit id="2">
          <source>stuff
            <mrk
                mtype="x-its"
                comment="note2"
                itsxlf:locNoteType="alert">
              starf
            </mrk>
          </source>
          <target state="new">stuff
            <mrk
                mtype="x-its"
                comment="note2"
                itsxlf:locNoteType="alert">
              starf
            </mrk>
          </target>
          <note priority="2">note1</note>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== its:withinText is removed
withinText values are determined by the segmentation scheme, so delete these.
--- input
<sec xmlns:its="http://www.w3.org/2005/11/its">
  <para its:withinText="yes">stuff<wtv its:withinText="yes">starf</wtv></para>
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1">
          <source>stuff<mrk mtype="x-its">starf</mrk></source>
          <target state="new">stuff<mrk mtype="x-its">starf</mrk></target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== ITS in sources forced into mrks still have correct structural ITS
--- input
<sec xmlns:its="http://www.w3.org/2005/11/its">
  <para
      xml:id="id1"
      its:term="yes"
      its:termInfoRef="stuff.com"
      its:locNote="whatevs"
      its:allowedChars="[a-z]">
    stuff
  </para>
</sec>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:itsxlf="http://www.w3.org/ns/its-xliff/"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <group id="1">
        <trans-unit id="1" resname="id1">
          <source its:allowedChars="[a-z]">
            <mrk mtype="term" itsxlf:termInfoRef="stuff.com">
              stuff
            </mrk>
          </source>
          <target state="new" its:allowedChars="[a-z]">
            <mrk mtype="term" itsxlf:termInfoRef="stuff.com">
              stuff
            </mrk>
          </target>
          <note priority="2">whatevs</note>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

