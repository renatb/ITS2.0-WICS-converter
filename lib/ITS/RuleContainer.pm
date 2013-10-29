#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::RuleContainer;
use strict;
use warnings;
use ITS::Rule;
our $VERSION = '0.04'; # VERSION
# ABSTRACT: Store one C<< <its:rules> >> element worth of information

sub new {
    my ($class, $el, %args) = @_;

    #TODO: input checking
    my $self = bless {
        element => $el,
        version => $args{version},
        query_language => $args{query_language} || 'xpath',
        params => \%{$args{params} || {}},
        script => $args{script}
    }, $class;
    $self->{rules} = [map {ITS::Rule->new($_, $self)} @{$args{rules}}];
    return $self;
}

sub element {
    my ($self) = @_;
    return $self->{element};
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
    my ($self) = @_;
    # shallow copy
    return [@{ $self->{rules} }];
}

sub params {
    my ($self) = @_;
    # safe copy
    return \%{$self->{params}};
}

sub script {
    my ($self) = @_;
    return $self->{script} if($self->{script});
    return;
}

1;

__END__

=pod

=head1 NAME

ITS::RuleContainer - Store one C<< <its:rules> >> element worth of information

=head1 VERSION

version 0.04

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
(C<< <its:rules> >>). The others are named arguments:

=over

=item C<version>

The version of ITS used in the container.

=item C<query_language>

The query language used by the rules in the container. This defaults to 'xpath',
which indicates the use of XPath 2.0 in ITS.

=item C<params>

A hashref containing all params available to the rules in the container
(both those declared in the container and those declared in the container
that included this one via C<xlink:href>).

=item C<script>

The script element containing this RuleContainer as text. This is applicable only
to HTML documents.

=item C<rules>

An arrayref of C<ITS::DOM::Element>s representing the rules inside this
container.

=back

=head2 C<element>

Returns the original C<ITS::DOM::Element> represented by this container.

=head2 C<version>

Returns the version of ITS employed by this container.

=head2 C<query_language>

Returns the name of the query language employed by the rules in this container.

=head2 C<rules>

Returns an arrayref containing C<ITS::Rule> objects for the ITS rules
declared in this container.

=head2 C<params>

Returns a hashref containing names and values of the parameters available to
this container.

=head2 C<script>

Returns the  C<script> element which holds the return value of C<element>,
but as text. Applicable only to HTML documents

=head1 TODO

This package does not yet support foreign (non-ITS) elements placed
in the its:rules element.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
