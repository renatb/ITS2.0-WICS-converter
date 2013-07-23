#some test::base filters for HTML conversion
package t::TestXML2HTML;
use Test::Base -base;

1;

package t::TestXML2HTML::Filter;
use Test::Base::Filter -base;
use strict;
use warnings;
use XML::ITS::WICS::XML2HTML;
use XML::ITS::DOM;

#convert the input XML into html and return the html string
sub htmlize {
    my ($self, $xml) = @_;
    # print $xml;
    my $wics = XML::ITS::WICS::XML2HTML->new();
    my $converted = ${ $wics->convert(\$xml) };
    # print "converting: $converted";
    return $converted;
}

#parse the input HTML, then stringify the parse and return it.
#this normalizes the contents of script elements (which contain ITS:XML
#but are compared as strings)
sub restring {
    my ($self, $html) = @_;
    my $string = XML::ITS::DOM->new('html' => \$html)->string;
    # print "restringing: $string";
    return $string;
}
