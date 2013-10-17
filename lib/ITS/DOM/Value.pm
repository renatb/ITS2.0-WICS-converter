#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::DOM::Value;

use strict;
use warnings;
our $VERSION = '0.03'; # VERSION
# ABSTRACT: thin wrapper around underlying XML engine value objects
use Carp;
use feature 'switch';


sub new {
    my ($class, $value) = @_;
    return bless {
        type => _get_type($value),
        value => $value->value(),
        }, $class;
}

sub type{
    my ($self) = @_;
    return $self->{type};
}

sub value {
    my ($self) = @_;
    return $self->{value};
}

sub as_xpath {
    my ($self) = @_;
    if($self->type eq 'BOOL'){
        return $self->value ? 'true()' : 'false()';
    }elsif($self->type eq 'NUM'){
        return $self->value;
    }
    #$self->type eq 'LIT'
    my $lit = $self->value;
    #escape single quotes and return single quoted string
    $lit =~ s/'/&#39;/g;
    return "'$lit'";
}

sub _get_type {
    my ($value) = @_;
    #get the type from the XML::LibXML::* class name
    given(ref $value){
        when(/Literal/){
            return 'LIT';
        }
        when(/Boolean/){
            return 'BOOL';
        }
        when(/Number/){
            return 'NUM';
        }
    }
    croak "Unkown value type $value";
}

1;

__END__

=pod

=head1 NAME

ITS::DOM::Value - thin wrapper around underlying XML engine value objects

=head1 VERSION

version 0.03

=head1 SYNOPSIS

    use ITS::DOM;
    use feature 'say';
    my $dom = ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_xpath('"some string"');
    for my $node (@nodes){
        say $node->value;
    }

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It is a thin wrapper around an XML::LibXML::(Literal|Boolean|Number)
objects. There are only two methods (besides C<new>), which are held in common with
ITS::DOM::Node.

=head1 METHODS

=head2 C<new>

Creates a new value object to wrap the input XML::LibXML object.

=head2 C<type>

Returns a string representing the type of the node:
C<LIT> (for literal, or string), C<NUM> or C<BOOL>.

=head2 C<value>

Returns the underlying Perl value of the type represented
by this object: a string, a boolean, or a number.

=head2 C<as_xpath>

Returns the value of this object as an XPath expression.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
