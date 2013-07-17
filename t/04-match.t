# check that rule matches are found and iterated properly
use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 9;
use Test::Warn;
use Data::Section::Simple qw(get_data_section);

my $all_data = get_data_section;

test_basic(
    \($all_data->{document}), \($all_data->{basic_rule}));
test_param(
    \($all_data->{document}), \($all_data->{param_rule}));
test_pointer(
    \($all_data->{document}), \($all_data->{pointer_rule}));
test_pointer_params(
    \($all_data->{document}), \($all_data->{pointer_param_rule}));
test_pointer_position_size(
    \($all_data->{document}), \($all_data->{pointer_position_size_rule}));
test_namespaces(
    \($all_data->{namespaced_document}), \($all_data->{namespace_rules}));
test_warnings(
    \($all_data->{document}), \($all_data->{warning_rules}));

#test out a basic rule match, no pointers or parameters
sub test_basic {
    my ($doc_text, $rules_text) = @_;
    subtest 'basic rule with no pointers' => sub {
        plan tests => 3;
        my $ITS = ITS->new(
            'xml',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a translateRule with selector id('par1Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'par1Id',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer matches');
    };
}

#test that rules parameters are used in global matching
sub test_param {
    my ($doc_text, $rules_text) = @_;
    subtest 'rule with parameter' => sub {
        plan tests => 3;
        my $ITS = ITS->new(
            'xml',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a translateRule with selector id('par1Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'par1Id',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer matches');
    };
}

#test that pointer XPaths are resolved and returned in matches
sub test_pointer {
    my ($doc_text, $rules_text) = @_;
    subtest 'rule with pointer' => sub {
        plan tests => 7;
        my $ITS = ITS->new(
            'xml',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a locNoteRule with selector id('par2Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'par2Id',
            'correct rule selector match'
        );
        ok($match->{locNotePointer}, 'there is a locNotePointer value');
        is(
            $match->{locNotePointer}->type,
            'ATT',
            '...which is an attribute'
        );
        is(
            $match->{locNotePointer}->name,
            'note',
            '...named "note"'
        );
        is(
            $match->{locNotePointer}->value,
            'some loc note',
            '...with a value of "some loc note"'
        );
        is(scalar keys %$match, 2, 'only one pointer match');
    };
}

#test that pointer XPaths are resolved and returned in matches
sub test_pointer_params {
    my ($doc_text, $rules_text) = @_;
    subtest 'pointer with parameter' => sub {
        plan tests => 7;
        my $ITS = ITS->new(
            'xml',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a locNoteRule with selector id('par2Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'par2Id',
            'correct rule selector match'
        );
        ok($match->{locNotePointer}, 'there is a locNotePointer value');
        is(
            $match->{locNotePointer}->type,
            'ATT',
            'locNotePointer matched an attribute'
        );
        is(
            $match->{locNotePointer}->name,
            'note',
            '...named "note"'
        );
        is(
            $match->{locNotePointer}->value,
            'some loc note',
            '...with a value of "some loc note"'
        );
        is(scalar keys %$match, 2, 'only one pointer match');
    };
}

#test that XPath context size and position are properly set for relative selectors
#do this by setting an idValueRule idValue to use position() and last() functions
sub test_pointer_position_size {
    my ($doc_text, $rules_text) = @_;
    subtest 'pointer with position() and last()' => sub {
        plan tests => 16;
        my $ITS = ITS->new(
            'xml',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # should match 3 par elements
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 3, 'found three rule matches');
        for my $i(1..3){
            my $match = $matches->[$i-1];
            is(
                $match->{selector}->att('xml:id'),
                "par${i}Id",
                $i . "th rule matches par${i}Id",
            );
            ok(exists $match->{idValue}, 'there is an "idValue" value');
            is(
                $match->{idValue}->type,
                'LIT',
                'idValue matched a literal'
            );
            is(
                $match->{idValue}->value,
                "par_${i}_of_3",
                "...with a value of par_${i}_of_3"
            );
            is(scalar keys %$match, 2, 'no pointers besides idValue');
        }
    };
}

#test that correct namespaces are in scope
sub test_namespaces {
    my ($doc_text, $rules_text) = @_;

    my $ITS = ITS->new(
        'xml',
        doc => $doc_text,
        rules => $rules_text,
    );

    my $rules = $ITS->get_rules;
    # should match one foo:par element
    my $matches = $ITS->get_matches($rules->[0]);

    subtest 'rule-scope namespaces available in XPath contexts' => sub {
        plan tests => 5;
        is(scalar @$matches, 1, 'found one match');
        my $match = $matches->[0];
        is($match->{selector}->att('xml:id'), 'par1Id', 'correct node selected');
        ok(exists $match->{idValue}, 'there is an "idValue" value');
        is(
            $match->{idValue}->type,
            'LIT',
            'idValue matched a literal'
        );
        is(
            $match->{idValue}->value,
            'xyz123',
            "...with a value of xyz123"
        );
    };

    todo:{
        local $TODO = 'LibXML cannot remove namespaces in context node scope';
        # should match one baz:par element
        $matches = $ITS->get_matches($rules->[1]);
        subtest 'namespaces on selected node unavailable to XPath contexts' => sub {
            plan tests => 3;
            is(scalar @$matches, 1, 'found one match');
            my $match = $matches->[0];
            is(
                $match->{selector}->att('xml:id'),
                'par2Id',
                'correct node selected'
            );
            is(
                $match->{idValue},
                undef,
                'no match for item in missing namespace'
            );
        };
    }
}

sub test_warnings {
    my ($doc_text, $rules_text) = @_;
    my $ITS = ITS->new(
        'xml',
        doc => $doc_text,
        rules => $rules_text,
    );
    my $rules = $ITS->get_rules;

    subtest 'rule with pointer to nothing' => sub {
        plan tests => 4;
        # match of a locNoteRule with selector id('par2Id')
        my $matches;
        warning_like
            { $matches = $ITS->get_matches($rules->[0]) }
            {carped => qr/\@foot returned 0 nodes/},
            'error for no pointer match';

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'par2Id',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer match');
    };

    subtest 'rule with pointer to nothing' => sub {
        plan tests => 6;
        # match of a locNoteRule with selector id('par2Id')
        my $matches;
        warning_like
            { $matches = $ITS->get_matches($rules->[1]) }
            {carped => qr(//par returned 3 nodes) },
            'error for multiple pointer matches';

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'par2Id',
            'correct rule selector match'
        );
        ok($match->{locNotePointer}, 'there is a locNotePointer value');
        is(
            $match->{locNotePointer}->att('xml:id'),
            'par1Id',
            '...and its id is "par1Id"'
        );
        is(scalar keys %$match, 2, 'only one pointer match used');
    };
}

__DATA__
@@ document
<?xml version="1.0"?>
<myDoc id="myDocId">
    <body id="bodyId">
    <par xml:id="par1Id" title="Text">
        The <trmark id="trmarkId">World Wide Web Consortium</trmark>
        is making the World Wide Web worldwide!
    </par>
    <par xml:id="par2Id" note="some loc note">
        Nothing interesting here!
    </par>
    <par xml:id="par3Id">
        Nothing interesting here, either!
    </par>
    </body>
</myDoc>

@@ basic_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
        <its:translateRule
            xml:id="rule1"
            selector="id('par1Id')"
            translate="yes"/>
</its:rules>

@@ param_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
        <its:param name="parId">par1Id</its:param>
        <its:translateRule
            xml:id="rule2"
            selector="id($parId)"
            translate="yes"/>
</its:rules>

@@ pointer_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
      <its:locNoteRule
        locNoteType="description"
        selector="id('par2Id')"
        locNotePointer="@note"/>
</its:rules>

@@ pointer_param_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
      <its:param name="noteAtt">note</its:param>
      <its:locNoteRule
        locNoteType="description"
        selector="id('par2Id')"
        locNotePointer="@*[name()=$noteAtt]"/>
</its:rules>

@@ pointer_position_size_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
    <its:idValueRule
    selector="//par"
    idValue="concat('par_', position(), '_of_', last())"/>
</its:rules>

@@ namespaced_document
<?xml version="1.0"?>
<myDoc id="myDocId">
    <body id="bodyId">
    <foo:par xml:id="par1Id" xmlns:foo="www.foo.com">
        <foo:id>xyz123</foo:id>
        Nothing interesting here!
    </foo:par>
    <baz:par xml:id="par2Id"
        xmlns:baz="www.baz.com"
        xmlns:bar="www.bar.com">
        <bar:id>another loc note</bar:id>
        Nothing interesting here, either!
    </baz:par>
    </body>
</myDoc>

@@ namespace_rules
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">

    <its:idValueRule
        xmlns:foo="www.foo.com"
        selector="//foo:par"
        idValue="string(foo:id)"/>

    <its:idValueRule
        xmlns:baz="www.baz.com"
        selector="//baz:par"
        idValue="string(bar:id)"/>
</its:rules>

@@ warning_rules
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
      <its:locNoteRule
        locNoteType="description"
        selector="id('par2Id')"
        locNotePointer="@foot"/>
      <its:locNoteRule
        locNoteType="description"
        selector="id('par2Id')"
        locNotePointer="//par"/>
</its:rules>
