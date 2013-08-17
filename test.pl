use strict;
use warnings;
use XML::ITS::WICS::XML2HTML;
use Log::Any::Test;

my $converter = XML::ITS::WICS::XML2HTML->new();
my $converted = $converter->convert(
    \'
    <xml xmlns="u.me">
        <its:rules version="2.0"
            xmlns:its="http://www.w3.org/2005/11/its">
          <its:translateRule selector="/xml" translate="yes"/>
        </its:rules>

        buh
    </xml>');
# my $converted = $converter->convert(
#     'C:\Users\Nate Glenn\Desktop\logrus_workspace\newTestSuite' .
#     '\localefilter\locale3xml.xml');

print $$converted;
