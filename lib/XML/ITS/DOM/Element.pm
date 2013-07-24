package XML::ITS::DOM::Element;
use strict;
use warnings;
#VERSION
#ABSTRACT: Represents a DOM element
use Exporter::Easy (
    OK => [qw(new_element)]
);
use XML::LibXML;
use parent 'XML::ITS::DOM::Node';

=head1 SYNOPSIS

    use XML::ITS::DOM::Element qw(new_element);
    my $element = new_element('name', {att => 'value'}, 'some text');
    print $element->att('att');# 'value'

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It is a thin wrapper around an XML::LibXML::Element. It inherits all methods
from XML::ITS::DOM::Node.

=head1 EXPORTS

The following function may be exported from XML::ITS::DOM::Element.

=head2 C<new_element>

Arguments: a tag name and optionally a hash of attribute name-value pairs
and text to store in the element

Creates and returns a new XML::ITS::DOM::Node object representing an element with
the given name and attributes.

=cut
sub new_element {
    my ($name, $atts, $text) = @_;
    my $el = XML::LibXML::Element->new($name);
    if(defined $atts){
        $el->setAttribute($_, $atts->{$_}) for keys %$atts;
    }
    if(defined $text){
        $el->appendText($text);
    }
    return bless {
        node => $el,
        type => 'ELT',
    }, __PACKAGE__;
}

=head1 METHODS

=head2 C<is_inline>

Returns true if this element appears to be inline. An element is considered inline
if it has a text sibling with more than just whitespace.

=cut
sub is_inline {
    my ($self)  = @_;
    my $el = $self->{node};

    my $prev = $el->previousNonBlankSibling;
    my $next = $el->nextNonBlankSibling;
    if( ($prev && $prev->nodeName() eq '#text') ||
        ($next && $next->nodeName() eq '#text') ){
        return 1;
    }
    return 0;
}

=head2 C<att>

If this node is an element, returns the value of the given attribute.
The first argument is either the  attribute name (with prefix
if attribute has one), or, if the namespace is provided as a second
argument, then the attribute's local name.

=cut
sub att {
    my ($self, $name, $ns) = @_;
    if($ns){
        return $self->{node}->getAttributeNS($ns, $name);
    }
    return $self->{node}->getAttribute($name);
}

=head2 C<set_att>

Arguments: name, value, and optional namespace URI for the desired
attribute.

Sets the attribute with the given name to the given value/namespace
for this element.

=cut
sub set_att {
    my ($self, $name, $value, $ns) = @_;
    if($ns){
        return $self->{node}->setAttributeNS($ns, $name, $value);
    }
    return $self->{node}->setAttribute($name, $value);
}

=head2 C<atts>

If this node is an element, returns a hash pointer containing all of its
attributes and their values.

=cut
sub atts {
    my ($self) = @_;
    my %atts =
        map {($_->nodeName, $_->value)}
        $self->{node}->attributes;
    return \%atts;
}

=head2 C<get_ns_declarations>

Similar to C<get_namespaces>, but only returns values for namespaces
declared on this element.

=cut
sub get_ns_declarations {
    my ($self) = @_;
    my @namespaces = $self->{node}->getNamespaces;
    my %namespaces;
    $namespaces{$_->getLocalName} = $_->getData
        for @namespaces;
    return \%namespaces;
}

=head2 C<strip_ns>

Replaces an entire element with an identical node which is in the null
namespace, and whose attributes are also in the null namespace.
Also removes all namespace declarations. Any child elements who use the namespace
will have the namespace declared on them, instead.
The newly created element is returned.

Creating a new element in order to remove namespacing is a requirement
of LibXML's design.

=cut
sub strip_ns {
    my ($self) = @_;
    my $el = $self->{node};
    # new element has same name, minus namespace
    my $new = XML::LibXML::Element->new( $el->localname );
    #copy attributes (minus namespace namespace)
    for my $att($el->attributes){
        if($att->nodeName !~ /xmlns(?::|$)/){
            $new->setAttribute($att->localname, $att->value);
        }
    }
    #move children
    for my $child($el->childNodes){
        $new->appendChild($child);
    }

    # if working with the root element, we have to set the new element
    # to be the new root
    my $doc = $el->ownerDocument;
    if( $el->isSameNode($doc->documentElement) ){
        $doc->setDocumentElement($new);
    }else{
        #otherwise just paste the new element in place of the old element
        $el->parentNode->insertAfter($new, $el);
        $el->unbindNode;
    }
    return XML::ITS::DOM::Node->new($new);
}

=head2 C<child_els>

Returns an array pointer containing the child elements of
this element.

=cut
sub child_els {
    my ($self) = @_;
    my @children =
        map {XML::ITS::DOM::Node->new($_)}
        $self->{node}->getChildrenByTagName('*');
    return \@children;
}

1;
