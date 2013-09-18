package ITS::DOM::Element;
use strict;
use warnings;
# VERSION
# ABSTRACT: Represents a DOM element
use Exporter::Easy (
    OK => [qw(new_element)]
);
use XML::LibXML;
use parent 'ITS::DOM::Node';
use Carp;

=head1 SYNOPSIS

    use ITS::DOM::Element qw(new_element);
    my $element = new_element('name', {att => 'value'}, 'some text');
    print $element->att('att');# 'value'

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It is a thin wrapper around an XML::LibXML::Element. It inherits all methods
from ITS::DOM::Node.

=head1 EXPORTS

The following function may be exported from ITS::DOM::Element.

=head2 C<new_element>

Arguments: a tag name and optionally a hash of attribute name-value pairs
and text to store in the element

Creates and returns a new ITS::DOM::Node object representing an element with
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

Returns true if this element appears to be inline, false if block. An element
is considered block if it is preceded and followed by a newline (and optionally
other whitespace), or if it is the root element.

For example, here are some block elements:

    ...some text...
    <block1>
    <block2>...text...</block2>
    </block1>
    ...some text...

and here are some inline elements:

    ...some text...
    <block>
    ...text1...<inline1>...text2</inline1>text2...
    <inline2>...text1...</inline2> ...text2...
    ...text1...<inline3>...text2</inline3>
    </block>
    ...some text...

=cut
sub is_inline {
    my ($self)  = @_;
    my $el = $self->{node};

    #the root is never inline
    if($el->isSameNode($el->ownerDocument->documentElement)){
        return 0;
    }
    my $prev = $el->previousSibling;
    my $next = $el->nextSibling;
    # has text siblings on both sides
    if( ($prev && $prev->nodeName() eq '#text') &&
        ($next && $next->nodeName() eq '#text') ){
        # and they include adjacent newline with optional whitespace
        my $prevText = $prev->nodeValue;
        my $nextText = $next->nodeValue;
        if($prevText =~ /[\r\n]\s*$/
            && $nextText =~ /^\s*[\r\n]/){
            return 0;
        }
    }
    return 1;
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


=head2 C<remove_att>

Arguments: name, value, and optional namespace URI for the desired
attribute.

Removes the specified attribute from its containing element.

=cut
sub remove_att {
    my ($self, $name, $ns) = @_;
    if($ns){
        return $self->{node}->removeAttributeNS($ns, $name);
    }
    return $self->{node}->removeAttribute($name);
}

=head2 C<set_namespace>

Input arguments are namespace URI and optionally a prefix. This
method assigns the given namespace URI and prefix to this element.
A missing prefix argument will make the namespace the default
namespace for this element.

=cut
sub set_namespace {
    my ($self, $URI, $prefix) = @_;
    croak 'cannot use empty string as namespace URI'
        unless length $URI;
    $self->{node}->setNamespace($URI, $prefix || undef);
    return;
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
If the input element had any namespacing to remove, the newly created element returned.
Otherwise, the original element is returned.

Creating a new element in order to remove namespacing is a requirement
of LibXML's design.

=cut
sub strip_ns {
    my ($self) = @_;
    my $el = $self->{node};
    my $changed = 0;
    # new element has same name, minus namespace
    my $new = XML::LibXML::Element->new( $el->localname );
    if($el->localname ne $el->nodeName){
        $changed = 1;
    }
    #copy attributes (minus namespace namespace)
    for my $att($el->attributes){
        if($att->nodeName !~ /xmlns(?::|$)/){
            $new->setAttribute($att->localname, $att->value);
        }else{
            $changed ||= 1;
        }
    }
    if(!$changed){
        return $self;
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
    return ITS::DOM::Node->new($new);
}

=head2 C<child_els>

Returns an array pointer containing the child elements of
this element. You may optionally provide name and namespace parameters
(C<$el->child_els($name, $ns)>) to restrict the list of children that
is returned to those with the given name or name and namespace.

If both a name and a namespace are provided, the name should be the local
name (without a prefix). '*' can be provided as the namespace to match any
namespace and only filter returned elements by local name.

=cut
sub child_els {
    my ($self, $name, $ns) = @_;
    my @children;
    if(defined $ns){
        @children = $self->{node}->getChildrenByTagNameNS($ns, $name);
    }elsif(defined $name){
        @children = $self->{node}->getChildrenByTagName($name);
    }else{
        @children =
        $self->{node}->getChildrenByTagName('*');
    }
    @children = map {ITS::DOM::Node->new($_)} @children;
    return \@children;
}

1;
