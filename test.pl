use strict;
use warnings;
use XML::ITS::WICS::XML2HTML;

my $converter = XML::ITS::WICS::XML2HTML->new();
my $converted = $converter->convert(\'<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:translateRule selector="id(\'i1\')" translate="yes"/>
    </its:rules>
  </head>
  <para xml:id="i1">Some text</para>
</xml>');

print $$converted;