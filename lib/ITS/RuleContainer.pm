package ITS::RuleContainer;
use strict;
use warnings;
use ITS::Rule;
# VERSION
# ABSTRACT: Store one its:rules element worth of information

=head1 SYNOPSIS

    use ITS;
    use ITS::RuleContainer;
    my $ITS = ITS->new('xml', doc =>'/path/to/doc.xml');
    my ($container) = $ITS->get_containers();
    my $params = $container->params;
    for my $param (my ($name, $val) = each %{$params}){
        print "$name = $val\n";
    }
    for my $rule (@{ $container->rules }){
        print $rule->type . "\n";
    }

=head1 DESCRIPTION

This package represents a container for ITS rules. Rule containers have
information on the employed ITS version, the query language used in selectors,
and parameters available to contained rules. This package is a way to store
this information and make it available to the ITS C<*Rule>s contained.

=head1 METHODS

=head2 C<new>

Creates a new RuleContainer object. The first argument should
be the original element which this container is representing
(C<its:rules> in XML and C<sript type="application/its+xml"> in HTML).
The others are named arguments:

=over

=item version

The version of ITS used in the container.

=item query_language

The query language used by the rules in the container. This defaults to 'xpath',
which indicates the use of XPath 2.0 in ITS.

=item params

A hashref containing all params available to the rules in the container
(both those declared in the container and those declared in the container
that included this one via C<xlink:href>).

=item rules

An arrayref of C<ITS::DOM::Element>s representing the rules inside this
container.

=back

=cut
sub new {
    my ($class, $el, %args) = @_;

    #TODO: input checking
    my $self = bless {
        element => $el,
        version => $args{version},
        query_language => $args{query_language} || 'xpath',
        params => \%{$args{params} || {}}
    }, $class;
    $self->{rules} = [map {ITS::Rule->new($_, $self)} @{$args{rules}}];
    return $self;
}

=head2 C<element>

Returns the original ITS::DOM::Element represented by this container

=cut
sub element {
    my ($self) = @_;
    return $self->{element};
}

=head2 C<version>

Returns the version of ITS employed by this container.

=cut
sub version {
    my ($self) = @_;
    return $self->{version};
}

=head2 C<query_language>

Returns the name of the query language employed by the rules in this container.

=cut
sub query_language {
    my ($self) = @_;
    return $self->{query_language};
}

=head2 C<rules>

Returns an arrayref containing C<ITS::Rule> objects for the ITS rules
declared in this container.

=cut
sub rules {
    my ($self) = @_;
    # shallow copy
    return [@{ $self->{rules} }];
}

=head2 C<params>

Returns a hashref containing names and values of the parameters available to
this container.

=cut
sub params {
    my ($self) = @_;
    # safe copy
    return \%{$self->{params}};
}

=head1 TODO

This package does not yet support foreign (non-ITS) elements placed
in the its:rules element.

1;