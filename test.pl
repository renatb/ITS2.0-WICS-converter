use strict;
use warnings;
use XML::ITS::WICS::XML2HTML;
use Log::Any::Test;

my $converter = XML::ITS::WICS::XML2HTML->new();
my $converted = $converter->convert(
    'C:\Users\Nate Glenn\Desktop\logrus_workspace\newTestSuite' .
    '\localefilter\locale3xml.xml');

print $$converted;
