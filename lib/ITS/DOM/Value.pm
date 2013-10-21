package ITS::DOM::Value;

use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine value objects
use Carp;
use feature 'switch';

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

=cut

sub new {
    my ($class, $value) = @_;
    return bless {
        type => _get_type($value),
        value => $value->value(),
        }, $class;
}

=head2 C<type>

Returns a string representing the type of the node:
C<LIT> (for literal, or string), C<NUM> or C<BOOL>.

=cut
sub type{
    my ($self) = @_;
    return $self->{type};
}

=head2 C<value>

Returns the underlying Perl value of the type represented
by this object: a string, a boolean, or a number.

=cut
sub value {
    my ($self) = @_;
    return $self->{value};
}

=head2 C<as_xpath>

Returns the value of this object as an XPath expression.

=cut
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
    my $class = ref $value;
    if($class =~ /Literal/)     {return 'LIT';}
    elsif($class =~ /Boolean/)  {return 'BOOL';}
    elsif($class =~ /Number/)   {return 'NUM';}
    croak "Unkown value type $value";
}

1;