# Make sure that rules are extracted correctly and are
# stored in proper application order

use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 4;
use Test::NoWarnings;
use Test::XML;
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $xml_dir = path($Bin, 'corpus');

subtest 'internal rules' => sub {
    plan tests => 4;
    my $internal_test = path($xml_dir, 'basic_rules.xml');

    my $ITS = ITS->new(file => $internal_test);
    my $rules = $ITS->get_rules();
    is($#$rules, 2, 'three rules in basic_rules.xml');
    is($rules->[0]->att('xml:id'), 'first', 'correct first rule');
    is($rules->[1]->att('xml:id'), 'second', 'correct second rule');
    is($rules->[2]->att('xml:id'), 'third', 'correct third rule');
};

subtest 'external and internal rules' => sub {
    plan tests => 5;
    my $external_test = path($xml_dir, 'test_external.xml');
    my $ITS = ITS->new(file => $external_test);
    my $rules = $ITS->get_rules();

    is($#$rules, 3, 'four rules in file');
    is($rules->[0]->att('xml:id'), 'ext3rule', 'correct first rule');
    is($rules->[1]->att('xml:id'), 'ext2rule', 'correct second rule');
    is($rules->[2]->att('xml:id'), 'ext1rule', 'correct third rule');
    is($rules->[3]->att('xml:id'), 'baseFileRule', 'correct fourth rule');
};

TODO: {
    local $TODO = 'its:param not implemented yet';
    subtest 'parameters resolved' => sub {
        plan tests => 1;
        ok(0);
    };
};