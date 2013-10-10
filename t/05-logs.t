# Test log output
use strict;
use warnings;
use t::TestXML2XLIFF;
use Test::More 0.88;
plan tests => 2*blocks();
use Test::XML;

filters {
  input => 'xlf_log',
  log => [qw(lines chomp array)],
};

for my $block(blocks()){
    my ($html, $log) = $block->input;
    # print $html;
    is_xml($html, $block->output, $block->name . ' (XLIFF output)');
    is_deeply($log, $block->log, $block->name . ' (logs)')
      or note join "\n", @$log;
}

__DATA__
Just test logs for one document.
=== its:locNoteRule
--- input
<xml xmlns:its="http://www.w3.org/2005/11/its" its:version="2.0">
  <its:rules>
    <its:locNoteRule locNoteType="alert" selector="/xml">
      <its:locNote>Note 1</its:locNote>
    </its:locNoteRule>
    <its:locNoteRule selector="/xml/foo" locNotePointer="@note"/>
  </its:rules>
  <its:provenanceRecords xml:id="prov1"/>
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
    <header>
      <its:provenanceRecords xml:id="prov1"/>
    </header>
    <body>
      <trans-unit>
        <source>
          stuff
          <mrk
              mtype="x-its"
              comment="Note 2"
              itsxlf:locNoteType="description">
            starf
          </mrk>
        </source>
        <target state="new">
          stuff
          <mrk
              mtype="x-its"
              comment="Note 2"
              itsxlf:locNoteType="description">
            starf
          </mrk>
        </target>
        <note priority="1">Note 1</note>
      </trans-unit>
    </body>
  </file>
</xliff>

--- log
match: rule=<its:locNoteRule>; selector=<xml>
match: rule=<its:locNoteRule>; locNotePointer=@note[Note 2]; selector=<foo>
extracting translation units from document
placing <its:provenanceRecords xml:id="prov1"> (standoff markup) as-is in XLIFF document
Creating new trans-unit with <xml> as source
Creating inline <mrk> from <foo>
Copying sources to targets
wrapping document in XLIFF structure
