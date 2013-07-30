use strict;
use warnings;
use XML::ITS::WICS::XML2HTML;
use Log::Any::Test;

my $converter = XML::ITS::WICS::XML2HTML->new();
my $converted = $converter->convert(\'<?xml version="1.0"?>
<xml>
  <head>
    <its:rules version="2.0" xmlns:its="http://www.w3.org/2005/11/its">
      <its:domainRule selector="//foo:para"
        domainPointer="//content" xmlns:foo="www.foo.com"/>
    </its:rules>
  </head>
  <foo:para xmlns:foo="www.foo.com">Some text</foo:para>
  <content>foo</content>
</xml>');

print $$converted;