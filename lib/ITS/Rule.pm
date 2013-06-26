package ITS::Rule;
use strict;
use warnings;

sub new {
    my ($class, $el) = @_;
    my $type = $el->tag;
    $type =~ s/Rule$//;
    my $self = bless {type => $type}, $class;
    return $self;
}

1;

__DATA__
# YAML file containing information about the behavior of each rule
{
    translate => {
        global => {
            required => [selector, translate],
        },
        local => {
            required => [translate],
        },
        inherit => {
            text => 1,
            atts => 0,
        },
        html => {
            translate => 'translate'
        }
    },
    termRule => {
        global => {
            required => [selector, term],
            optional => [termInfoRef, termInfoPointer, termInfoRefPointer]
        }
        local => {
            required => [term],
            optional => [termInfoRef, termConfidence],
        },
        inherit => {
            text => 0,
            atts => 0,
        },
        html => {
            termInfoRef => 'its-term-info-ref',
            termConfidence => 'its-term-confidence',
        }
    },
}