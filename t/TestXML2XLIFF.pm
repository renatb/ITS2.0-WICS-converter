#some test::base filters for XLIFF conversion
package t::TestXML2XLIFF;
use Test::Base -base;

1;

package t::TestXML2XLIFF::Filter;
use Test::Base::Filter -base;
use strict;
use warnings;
use Log::Any::Test;
use Log::Any qw($log);
use ITS::DOM;
use ITS::XML2XLIFF;

#convert the input XML into xlf and return the xlf string
sub xlfize {
    my ($self, $xml) = @_;
    my $converter = ITS::XML2XLIFF->new();
    my $converted = ${ $converter->convert(\$xml) };
    # $converted = $self->normalize_xlf($converted);
    # print $converted;
    return $converted;
}
