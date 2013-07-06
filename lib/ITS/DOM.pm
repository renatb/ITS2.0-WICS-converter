package ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use Carp;
our @CARP_NOT = qw(ITS::DOM ITS);
use Try::Tiny;
use Path::Tiny;
#the XML engine currently used
# use XML::Twig::XPath;
use XML::LibXML;
use Exporter::Easy (
    OK => [qw(new_element)]
);

=head1 SYNOPSIS

    use ITS::DOM;
    use feature 'say';
    my $dom = ITS::DOM->new(xml => 'path/to/file');
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

=head2 C<get_xpath>

Argument: XPath string to query document with, hash of name-value
pairs of parameters (strings only!)

Returns a list of ITS::DOM::Node objects matching the given XPath.

=cut

sub get_xpath {
    my ($self, $xpath, $parameters, $namespaces) = @_;

    #set up the XPath context with the given information
    my $xpc = XML::LibXML::XPathContext->new($self->{dom});
    if($parameters){
        $xpc->registerVarLookupFunc(\&_var_lookup, $parameters);
    }
    if($namespaces){
        $xpc->registerNs($_, $namespaces->{$_})
            for keys %$namespaces;
    }

    my @nodes =
        map {ITS::DOM::Node->new($_)}
        $xpc->findnodes($xpath);
    return @nodes;
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

sub _var_lookup {
    my ($varname, $ns, $data) = @_;
    return $data->{$varname};
}

#Returns an XML::Twig object with proper settings for parsing ITS
sub _create_twig {
    my $twig = XML::Twig::XPath->new(
        map_xmlns               => {
            'http://www.w3.org/2005/11/its' => 'its',
            'http://www.w3.org/1999/xlink' => 'xlink'
        },
        # empty_tags              => 'html',
        pretty_print            => 'indented',
        output_encoding         => 'UTF-8',
        keep_spaces             => 0,
        no_prolog               => 1,
        #can be important when things get complicated
        do_not_chain_handlers   => 1,
    );
    return $twig;
}

#for exporting purposes
*new_element = *ITS::DOM::Node::new_element;

1;

package ITS::DOM::Node;
use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine node objects
use Carp;
use feature 'switch';

=head1 SYNOPSIS

    use ITS::DOM;
    use feature 'say';
    my $dom = ITS::DOM->new(xml => 'path/to/file');
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
    return $type;
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

=cut
sub att {
    my ($self, $name) = @_;
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

=head2 C<children>

If this node is an element, returns an array pointer containing the
child nodes of this element.

=cut
sub children {
    my ($self) = @_;
    my @children =
        map {ITS::DOM::Node->new($_)}
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

The following functions may be exported from ITS::DOM.

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

1;
