# Make sure that rules are extracted correctly and are
# stored in proper application order

use strict;
use warnings;
use ITS;
use Test::More;
plan tests => 5;
use Test::NoWarnings;
use Test::XML;
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $xml_dir = path($Bin, 'corpus', 'inputXML');
my $internal_test = path($xml_dir, 'basic_rules.xml');

my $ITS = ITS->new(file => $internal_test);
my $rules = $ITS->get_rules();
is($#$rules, 2, 'two rules in file');
is($rules->[0]->att('xml:id'), 'first', 'correct first rule');
is($rules->[1]->att('xml:id'), 'second', 'correct second rule');
is($rules->[2]->att('xml:id'), 'third', 'correct third rule');


my $external_test = path($xml_dir, 'test_external.xml');

