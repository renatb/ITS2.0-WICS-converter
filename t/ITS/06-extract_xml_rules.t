# Make sure that RuleContainers and rules are extracted correctly from XML
# and that they are stored in proper application order

use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 8;
use Test::NoWarnings;
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $xml_dir = path($Bin, 'corpus', 'XML');

subtest 'internal rules' => sub {
    plan tests => 5;
    my $internal_test = path($xml_dir, 'basic_rules.xml');
    my $ITS = ITS->new('xml', doc => $internal_test);

    my $containers = $ITS->get_containers;
    is(@$containers, 1, 'one rule container found');

    my $rules = $ITS->get_rules();
    is(@$rules, 3, 'three rules in basic_rules.xml');
    is($rules->[0]->element->att('xml:id'), 'first', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'second', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'third', 'correct third rule');
};

subtest 'external rules' => sub {
    plan tests => 9;
    my $external_test = path($xml_dir, 'test_external.xml');
    my $ITS = ITS->new('xml', doc => $external_test);

    my $containers = $ITS->get_containers;
    is(@$containers, 4, 'four rule containers found');
    is($containers->[0]->element->att('xml:id'), 'ext3container',
        'correct second container');
    is($containers->[1]->element->att('xml:id'), 'ext2container',
        'correct third container');
    is($containers->[2]->element->att('xml:id'), 'ext1container',
        'correct fourth container');
    is($containers->[3]->element->att('xml:id'), 'baseFileContainer',
        'correct first container');

    my $rules = $ITS->get_rules();
    is(@$rules, 3, 'four rules in file');
    is($rules->[0]->element->att('xml:id'), 'ext3rule', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'ext2rule', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'ext1rule', 'correct third rule');
};

subtest 'external and internal rules' => sub {
    plan tests => 6;
    my $external_test = path($xml_dir, 'test_external_internal.xml');
    my $ITS = ITS->new('xml', doc => $external_test);
    my $rules = $ITS->get_rules();

    is(@$rules, 5, 'five rules in file');
    is($rules->[0]->element->att('xml:id'), 'ext3rule', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'ext2rule', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'ext1rule', 'correct third rule');
    is($rules->[3]->element->att('xml:id'), 'baseFileRule1', 'correct fourth rule');
    is($rules->[4]->element->att('xml:id'), 'baseFileRule2', 'correct fifth rule');
};

subtest 'parameters resolved' => sub {
    plan tests => 10;
    my $param_test = path($xml_dir, 'test_param.xml');
    my $ITS = ITS->new('xml', doc => $param_test);

    my $internal_params = {
        title   => 'Text',
        trmarkId=> 'notran',
        foo     => 'bar1',
    };
    my $external_params = {
        title   => 'Text',
        trmarkId=> 'notran',
        baz     => 'qux',
        foo     => 'bar2',
    };

    my $containers = $ITS->get_containers;
    is(@$containers, 2, 'two rule containers found');
    is_deeply(
        $containers->[0]->params, $external_params,
        'correct parameters in first container');
    is_deeply($containers->[1]->params, $internal_params,
        'correct parameters in second container');

    my $rules = $ITS->get_rules();
    is(@$rules, 3, 'three rules in file');
    my $ext_rule = $rules->[0];
    is($ext_rule->element->att('xml:id'), 'ext_rule', 'external rule first');
    is_deeply($ext_rule->params, $external_params, 'external rule params');

    my $idValRule = $rules->[1];
    is($idValRule->element->att('xml:id'), 'idValRule', 'internal rule next');
    is_deeply($idValRule->params, $internal_params, 'internal rule params');

    my $locNoteRule = $rules->[2];
    is($locNoteRule->element->att('xml:id'), 'locNoteRule', 'last internal rule last');
    is_deeply($locNoteRule->params, $internal_params, 'last rule params');
};

subtest 'params contained to one its:rules element' => sub {
    plan tests => 7;
    my $ITS = ITS->new('xml', doc => \<<'XML');
    <myDoc>
     <head>
        <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
            <its:param name="bar">baz</its:param>
            <its:locNoteRule xml:id="rule1" selector="id('Text')" locNote="foo"/>
        </its:rules>
        <its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
            <its:param name="qux">muck</its:param>
            <its:locNoteRule xml:id="rule2" selector="id('Text')" locNote="bar"/>
        </its:rules>
     </head>
     <body>
      <par id="100" title="Text">The
        <trmark id="notran">World Wide Web Consortium</trmark>
         is making the World Wide Web worldwide!
      </par>
     </body>
    </myDoc>
XML

    my $first_param = {bar => 'baz'};
    my $second_param = {qux => 'muck'};

    my $containers = $ITS->get_containers;
    is_deeply( $containers->[0]->params, $first_param,
        'correct parameters in first container');
    is_deeply( $containers->[1]->params, $second_param,
        'correct parameters in second container');

    my $rules = $ITS->get_rules();
    is(@$rules, 2, '2 rules in string');

    my $rule = $rules->[0];
    is($rule->element->att('xml:id'), 'rule1', 'correct first rule');
    is_deeply($rule->params, $first_param, '1 param in first rule');

    $rule = $rules->[1];
    is($rule->element->att('xml:id'), 'rule2', 'correct second rule');
    is_deeply($rule->params, $second_param, '1 param in first rule');
};

subtest 'rules and document from separate strings' => sub {
    plan tests => 4;
    my $ITS = ITS->new('xml', doc => \<<'XML', rules => \<<'RULES');
<myDoc>
 <body>
  <par id="100" title="Text">The
    <trmark id="notran">World Wide Web Consortium</trmark>
     is making the World Wide Web worldwide!
  </par>
 </body>
</myDoc>
XML
<its:rules xmlns:its="http://www.w3.org/2005/11/its" version="2.0">
    <its:idValueRule xml:id="idValRule" selector="id('Text')" idValue="bodyId"/>
    <its:locNoteRule xml:id="locNoteRule" selector="id('Text')" locNotePointer="id('notran')"/>
</its:rules>
RULES

    my $containers = $ITS->get_containers;
    is(@$containers, 1, 'one rule container found');

    my $rules = $ITS->get_rules();
    is(scalar @$rules, 2, '2 rules in string');
    is($rules->[0]->element->att('xml:id'), 'idValRule', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'locNoteRule', 'correct second rule');;
};

subtest 'eval_rules after editing DOM' => sub {
    plan tests => 8;
    my $external_test = path($xml_dir, 'basic_rules.xml');
    my $ITS = ITS->new('xml', doc => $external_test);

    my $containers = $ITS->get_containers;
    my $c1 = $containers->[0]->element;
    my $c2 = $c1->copy(1);
    $c2->paste($c1, 'after');
    $ITS->eval_rules;

    $containers = $ITS->get_containers;
    is(@$containers, 2, 'two containers found');
    my $rules = $ITS->get_rules();

    is(@$rules, 6, 'ten rules in DOM');
    is($rules->[0]->element->att('xml:id'), 'first', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'second', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'third', 'correct third rule');
    #new rules are copies of the others
    is($rules->[3]->element->att('xml:id'), 'first', 'correct fourth rule');
    is($rules->[4]->element->att('xml:id'), 'second', 'correct fifth rule');
    is($rules->[5]->element->att('xml:id'), 'third', 'correct sixth rule');
};
