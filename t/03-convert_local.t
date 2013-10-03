# Test conversion of local ITS;
# The local markup used in the sample is:
# xml:id, its:[locNote*|translate|term*|version]
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
=== its:version
Should be removed; it's declared in the XLIFF root
--- input
<xml
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  stuff
  <foo its:withinText="yes" its:version="2.0">starf</foo>
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
        <source>stuff<mrk>starf</mrk></source>
      </trans-unit>
    </body>
  </file>
</xliff>

=== its:locNote*
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <x
      its:locNoteType="alert"
      its:locNote="note1">
    stuff
    <foo
        its:withinText="yes"
        its:locNoteType="description"
        its:locNote="note2">starf</foo>
  </x>
  <x
      its:locNoteType="description"
      its:locNote="note1">
    stuff
    <foo
        its:withinText="yes"
        its:locNoteType="alert"
        its:locNote="note2">starf</foo>
  </x>
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
        <source>stuff
          <mrk
              comment="note2"
              itsxlf:locNoteType="description">
            starf
          </mrk>
        </source>
        <note priority="1">note1</note>
      </trans-unit>
      <trans-unit>
        <source>stuff
          <mrk
              comment="note2"
              itsxlf:locNoteType="alert">
            starf
          </mrk>
        </source>
        <note priority="2">note1</note>
      </trans-unit>
    </body>
  </file>
</xliff>

=== its:translate
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <x its:translate="yes">
    stuff
    <foo its:withinText="yes" its:translate="yes">starf</foo>
  </x>
  <x its:translate="no">
    stuff
    <foo its:withinText="yes" its:translate="no">starf</foo>
  </x>
</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <trans-unit translate="yes">
        <source>stuff
          <mrk mtype="x-its-translate-yes">
            starf
          </mrk>
        </source>
      </trans-unit>
      <trans-unit translate="no">
        <source>stuff
          <mrk mtype="protected">
            starf
          </mrk>
        </source>
      </trans-unit>
    </body>
  </file>
</xliff>

=== xml:id
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <x xml:id="id1">
    stuff
    <foo its:withinText="yes" xml:id="id2">starf</foo>
  </x>
</xml>
--- output
<?xml version="1.0" encoding="utf-8"?>
<xliff
    xmlns="urn:oasis:names:tc:xliff:document:1.2"
    xmlns:its="http://www.w3.org/2005/11/its"
    its:version="2.0">
  <file original="STRING" source-language="en" datatype="plaintext">
    <body>
      <trans-unit resname="id1">
        <source>stuff
          <mrk>starf</mrk>
        </source>
      </trans-unit>
    </body>
  </file>
</xliff>

=== its:term*
This requires wrapping children of structural elements in <mrk>
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <x
      its:term="yes"
      its:termInfoRef="stuff.com"
      its:termConfidence=".5">
    stuff
    <foo
        its:withinText="yes"
        its:term="yes"
        its:termInfoRef="starf.com"
        its:termConfidence=".5">
      starf</foo>
  </x>
  <x its:term="no">
    stuff
    <foo its:withinText="yes" its:term="no">
      starf</foo>
  </x>
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
          <mrk
              mtype="term"
              itsxlf:termInfoRef="stuff.com"
              itsxlf:termConfidence=".5">
            stuff
            <mrk
                mtype="term"
                itsxlf:termInfoRef="starf.com"
                itsxlf:termConfidence=".5">starf</mrk>
          </mrk>
        </source>
      </trans-unit>
      <trans-unit>
        <source>
          <mrk mtype="x-its-term-no">
            stuff
            <mrk mtype="x-its-term-no">starf</mrk>
          </mrk>
        </source>
      </trans-unit>
    </body>
  </file>
</xliff>

=== ITS in sources forced into mrks still affect trans-unit
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <x
      xml:id="id1"
      its:term="yes"
      its:termInfoRef="stuff.com"
      its:locNote="whatevs">
    stuff
  </x>
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
      <trans-unit resname="id1">
        <source>
          <mrk mtype="term" itsxlf:termInfoRef="stuff.com">
            stuff
          </mrk>
        </source>
        <note priority="2">whatevs</note>
      </trans-unit>
    </body>
  </file>
</xliff>

