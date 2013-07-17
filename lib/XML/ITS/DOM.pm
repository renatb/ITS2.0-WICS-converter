package XML::ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use Carp;
our @CARP_NOT = qw(ITS::DOM ITS);
use Try::Tiny;
use Path::Tiny;
#the XML engine currently used
use XML::LibXML;
use Exporter::Easy (
    OK => [qw(new_element)]
);

=head1 SYNOPSIS

    use XML::ITS::DOM;
    use feature 'say';
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_nodes('//@foo');

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It abstracts away XML/HTML processing to quarantine 3rd party code.

=head1 METHODS

=head2 C<new>

Argument: a single named argument. The name should be either 'xml' or
'html', and the value is either a string filepath or a string pointer
containing the actual data to be parsed.

Parses the input document, creating a queryable DOM structure.

=cut

sub new {
    my ($class, %args) = @_;
    my $dom;
    my $source;
    if($args{xml}){
        $dom = _get_xml_dom($args{xml});
        $source = $args{xml};
    }elsif($args{html}){
        croak 'HTML parsing not supported yet';
        $source = $args{html};
    }

    my $base;
    if(ref $source eq 'SCALAR'){
        $base = path('.');
    }else{
        $base = path($source)->parent;
    }
    my $identifier = (ref $source eq 'SCALAR') ? 'STRING' : $source;

    return bless {dom => $dom, base => $base, source => $identifier}, $class;
}

sub get_root {
    my ($self) = @_;
    return XML::ITS::DOM::Node->new($self->{dom}->documentElement);
}

=head2 C<get_base_uri>

Returns the path of the directory containing the DOM content
(which is '.' for strings). This is useful for resolving relative
URIs.

=cut
sub get_base_uri {
    my ($self) = @_;
    return $self->{base};
}

=head2 C<get_source>

Returns the path of the file used to create this document. If the
data used to create this document was a string, then this returns
'STRING'.

=cut
sub get_source {
    my ($self) = @_;
    return $self->{source};
}

sub _get_xml_dom {
    my ($xml) = @_;

    my $parser = XML::LibXML->new();
    my $dom;
    if(ref $xml eq 'SCALAR'){
        #string refs are xml content;
        try{
            $dom = $parser->load_xml( string => $xml );
        } catch {
            croak "error parsing string: $_";
        };
    }
    else{
        #strings are file names
        try{
            $dom = $parser->load_xml( location => $xml );
        } catch {
            croak "error parsing file '$xml': $_";
        };
    }
    return $dom;
}

#for exporting purposes
*new_element = *XML::ITS::DOM::Node::new_element;

1;

package XML::ITS::DOM::Node;
use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine node objects
use Carp;
use feature 'switch';

=head1 SYNOPSIS

    use XML::ITS::DOM;
    use feature 'say';
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_nodes('//@foo');
    for(@nodes){
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

=head2 C<atts>

If this node is an element, returns a hash pointer containing all of its
attributes and their values.

=cut
sub atts {
    my ($self, $name) = @_;
    my %atts =
        map {($_->nodeName, $_->value)}
        $self->{node}->attributes;
    return \%atts;
}

=head C<namespaces>

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

=head2 C<children>

If this node is an element, returns an array pointer containing the
child nodes of this element.

=cut
sub children {
    my ($self) = @_;
    my @children =
        map {XML::ITS::DOM::Node->new($_)}
        $self->{node}->getChildrenByTagName('*');
    return \@children;
}

=head2 C<paste>

Argument: ITS::Node to be used as new parent node.
Inserts this node as the last child of the input parent node.

=cut
sub paste {
    my ($self, $parent) = @_;
    $parent->{node}->appendChild($self->{node});
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

package XML::ITS::DOM::Value;

use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine value objects

=head1 SYNOPSIS

    use XML::ITS::DOM;
    use feature 'say';
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_nodes('"some string"');
    for(@nodes){
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

=head2 C<type>

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
}