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

subtest 'parameters resolved' => sub {
    plan tests => 7;
    my $param_test = path($xml_dir, 'test_param.xml');
    my $ITS = ITS->new(file => $param_test);
    my $rules = $ITS->get_rules();

    is($#$rules, 2, 'three rules in file');

    my $ext_rule = $rules->[0];
    is($ext_rule->att('xml:id'), 'ext_rule', 'external rule first');
    is_deeply(
        $ext_rule->params,
        {
            title   => 'Text',
            trmarkId=> 'notran',
            baz     => 'qux',
            foo     => 'bar2',
        },
        'external rule params');

    my $idValRule = $rules->[1];
    is($idValRule->att('xml:id'), 'idValRule', 'internal rule next');
    is_deeply(
        $idValRule->params,
        {
            title   => 'Text',
            trmarkId=> 'notran',
            foo     => 'bar1',
        },
        'internal rule params');

    my $locNoteRule = $rules->[2];
    is($locNoteRule->att('xml:id'), 'locNoteRule', 'last internal rule last');
    is_deeply(
        $locNoteRule->params,
        {
            title   => 'Text',
            trmarkId=> 'notran',
            foo     => 'bar1',
        },
        'last rule params');

};
