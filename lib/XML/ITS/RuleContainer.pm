package XML::ITS::RuleContainer;
use strict;
use warnings;
use XML::ITS::Rule;
# VERSION
# ABSTRACT: Store one its:rules element worth of information

#not much in the way of input checking here...
sub new {
    my ($class, %args) = @_;

    my $self = bless {
        version => $args{version},
        query_language => $args{query_language},
        params => $args{params} || {}
    }, $class;
    $self->{rules} = [map {XML::ITS::Rule->new($_, $self)} @{$args{rules}}];
    return $self;
}

sub version {
    my ($self) = @_;
    return $self->{version};
}

sub query_language {
    my ($self) = @_;
    return $self->{query_language};
}

sub rules {
    my ($self, $rules) = @_;
    if($rules){
        #store shallow copy
        @{ $self->{rules} } = @$rules;
    }
    #return shallow copy
    return [@{ $self->{rules} }];
}

sub params {
    my ($self, $params) = @_;

    return $self->{params};
}

1;