# Make sure that rules are extracted correctly and are
# stored in proper application order

use strict; use warnings;
use XML::ITS;
use Test::More 0.88;
plan tests => 7;
use Test::NoWarnings;
use Path::Tiny;
use FindBin qw($Bin);
use File::Slurp;

my $xml_dir = path($Bin, 'corpus');

subtest 'internal rules' => sub {
    plan tests => 4;
    my $internal_test = path($xml_dir, 'basic_rules.xml');

    my $ITS = XML::ITS->new('xml', doc => $internal_test);
    my $rules = $ITS->get_rules();
    is(@$rules, 3, 'three rules in basic_rules.xml');
    is($rules->[0]->element->att('xml:id'), 'first', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'second', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'third', 'correct third rule');
};

subtest 'external rules' => sub {
    plan tests => 4;
    my $external_test = path($xml_dir, 'test_external.xml');
    my $ITS = XML::ITS->new('xml', doc => $external_test);
    my $rules = $ITS->get_rules();

    is(@$rules, 3, 'four rules in file');
    is($rules->[0]->element->att('xml:id'), 'ext3rule', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'ext2rule', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'ext1rule', 'correct third rule');
};

subtest 'external and internal rules' => sub {
    plan tests => 5;
    my $external_test = path($xml_dir, 'test_external_internal.xml');
    my $ITS = XML::ITS->new('xml', doc => $external_test);
    my $rules = $ITS->get_rules();

    is(@$rules, 4, 'four rules in file');
    is($rules->[0]->element->att('xml:id'), 'ext3rule', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'ext2rule', 'correct second rule');
    is($rules->[2]->element->att('xml:id'), 'ext1rule', 'correct third rule');
    is($rules->[3]->element->att('xml:id'), 'baseFileRule', 'correct fourth rule');
};

subtest 'parameters resolved' => sub {
    plan tests => 7;
    my $param_test = path($xml_dir, 'test_param.xml');
    my $ITS = XML::ITS->new('xml', doc => $param_test);
    my $rules = $ITS->get_rules();

    is(@$rules, 3, 'three rules in file');

    my $ext_rule = $rules->[0];
    is($ext_rule->element->att('xml:id'), 'ext_rule', 'external rule first');
    is_deeply(
        $ext_rule->params,
        {
            title   => 'Text',
            trmarkId=> 'notran',
            baz     => 'qux',
            foo     => 'bar2',
        },
        'external rule params');

    my $params = {
        title   => 'Text',
        trmarkId=> 'notran',
        foo     => 'bar1',
    };
    my $idValRule = $rules->[1];
    is($idValRule->element->att('xml:id'), 'idValRule', 'internal rule next');
    is_deeply(
        $idValRule->params, $params, 'internal rule params');

    my $locNoteRule = $rules->[2];
    is($locNoteRule->element->att('xml:id'), 'locNoteRule', 'last internal rule last');
    is_deeply(
        $locNoteRule->params, $params, 'last rule params');
};

subtest 'params contained to one its:rules element' => sub {
    plan tests => 5;
    my $ITS = XML::ITS->new('xml', doc => \<<'XML');
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

    my $rules = $ITS->get_rules();
    is(@$rules, 2, '2 rules in string');

    my $rule = $rules->[0];
    is($rule->element->att('xml:id'), 'rule1', 'correct first rule');
    is_deeply($rule->params, {bar => 'baz'}, '1 param in first rule');

    $rule = $rules->[1];
    is($rule->element->att('xml:id'), 'rule2', 'correct second rule');
    is_deeply($rule->params, {qux => 'muck'}, '1 param in first rule');
};

subtest 'rules and document from separate strings' => sub {
    plan tests => 3;
    my $ITS = XML::ITS->new('xml', doc => \<<'XML', rules => \<<'RULES');
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

    my $rules = $ITS->get_rules();
    is(scalar @$rules, 2, '2 rules in string');
    is($rules->[0]->element->att('xml:id'), 'idValRule', 'correct first rule');
    is($rules->[1]->element->att('xml:id'), 'locNoteRule', 'correct second rule');;
};
