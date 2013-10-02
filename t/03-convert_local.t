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
