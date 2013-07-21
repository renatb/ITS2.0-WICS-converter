package XML::ITS::DOM::Value;

use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine value objects
use Carp;
use feature 'switch';

=head1 SYNOPSIS

    use XML::ITS::DOM;
    use feature 'say';
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
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