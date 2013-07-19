#some test::base filters for HTML conversion
package t::TestXML2HTML;
use Test::Base -base;

1;

package t::TestXML2HTML::Filter;
use Test::Base::Filter -base;
use strict;
use warnings;
use XML::ITS::WICS::XML2HTML;

#convert the input XML into html and return the html string
sub htmlize {
    my ($self, $xml) = @_;
    # print $xml;
    my $wics = XML::ITS::WICS::XML2HTML->new();
    return ${ $wics->convert(\$xml) };
}
