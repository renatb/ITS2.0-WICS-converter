#test that the module is loaded properly
use strict;
use warnings;
use Test::More 0.88;
plan tests => 1;
my $package = 'ITS::WICS';

use_ok('XML::ITS::WICS');

__END__