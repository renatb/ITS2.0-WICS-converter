# check that rule matches are found and iterated properly
use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 3;
use Data::Section::Simple qw(get_data_section);

my $all_data = get_data_section;

test_basic(
    \($all_data->{document}), \($all_data->{basic_rule}));

test_param(
    \($all_data->{document}), \($all_data->{param_rule}));

test_pointer(
    \($all_data->{document}), \($all_data->{pointer_rule}));

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
        # match of a translateRule with selector id('parId')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'parId',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer matches');
    };
}

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
        # match of a translateRule with selector id('parId')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('xml:id'),
            'parId',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer matches');
    };
}

sub test_pointer {
    my ($doc_text, $rules_text) = @_;
    subtest 'rule with parameter' => sub {
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
            'locNotePointer matched an attribute...'
        );
        is(
            $match->{locNotePointer}->name,
            'note',
            '  named "note"...'
        );
        is(
            $match->{locNotePointer}->value,
            'some loc note',
            '  with a value of "some loc note"'
        );
        is(scalar keys %$match, 2, 'only one pointer match');
    };
}

__DATA__
@@ document
<?xml version="1.0"?>
<myDoc id="myDocId">
    <body id="bodyId">
    <par xml:id="parId" title="Text">
        The <trmark id="trmarkId">World Wide Web Consortium</trmark>
        is making the World Wide Web worldwide!
    </par>
    <par xml:id="par2Id" note="some loc note">
        Nothing interesting here!
    </par>
    </body>
</myDoc>

@@ basic_rule
<its:rules xml:id='container1'
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
        <its:translateRule
            xml:id="rule1"
            selector="id('parId')"
            translate="yes"/>
</its:rules>

@@ param_rule
<its:rules xml:id='container2'
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
        <its:param name="parId">parId</its:param>
        <its:translateRule
            xml:id="rule2"
            selector="id($parId)"
            translate="yes"/>
</its:rules>

@@ pointer_rule
<its:rules xml:id='container2'
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
      <its:locNoteRule
        locNoteType="description"
        selector="id('par2Id')"
        locNotePointer="@note"/>
</its:rules>
