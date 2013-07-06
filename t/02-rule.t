# Test Rule methods

use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 5;
use Test::Warn;
use Test::NoWarnings;
use XML::Twig::XPath;
use ITS::DOM qw(new_element);

subtest 'basic rule' => sub {
    plan tests => 5;
    my $attributes = {
        'xmlns:its' => 'http://www.w3.org/2005/11/its',
        'selector' => 'id("id_1")',
        'storageSize' => '8',
        'storageEncoding' => 'UTF-8',
    };
    my $rule = ITS::Rule->new(new_element('its:storageSizeRule' => $attributes));
    is($rule->type, 'storageSize', 'rule name');
    is_deeply($rule->node->atts, $attributes, 'rule attributes');
    is($rule->node->att('storageSize'), '8', 'attribute accessor');
    is($rule->selector, 'id("id_1")', 'selector accessor');
    is_deeply($rule->params, {}, 'no parameters');
};

subtest 'parameters' => sub {
    plan tests => 1;
    my $params = {
        x => 'x value',
        y => 'y value',
    };
    my $el = new_element(
        'its:storageSizeRule' => {
            'xmlns:its' => 'http://www.w3.org/2005/11/its',
            'selector' => 'id("id_1")',
            'storageSize' => '8',
            'storageEncoding' => 'UTF-8',
        }
    );
    my $rule = ITS::Rule->new($el, %$params);
    is_deeply($rule->params, $params, 'parameter values')
};

subtest 'pointer attributes' => sub {
    plan tests => 1;
    my $el = new_element(
        'its:storageSizeRule' => {
            'xmlns:its' => 'http://www.w3.org/2005/11/its',
            'selector' => 'id("id_1")',
            'storageSizePointer' => '@size',
            'storageEncodingPointer' => '@encoding',
        }
    );
    my $rule = ITS::Rule->new($el);
    is_deeply($rule->pointers,
        [qw(storageEncodingPointer storageSizePointer)],
        'pointer attributes'
    );
};

my $el = new_element(
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
warning_is {my $rule = ITS::Rule->new($el)}
    'storageSize rule is missing a selector! No nodes will match.',
    'warn on missing selector';
