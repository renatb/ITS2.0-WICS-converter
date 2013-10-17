# Test conversion of global ITS using custom segmentation scheme;
use strict;
use warnings;
use Data::Dumper;
use t::TestXML2XLIFF;
use Test::NoWarnings;
plan tests => 1 + blocks();
use Test::XML;

filters {
  input => 'xlfize_custom=sec|para',
};

for my $block(blocks()){
    my $xliff = $block->input;
    # print $xliff;
    is_xml($block->input, $block->output, $block->name);
}

__DATA__
There is no need to test the conversions of all supported categories here,
since they are tested in the convert_local tests. Just make sure that
conversion still happens when using a custom segmentation scheme.

=== idValueRule
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its">
  <its:rules>
    <its:idValueRule idValue="'id1'" selector="/xml/sec/para"/>
    <its:idValueRule idValue="'id2'" selector="/xml/sec/para/foo"/>
  </its:rules>
  <sec>
    <para>
    stuff
    <foo>starf</foo>
    </para>
  </sec>
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
        <trans-unit id="1" resname="id1">
          <source>stuff
            <ph id="1">&lt;foo&gt;starf&lt;/foo&gt;</ph>
          </source>
          <target state="new">stuff
            <ph id="1">&lt;foo&gt;starf&lt;/foo&gt;</ph>
          </target>
        </trans-unit>
      </group>
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
        selector="/xml/sec/para[1]"/>
    <its:termRule
        term="yes"
        termInfoPointer="@info"
        termConfidence=".5"
        selector="/xml/sec/para[1]/foo"/>
    <its:termRule term="no" selector="/xml/sec/para[2]|/xml/sec/para[2]/foo"/>
  </its:rules>
  <sec>
    <para ref="stuff.com">
      stuff
      <foo info="nonce">starf</foo>
      </para>
    <para>
      stuff
      <foo>starf</foo>
    </para>
  </sec>
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
      <group id="1">
        <trans-unit id="1">
          <source>
            <mrk
              mtype="term"
              itsxlf:termInfoRef="stuff.com"
              itsxlf:termConfidence=".5">
            stuff
            <mrk
                mtype="term"
                itsxlf:termInfo="nonce"
                itsxlf:termConfidence=".5"><ph id="1">&lt;foo&gt;starf&lt;/foo&gt;</ph></mrk>
            </mrk>
          </source>
          <target state="new">
            <mrk
              mtype="term"
              itsxlf:termInfoRef="stuff.com"
              itsxlf:termConfidence=".5">
            stuff
            <mrk
                mtype="term"
                itsxlf:termInfo="nonce"
                itsxlf:termConfidence=".5"><ph id="1">&lt;foo&gt;starf&lt;/foo&gt;</ph></mrk>
            </mrk>
          </target>
        </trans-unit>
        <trans-unit id="2">
          <source>
            <mrk mtype="x-its-term-no">
            stuff
            <mrk mtype="x-its-term-no"><ph id="1">&lt;foo&gt;starf&lt;/foo&gt;</ph></mrk>
            </mrk>
          </source>
          <target state="new">
            <mrk mtype="x-its-term-no">
            stuff
            <mrk mtype="x-its-term-no"><ph id="1">&lt;foo&gt;starf&lt;/foo&gt;</ph></mrk>
            </mrk>
          </target>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== local overrides global
--- input
<sec xmlns:its="http://www.w3.org/2005/11/its">
  <its:rules>
    <its:idValueRule idValue="'id1'" selector="/xml/x"/>
    <its:termRule
        term="yes"
        termInfoPointer="/sec/para[2]"
        selector="/sec/para[1]"/>
    <its:translateRule selector="/sec/para[2]" translate="yes"/>
    <its:locNoteRule selector="/sec/para[2]" locNote="note1"/>
  </its:rules>
  <para xml:id="id2" its:term="yes" its:termInfoRef="stuff.com">stuff</para>
  <para its:translate="no" its:locNote="note2">stoof</para>
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
        <trans-unit id="1" resname="id2">
          <source>
            <mrk mtype="term" itsxlf:termInfoRef="stuff.com">
              stuff
            </mrk>
          </source>
          <target state="new">
            <mrk mtype="term" itsxlf:termInfoRef="stuff.com">
              stuff
            </mrk>
          </target>
        </trans-unit>
        <trans-unit id="2" translate="no">
          <source>stoof</source>
          <target state="new">stoof</target>
          <note priority="2">note2</note>
        </trans-unit>
      </group>
    </body>
  </file>
</xliff>

=== ITS in sources forced into mrks still have correct structural ITS
--- input
<sec xmlns:its="http://www.w3.org/2005/11/its">
  <its:rules version="2.0">
    <its:termRule
        term="yes"
        termInfoRefPointer="@ref"
        selector="//para"/>
  </its:rules>
  <para
      ref="stuff.com"
      xml:id="id1"
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

