# Test Rule class methods (not creation from document)

use strict;
use warnings;
use ITS::Rule;
use Test::More 0.88;
plan tests => 6;
use Test::Warn;
use Test::NoWarnings;
use ITS::DOM;
use ITS::DOM::Element qw(new_element);
use ITS::RuleContainer;

my $plain_container = ITS::RuleContainer->new();

subtest 'basic rule' => sub {
    plan tests => 5;
    my $attributes = {
        'xmlns:its' => 'http://www.w3.org/2005/11/its',
        'selector' => 'id("id_1")',
        'storageSize' => '8',
        'storageEncoding' => 'UTF-8',
    };
    my $rule = ITS::Rule->new(
        new_element('its:storageSizeRule' => $attributes), $plain_container);
    is($rule->type, 'storageSize', 'rule name');
    is_deeply($rule->element->atts, $attributes, 'rule attributes');
    is($rule->element->att('storageSize'), '8', 'attribute accessor');
    is($rule->selector, 'id("id_1")', 'selector accessor');
    is_deeply($rule->params, {}, 'no parameters');
};

subtest 'parameters' => sub {
    plan tests => 1;
    my $params = {
        x => 'x value',
        y => 'y value',
    };
    my $container = ITS::RuleContainer->new(
            undef,
            params => $params,
        );
    my $el = new_element(
        'its:storageSizeRule' => {
            'xmlns:its' => 'http://www.w3.org/2005/11/its',
            'selector' => 'id("id_1")',
            'storageSize' => '8',
            'storageEncoding' => 'UTF-8',
        }
    );
    my $rule = ITS::Rule->new($el, $container);
    is_deeply($rule->params, $params, 'parameter values')
};

subtest 'pointer attributes' => sub {
    plan tests => 2;

    #test that *pointer atts are recognized as pointers
    my $el = new_element(
        'its:storageSizeRule' => {
            'xmlns:its' => 'http://www.w3.org/2005/11/its',
            'selector' => 'id("id_1")',
            'storageSizePointer' => '@size',
            'storageEncodingPointer' => '@encoding',
        }
    );
    my $rule = ITS::Rule->new($el, $plain_container);
    is_deeply($rule->pointers,
        [qw(storageEncodingPointer storageSizePointer)],
        '2 pointer attributes found'
    );

    #test that idValue is recognized as a pointer
    $el = new_element(
        'its:idValueRule' => {
            'xmlns:its' => 'http://www.w3.org/2005/11/its',
            'selector' => '//foo',
            'idValue' => '@name',
        }
    );
    $rule = ITS::Rule->new($el, $plain_container);
    is_deeply($rule->pointers,
        [qw(idValue)],
        'idValue is a pointer attribute'
    );
};

#test that value atts are recognized
my $el = new_element(
    'its:storageSizeRule' => {
        'xmlns:its' => 'http://www.w3.org/2005/11/its',
        'selector' => 'id("id_1")',
        'storageSizePointer' => '@size',
        'storageEncodingPointer' => '@encoding',
        'foo' => 'bar'
    }
);
is_deeply(ITS::Rule->new($el, $plain_container)->value_atts,
    [qw(foo)],
    '1 value attribute found'
);

#test that a warning is given for a missing selector
$el = new_element(
    'its:locNoteRule' => {
        'xmlns:its' => 'http://www.w3.org/2005/11/its',
        'locNoteType' => 'description',
        'selector' => '//*',
    }
);
$el = new_element(
    'its:storageSizeRule' => {
        'xmlns:its' => 'http://www.w3.org/2005/11/its',
        'storageSizePointer' => '@size',
        'storageEncodingPointer' => '@encoding',
    }
);
warning_is {my $rule = ITS::Rule->new($el, $plain_container)}
    'storageSize rule is missing a selector! No nodes will match.',
    'warn on missing selector';
