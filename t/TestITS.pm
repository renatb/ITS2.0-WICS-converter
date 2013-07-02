package t::TestITS;
use strict;
use warnings;
use Test::Base -base;

1;

package t::TestITS::Filter;
use Test::Base::Filter -base;
use ITS;

sub rules {
    my ($self, $input) = @_;
    my $ITS = ITS->new(string => \$input);
    return $ITS->get_rules();
}


1;