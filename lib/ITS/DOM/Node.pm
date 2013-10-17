#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::DOM::Node;
use strict;
use warnings;
our $VERSION = '0.03'; # VERSION
# ABSTRACT: thin wrapper around underlying XML engine node objects
use ITS::DOM::Value;
our @CARP_NOT = qw(ITS::DOM);
use Try::Tiny;
use Carp;
use feature 'switch';

sub new {
    my ($class, $node) = @_;
    my $type = _get_type($node);

    # why subclassing isn't supported; class names are hard-coded
    if($type eq 'ELT'){
        $class = 'ITS::DOM::Element';
    }else{
        $class = 'ITS::DOM::Node';
    }
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

sub to_string {
    my ($node) = @_;
    return $node->{node}->toString
}


sub get_xpath {
    my ($self, $xpath, %context) = @_;

    #set up the XPath context with the given information
    my $xpc = XML::LibXML::XPathContext->new($self->{node});
    if($context{params}){
        $xpc->registerVarLookupFunc(\&_var_lookup, $context{params});
    }
    if($context{namespaces}){
        for (keys %{ $context{namespaces} }){
            if($_){
                $xpc->registerNs($_, $context{namespaces}->{$_});
            }
            # otherwise it is the default namespace, and we can't/don't
            # register that
        }
    }
    if($context{size}){
        $xpc->setContextSize($context{size});
    }
    if($context{position}){
        $xpc->setContextPosition($context{position});
    }

    my $object;
    try{
        $object = $xpc->find($xpath);
    }catch{
        # get rid of the part of the error which mentions
        # this file, which would be useless to users trying
        # to find a bad XPath expression.
        s/ at .*Node.pm line \d+\.\v+//;
        croak ("Failed evaluating XPath: $_");
    };
    my @nodes = ();
    if(ref $object eq 'XML::LibXML::NodeList'){
        @nodes =
            map {ITS::DOM::Node->new($_)}
            $object->get_nodelist();
    }else{
        push @nodes, ITS::DOM::Value->new($object);
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

sub type {
    my ($self) = @_;
    return $self->{type};
}

sub name {
    my ($self) = @_;
    return $self->{node}->nodeName;
}

sub set_name {
    my ($self, $name) = @_;
    $self->{node}->setNodeName($name);
    return;
}

sub remove {
    my ($self) = @_;
    $self->{node}->unbindNode;
    return;
}

sub namespace_URI {
    my ($self) = @_;
    return $self->{node}->namespaceURI || '';
}

sub local_name {
    my ($self) = @_;
    return $self->{node}->localname;
}

sub value {
    my ($self) = @_;
    return $self->{node}->nodeValue;
}

sub text {
    my ($self) = @_;
    return $self->{node}->textContent;
}

sub get_namespaces {
    my ($self) = @_;
    my @namespaces = $self->get_xpath('namespace::*');
    my %namespaces;
    $namespaces{$_->{node}->getLocalName || ''} = $_->{node}->getData
        for @namespaces;
    return \%namespaces;
}

sub children {
    my ($self) = @_;
    return map {ITS::DOM::Node->new($_)}
        $self->{node}->childNodes;
}

sub parent {
    my ($self) = @_;
    my $parent = $self->{node}->parentNode;
    if($parent){
        return __PACKAGE__->new($parent);
    }
    return;
}

sub doc_node {
    my ($self) = @_;
    my $doc = $self->{node}->ownerDocument;
    #owner document exists?
    if($doc){
        return __PACKAGE__->new($doc);
    }
    #return nothing if this node is an orphan
    return;
}

sub path {
    my ($self) = @_;
    return $self->{node}->nodePath();
}

sub next_sibling {
    my ($self) = @_;
    my $sib = $self->{node}->nextSibling;
    if($sib){
        return __PACKAGE__->new($sib);
    }
    return;
}

sub prev_sibling {
    my ($self) = @_;
    my $sib = $self->{node}->previousSibling;
    if($sib){
        return __PACKAGE__->new($sib);
    }
    return;
}

sub paste {
    my ($self, $other, $loc) = @_;

    $loc ||= 'last_child';
    my $this_node = $self->{node};
    my $o_node = $other->{node};

    if($loc eq 'last_child'){
        $o_node->appendChild($this_node);
    }elsif($loc eq 'first_child'){
        $o_node->insertBefore($this_node, $o_node->firstChild);
    }elsif($loc eq 'before'){
        my $parent = $o_node->parentNode;
        $parent->insertBefore($this_node, $o_node);
    }elsif($loc eq 'after'){
        my $parent = $o_node->parentNode;
        $parent->insertAfter($this_node, $o_node);
    }else{
        croak "unknown paste location: $loc";
    }
    return;
}

sub append_text {
    my ($self, $text, $position) = @_;
    my $txt_node = XML::LibXML::Text->new($text);
    $txt_node = ITS::DOM::Node->new($txt_node);
    $txt_node->paste($self, $position);
    return $txt_node;
}

sub is_same_node {
    my ($self, $other) = @_;
    #use unique_key method because we made it work for
    #Namespaces; isSameNode doesn't work with Namespaces.
    return $self->unique_key eq $other->unique_key;
}

sub copy {
    my ($self, $deep) = @_;
    #default value is false
    $deep //= 0;
    return __PACKAGE__->new($self->{node}->cloneNode($deep));
}

sub unique_key {
    my ($self) = @_;
    if($self->type eq 'NS'){
        return $self->{node}->declaredPrefix . ':' .
            $self->{node}->declaredURI;
    }
    return $self->{node}->unique_key;
}

1;

__END__

=pod

=head1 NAME

ITS::DOM::Node - thin wrapper around underlying XML engine node objects

=head1 VERSION

version 0.03

=head1 SYNOPSIS

    use ITS::DOM;
    use feature 'say';
    my $dom = ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_xpath('//@foo');
    for my $node(@nodes){
        say $node->text;
    }

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It is a thin wrapper around an XML::LibXML::Node.

=head1 METHODS

=head2 C<new>

Argument: a single XML::LibXML node.

Note that this constructor DOES NOT support subclassing by other libraries.
The package of the returned object depends on the type of XML::LibXML node
passed in.

=head2 C<to_string>

Returns a string representation of this node.

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

=head2 C<type>

Returns a string representing the type of the node:
C<ELT>, C<ATT>, C<TXT>, C<NS>, C<PI>, C<COM> or C<DOC>.

=head2 C<name>

Returns the name of the node. This is the tag name for elements,
the name for attributes and PIs, etc.

=head2 C<set_name>

Sets the node's name to the given string. Is namespace aware.

=head2 C<remove>

Unbinds this node from its siblings and parents (but not
the document, though it becomes hidden and will be lost unless
pasted somewhere in the document).

=head2 C<namespace_URI>

Returns the namespace URI of this node. If there is no namespace
associated with this node, returns an empty string.

=head2 C<local_name>

Returns the node name without the namespace prefix.

=head2 C<value>

Returns a string representing the value of the node. This is not
text content for elements (call L<text> for that).

=head2 C<text>

Returns the content of all text nodes in the descendants of this node.

=head2 C<get_namespaces>

Returns a hash ref containing prefix/URI pairs for all of the namespaces
in scope for this node.

=head2 C<children>

Returns a list containing the
child nodes of this node.

=head2 C<parent>

Returns the parent node of this node, or undef if there is none.

=head2 C<doc_node>

Returns the document node for the document which owns this node,
or undef if there is no owner.

=head2 C<path>

Returns an XPath uniquely identifying this node in the current document

=head2 C<next_sibling>

Returns the next sibling node of this node, or undef if there is none.

=head2 C<prev_sibling>

Returns the previous sibling node of this node, or undef if there is none.

=head2 C<paste>

Paste this node into the given relation with the given node.
The arguments are another node, and an optional relation.
The possible relations are C<last_child>, C<first_child>,
C<before> and C<after>. The default is C<last_child>.

=head2 C<append_text>

Appends the input text in the document relative to this node,
and returns the new text node.

The arguments are the string to append, and an optional
relation to specify where to paste the text relative to this
node. The possible relations are the same as for C<paste>,
and the default is C<last_child>.

=head2 C<is_same_node>

Return true if this node is the same node as the input node.

=head2 C<copy>

Returns a copy of this node. A single boolean argument indicates
whether a deep copy should be performed (true for yes); that is,
whether children should also be copied.

=head2 C<unique_key>

Returns a unique value guaranteed to always be the same for this node.
In other words, if and only if the unique key for two node objects
are the same, then is_same_node will return true.

For namespace nodes, this returns a string "prefix:URI", which
uniquely identifies a namespace.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
