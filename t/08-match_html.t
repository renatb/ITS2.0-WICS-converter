# check that rule matches are found and iterated properly
use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 10;
use Test::Warn;
use Path::Tiny;
use FindBin qw($Bin);
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
    \($all_data->{document}),
    \($all_data->{warning_rules}),
    \($all_data->{default_ns_rules}));

#test out a basic rule match, no pointers or parameters
sub test_basic {
    my ($doc_text, $rules_text) = @_;
    subtest 'basic rule with no pointers' => sub {
        plan tests => 3;
        my $ITS = ITS->new(
            'html',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a translateRule with selector id('par1Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('id'),
            'par1Id',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer matches');
    };
    return;
}

#test that rules parameters are used in global matching
sub test_param {
    my ($doc_text, $rules_text) = @_;
    subtest 'rule with parameter' => sub {
        plan tests => 3;
        my $ITS = ITS->new(
            'html',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a translateRule with selector id('par1Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('id'),
            'par1Id',
            'correct rule selector match'
        );
        is(scalar keys %$match, 1, 'no pointer matches');
    };
    return;
}

#test that pointer XPaths are resolved and returned in matches
sub test_pointer {
    my ($doc_text, $rules_text) = @_;
    subtest 'rule with pointer' => sub {
        plan tests => 7;
        my $ITS = ITS->new(
            'html',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a locNoteRule with selector id('par2Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('id'),
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
    return;
}

#test that pointer XPaths are resolved and returned in matches
sub test_pointer_params {
    my ($doc_text, $rules_text) = @_;
    subtest 'pointer with parameter' => sub {
        plan tests => 7;
        my $ITS = ITS->new(
            'html',
            doc => $doc_text,
            rules => $rules_text,
        );

        my $rules = $ITS->get_rules;
        # match of a locNoteRule with selector id('par2Id')
        my $matches = $ITS->get_matches($rules->[0]);

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('id'),
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
    return;
}

#test that XPath context size and position are properly set for relative selectors
#do this by setting an idValueRule idValue to use position() and last() functions
sub test_pointer_position_size {
    my ($doc_text, $rules_text) = @_;
    subtest 'pointer with position() and last()' => sub {
        plan tests => 16;
        my $ITS = ITS->new(
            'html',
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
                $match->{selector}->att('id'),
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
    return;
}

#test that correct namespaces are in scope
sub test_namespaces {
    my ($doc_text, $rules_text) = @_;

    my $ITS = ITS->new(
        'html',
        doc => $doc_text,
        rules => $rules_text,
    );

    my $rules = $ITS->get_rules;
    # should match one foo:par element
    my $matches = $ITS->get_matches($rules->[0]);
    is(scalar @$matches, 0, q<namespaces don't work in HTML5>);

    return;
}

sub test_warnings {
    my ($doc_text, $rules_text, $default_ns_rules) = @_;
    my $ITS = ITS->new(
        'html',
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
            $match->{selector}->att('id'),
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
            {carped => qr(//h:p returned 3 nodes) },
            'error for multiple pointer matches';

        is(scalar @$matches, 1, 'found one rule match');
        my $match = $matches->[0];
        is(
            $match->{selector}->att('id'),
            'par2Id',
            'correct rule selector match'
        );
        ok($match->{locNotePointer}, 'there is a locNotePointer value');
        is(
            $match->{locNotePointer}->att('id'),
            'par1Id',
            '...and its id is "par1Id"'
        );
        is(scalar keys %$match, 2, 'only one pointer match used');
    };

    subtest 'rule with a non-element, non-attribute selector' => sub {
        plan tests => 3;
        # match of a locNoteRule with selector comment()
        my $msg = 'skipping match of illegal type COM ' .
            '(only ELT or ATT are allowed) from selector: ' .
            '/h:html/comment()|/h:html';
        my $matches;
        warning_is
            { $matches = $ITS->get_matches($rules->[2]) }
            {carped => $msg },
            'warning for illegal node type';
        is(scalar @$matches, 1, 'only one match retrieved');
        is($matches->[0]->{selector}->name, 'html', 'correct match');
    };
    $ITS = ITS->new(
        'html',
        doc => $doc_text,
        rules => $default_ns_rules,
    );
    my $matches = $ITS->get_matches($ITS->get_rules()->[0]);
    is(@$matches, 0, 'no matches found because of default HTML namespace');
    return;
}

__DATA__
@@ document
<!DOCTYPE html>
<html id="myDocId">
    <head>
        <title>WICS</title>
    </head>
    <body id="bodyId">
        <p id="par1Id" title="Text">
            The <span id="trmarkId">World Wide Web Consortium</span>
            is making the World Wide Web worldwide!
        </p>
        <p id="par2Id" note="some loc note">
            Nothing interesting here!
        </p>
        <p id="par3Id">
            Nothing interesting here, either!
        </p>
    </body>
    <!-- Some comment... -->
</html>

@@ basic_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">
        <its:translateRule
            xml:id="rule1"
            selector="//h:p[1]"
            translate="yes"/>
</its:rules>

@@ param_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">
        <its:param name="parId">par1Id</its:param>
        <its:translateRule
            id="rule2"
            selector="//h:p[@id=$parId]"
            translate="yes"/>
</its:rules>

@@ pointer_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">
      <its:locNoteRule
        locNoteType="description"
        selector="//h:p[2]"
        locNotePointer="@note"/>
</its:rules>

@@ pointer_param_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">
      <its:param name="noteAtt">note</its:param>
      <its:locNoteRule
        locNoteType="description"
        selector="//h:p[2]"
        locNotePointer="@*[name()=$noteAtt]"/>
</its:rules>

@@ pointer_position_size_rule
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">
    <its:idValueRule
    selector="//h:p"
    idValue="concat('par_', position(), '_of_', last())"/>
</its:rules>

@@ namespaced_document

<!DOCTYPE html>
<html>
    <body>
        <foo:p id="par1Id" xmlns:foo="www.foo.com">
            <foo:id>xyz123</foo:id>
            Nothing interesting here!
        </foo:p>
    </body>
</html>

@@ namespace_rules
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">

    <its:idValueRule
        xmlns:foo="www.foo.com"
        selector="//foo:p[1]"
        idValue="string(foo:id)"/>
</its:rules>

@@ warning_rules
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    xmlns:h="http://www.w3.org/1999/xhtml"
    version="2.0">
      <its:locNoteRule
        locNoteType="description"
        selector="//h:p[2]"
        locNotePointer="@foot"/>
      <its:locNoteRule
        locNoteType="description"
        selector="//h:p[2]"
        locNotePointer="//h:p"/>
      <its:locNoteRule
        locNoteType="description"
        selector="/h:html/comment()|/h:html"
        locNote="no comment!"/>
</its:rules>

@@ default_ns_rules
<?xml version="1.0"?>
<its:rules
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
  <its:translateRule
    selector="//p"
    translate="yes"/>
</its:rules>
