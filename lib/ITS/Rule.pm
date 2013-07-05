package ITS::Rule;
use strict;
use warnings;
use Carp;

=head1 METHODS

=head2 C<new>

Arguments: an ITS::DOM node of type ELT and a hash representing
parameter names and values usable by this rule.

Creates a new C<Rule> instance.

=cut

sub new {
    my ($class, $el, %params) = @_;
    my $type = $el->local_name;
    $type =~ s/Rule$//;
    my $atts = $el->atts;

    my $selector = undef;
    if(!$atts->{selector}){
        carp "$type rule is missing selector! No nodes will match.";
    }else{
        $selector = $atts->{selector};
    }

    # TODO: is this too forgiving? Should I be checking for
    # the correct pointer which matches the element name?
    my @pointer = sort grep {$_ =~ /.+Pointer$/} keys %$atts;

    # TODO: this is fine for now, but any extions or updates
    # to ITS could require saving more information than just
    # the tag and text of the children.
    my @children;
    for(@{$el->children}){
        push @children, [$_->name, $_->text];
    }

    my $self = bless {
        type => $type,
        atts => $atts,
        selector => $selector,
        pointers => \@pointer,
        children => \@children,
        params => \%params || {},
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

=head2 C<params>

Returns a hash pointer containing all of the paramater names and
their values.

=cut

sub params {
    my ($self, $name) = @_;
    return $self->{params};
}

=head2 C<att>

Returns the value of the attribute with the given name.

=cut

sub att {
    my ($self, $name) = @_;
    return $self->{atts}->{$name};
}

=head2 C<atts>

Returns a hash pointer containing all of the attribute names
and values;

=cut

sub atts {
    my ($self) = @_;
    return $self->{atts};
}

=head2 C<pointers>

Returns an array pointer containing the names of attributes which are pointers
(or relative selectors).

=cut

sub pointers {
    my ($self) = @_;
    return $self->{pointers};
}

=head2 C<children>

Returns an array ref; each element is an array ref containing [element name, element text]
for each of the child elements of the original rule XML element.

=cut

sub children {
    my ($self) = @_;
    return $self->{children};
}

=head2 C<selector>

Returns the value of this rule's C<selector> attribute, which is used
to apply the rule meta-data to document nodes.

=cut

sub selector {
    my ($self) = @_;
    return $self->{selector};
}

=head2 C<as_element>

Returns an XML element representing the rule. The rule tag will be prefixed
with C<its:>, but the attribute C<xmnls:its> will not be declared. The namespace
C<its> should correspond to C<http://www.w3.org/2005/11/its> in the part of
the document where the returned
element is used.

=cut

sub as_element {
    my ($self) = @_;
    return 'TODO';
}

1;
