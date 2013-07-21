package XML::ITS::DOM::Node;
use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine node objects
use XML::ITS::DOM::Value;
use Carp;
use feature 'switch';
use Exporter::Easy (
    OK => [qw(new_element)]
);

=head1 SYNOPSIS

    use XML::ITS::DOM;
    use feature 'say';
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_nodes('//@foo');
    for my $node(@nodes){
        say $node->text;
    }

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It is a thin wrapper around an XML::Twig::XPath nodes.

=head1 METHODS

=head2 C<new>

Argument: a single XML/HTML node

=cut
sub new {
    my ($class, $node) = @_;
    # print $node->tag . "---\n";
    return bless {
        node => $node,
        type => _get_type($node),
    }, $class;
}

sub _get_type {
    my ($node) = @_;
    my $type;
    if(!$node->can('nodeType')){
        #has to be a literal, number or boolean
        if(ref $node eq 'XML::LibXML::Literal'){
            $type = 'LIT';
        }else{
            $type = ref $node;
            $type =~ s/.*:://;
            croak "ITS doesn't support nodes of type $type";
        }
    }
    else{
        given($node->nodeType){
            when(1){$type = 'ELT'; break;}
            when(2){$type = 'ATT'; break;}
            when(3){$type = 'TXT'; break;}
            when(18){$type = 'NS'; break;}
            when(7){$type = 'PI'; break;}
            when(8){$type = 'COM'; break;}
            when(9){$type = 'DOC'; break;}
            default{croak "unknown node type for $node";}
        }
    }
    return $type;
}

=head2 C<get_xpath>

Constructs an xpath query from the input arguments, and returns
a list of nodes matching the query.

The xpath context node will be the calling node, and the first argument should be
the XPath string. The rest of the parameters are named and optional:

=over 3

=item position

An integer indicating the context position. Default is -1.

=item size

An integer indicating the context size. Default is -1.

=item params

A hash ref containing variable names and strings values. No other
types of values are allowed. There are no default parameters.

=item namespaces

A hash ref of namespace prefix keys and namespace URI values to be
made available to the XPath expression. Any previously scoped namespaces
are removed (by default, all namespaces in the scope of the context node
are available, but providing a namespaces value removes these).

=back

=cut

sub get_xpath {
    my ($self, $xpath, %context) = @_;

    #set up the XPath context with the given information
    my $xpc = XML::LibXML::XPathContext->new($self->{node});
    if($context{params}){
        $xpc->registerVarLookupFunc(\&_var_lookup, $context{params});
    }
    if($context{namespaces}){
        # my $old_namespaces = $self->get_namespaces;
        # for(keys %$old_namespaces){
        #     print "trying to unregister $_\n";
        #     $xpc->unregisterNs($_);
        # }
        $xpc->registerNs($_, $context{namespaces}->{$_})
            for keys %{ $context{namespaces} };
    }
    # print $xpc->lookupNs('bar');
    if($context{size}){
        $xpc->setContextSize($context{size});
    }
    if($context{position}){
        $xpc->setContextPosition($context{position});
    }

    my $object;
    #TODO: catch errors and clean up the stack trace
    # try{
        $object = $xpc->find($xpath);
    # }catch{
    #     croak "Problem evaluating XPath: $_";
    # };
    my @nodes;
    if(ref $object eq 'XML::LibXML::NodeList'){
        @nodes =
            map {XML::ITS::DOM::Node->new($_)}
            $object->get_nodelist();
    }else{
        push @nodes, XML::ITS::DOM::Value->new($object);
    }
    return @nodes;
}

#simple dictionary-lookup sub for parameter handling in get_xpath method
sub _var_lookup {
    my ($data, $varname, $ns) = @_;
    my $lookup = $varname;
    if(defined $ns){
        $lookup = "$ns:$lookup";
    }
    my $val = $data->{$lookup};
    if (!defined($val)) {
        warn("Unknown variable \"$lookup\"\n");
        $val = '';
    }
    return $val;
}

=head2 C<type>

Returns a string representing the type of the node:
C<ELT>, C<ATT>, C<TXT>, C<NS>, C<PI>, C<COM> or C<DOC>.

=cut
sub type {
    my ($self) = @_;
    return $self->{type};
}

=head2 C<name>

Returns the name of the node. This is the tag name for elements,
the name for attributes and PIs, etc.

=cut
sub name {
    my ($self) = @_;
    return $self->{node}->nodeName;
}

=head2 C<set_name>

Sets the node's name to the given string. Is namespace aware.

=cut
sub set_name {
    my ($self, $name) = @_;
    $self->{node}->setNodeName($name);
}

=head2 C<remove>

Unbinds this node from it's siblings and parents (but not
the document, though it invisible).

=cut
sub remove {
    my ($self) = @_;
    $self->{node}->unbindNode;
}

=head2 C<namespaceURI>

Returns the namespace URI of this node.

=cut
sub namespaceURI {
    my ($self) = @_;
    return $self->{node}->namespaceURI;
}

=head2 C<local_name>

If this node is an element, this method returns its name without
the namespace prefix.
=cut
sub local_name {
    my ($self) = @_;
    return $self->{node}->localname;
}

=head2 C<value>

Returns a string representing the value of the node.

=cut
sub value {
    my ($self) = @_;
    return $self->{node}->getValue;
}

=head2 C<text>

Returns the content of all text nodes in the descendants of this node.

=cut
sub text {
    my ($self) = @_;
    return $self->{node}->textContent;
}

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

=head2 C<get_namespaces>

Returns an array ref containing prefix/URI pairs for all of the namespaces
in scope for this node.

=cut
sub get_namespaces {
    my ($self) = @_;
    my @namespaces = $self->get_xpath('namespace::*');
    my %namespaces;
    $namespaces{$_->{node}->getLocalName} = $_->{node}->getData
        for @namespaces;
    return \%namespaces;
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

=head2 C<children>

Returns an array pointer containing the
child nodes of this element.

=cut
sub children {
    my ($self) = @_;
    my @children =
        map {XML::ITS::DOM::Node->new($_)}
        $self->{node}->childNodes;
    return \@children;
}
=head2 C<paste>

Argument: ITS::Node to be used as new parent node.
Inserts this node as the last child of the input parent node.

=cut
sub paste {
    my ($self, $parent) = @_;
    $parent->{node}->appendChild($self->{node});
    return;
}

=head1 EXPORTS

The following functions may be exported from XML::ITS::DOM.

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

1;

