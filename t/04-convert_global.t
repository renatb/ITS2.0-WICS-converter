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
=== idValueRule
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:rules>
    <its:idValueRule idValue="'id1'" selector="/xml/x"/>
    <its:idValueRule idValue="'id2'" selector="/xml/x/foo"/>
  </its:rules>
  <x>
    stuff
    <foo its:withinText="yes">starf</foo>
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

=== its:translateRule
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <its:rules>
    <its:translateRule translate="yes" selector="//x|//x/foo"/>
    <its:translateRule translate="no" selector="//y|//y/foo"/>
  </its:rules>
  <x>
    stuff
    <foo its:withinText="yes">starf</foo>
  </x>
  <y>
    stuff
    <foo its:withinText="yes">starf</foo>
  </y>
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

=== its:termRule
This requires wrapping children of structural elements in <mrk>
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <its:rules>
    <its:termRule
        term="yes"
        termInfoRefPointer="@ref"
        termConfidence=".5"
        selector="//x"/>
    <its:termRule
        term="yes"
        termInfoPointer="@info"
        termConfidence=".5"
        selector="//x/foo"/>
    <its:termRule term="no" selector="//y|//y/foo"/>
  </its:rules>
  <x ref="stuff.com">
    stuff
    <foo info="nonce" its:withinText="yes">
      starf</foo>
  </x>
  <y>
    stuff
    <foo its:withinText="yes">
      starf</foo>
  </y>
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
                itsxlf:termInfo="nonce"
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

=== its:locNoteRule
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <its:rules>
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

=== local overrides global
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:rules>
    <its:idValueRule idValue="'id1'" selector="/xml/x"/>
    <its:termRule
        term="yes"
        termInfoPointer="../y"
        selector="/xml/x"/>
    <its:translateRule selector="//y" translate="yes"/>
    <its:locNoteRule selector="//y" locNote="note1"/>
  </its:rules>
  <x xml:id="id2" its:term="yes" its:termInfoRef="stuff.com">stuff</x>
  <y its:translate="no" its:locNote="note2">stoof</y>
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
      <trans-unit resname="id2">
        <source>
          <mrk mtype="term" itsxlf:termInfoRef="stuff.com">
            stuff
          </mrk>
        </source>
      </trans-unit>
      <trans-unit translate="no">
        <source>stoof</source>
        <note priority="2">note2</note>
      </trans-unit>
    </body>
  </file>
</xliff>
