#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::Rule;
use strict;
use warnings;
use Carp;
# ABSTRACT: Wrapper around ITS:*Rule elements
our $VERSION = '0.04'; # VERSION

sub new {
    my ($class, $el, $container) = @_;
    my $type = $el->local_name;
    $type =~ s/Rule$//
        or croak "Element $type is not an ITS rule element.";

    if(!$el->att('selector')){
        carp "$type rule is missing a selector! No nodes will match.";
    }

    my $self = bless {
        type => $type,
        node => $el,
        container => $container,
    }, $class;
    return $self;
}


sub type {
    my ($self) = @_;
    return $self->{type};
}


sub params {
    my ($self) = @_;
    return $self->{container}->params;
}


sub pointers {
    my ($self) = @_;
    # TODO: is this too forgiving? Should I be checking for
    # the correct pointer which matches the element name?
    my $atts = $self->{node}->atts;
    my @pointers = sort grep {$_ =~ /.+Pointer$/} keys %$atts;
    if($self->type eq 'idValue' && exists $atts->{idValue}){
        push @pointers, 'idValue';
    }
    return \@pointers;
}


sub selector {
    my ($self) = @_;
    return $self->{node}->att('selector');
}


sub element {
    my ($self) = @_;
    return $self->{node};
}

sub value_atts {
    my ($self) = @_;
    my $atts = $self->{node}->atts;
    my @value_atts = sort grep {
        $_ !~ /.+Pointer$/ and
        $_ ne 'idValue' and
        $_ ne 'selector' and
        $_ !~ /xmlns/
    } keys %$atts;
    return \@value_atts;
}

1;

__END__

=pod

=head1 NAME

ITS::Rule - Wrapper around ITS:*Rule elements

=head1 VERSION

version 0.04

=head1 SYNOPSIS

    use ITS;
    use ITS::Rule;
    use feature 'say';
    my $ITS = ITS->new(file => 'myITSfile.xml');
    my $rules = $ITS->get_rules;
    say $_->type for @$rules;

=head1 DESCRIPTION

This package is a thin wrapper around an ITS::DOM::Node object. It provides
convenience methods for working with ITS::*Rule elements, such as locNoteRule
and translateRule.

=head1 METHODS

=head2 C<new>

Arguments: an ITS::DOM::Node node of type ELT and a hash representing
parameter names and values usable by this rule.

Creates a new C<Rule> instance.

This class is only a thin wrapper around the methods in ITS::DOM::Node.
A reference to the input element is stored, and any changes to it will
be reflected in the methods of this class.

=head2 C<type>

Returns the type of the rule (C<lang>, C<locNote>, etc.).

=head2 C<params>

Returns a hash pointer containing all of the paramater names and
their values.

=head2 C<pointers>

Returns an array ref containing the names of attributes which are pointers
(relative selectors).

=head2 C<selector>

Returns the value of this rule's C<selector> attribute, which is used
to apply the rule meta-data to document nodes.

=head2 C<element>

Returns the ITS::DOM::Element that this rule represents.

=head2 C<value_atts>

Returns an array ref containing the names of the attributes of this rule
that are neither a C<pointer> attribute nor the C<selector>. For example,
the C<translate> attribute of a C<its:translateRule> would be returned.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
