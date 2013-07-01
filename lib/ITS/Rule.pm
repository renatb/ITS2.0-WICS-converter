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
