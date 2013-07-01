package ITS::Rule;
use strict;
use warnings;


=head1 METHODS

=head2 C<new>

Arguments: an XML element and a hash representing parameter names
and values usable by this rule.

Creates a new C<Rule> instance.

=cut

sub new {
    my ($class, $el, $params) = @_;
    my $type = $el->tag;
    $type =~ s/Rule$//;
    my $atts = $el->atts;

    #TODO: is this too forgiving? Should I be checking for the correct pointer?
    my @pointer = grep {$_ =~ /.+Pointer$/} keys %$atts;
    #textAnalysisRule has more than one pointer!

    my $self = bless {
        type => $type,
        atts => $atts,
        pointers => \@pointer,
        params => $params || {},
    }, $class;
    return $self;
}

=head2 C<type>

Returns the type of the rule (C<lang>, C<locNote>, etc.).

=cut

sub type {
    my ($self) = @_;
    return $self->{type};
}

=head2 C<att>

Returns the value of the attribute with the given name.

=cut

sub att {
    my ($self, $name) = @_;
    return $self->{atts}->{$name};
}

=head2 C<as_element>

Returns an XML element representing the rule

=cut

sub as_element {
    my ($self) = @_;
    return 'TODO';
}

1;
