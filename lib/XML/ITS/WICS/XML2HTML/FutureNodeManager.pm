package XML::ITS::WICS::XML2HTML::FutureNodeManager;
use strict;
use warnings;
use XML::ITS::WICS::XML2HTML::FutureNode;
use Carp;

# VERSION
# ABSTRACT: Track and replace FutureNodes

=head1 SYNOPSIS

    use XML::ITS::WICS::XML2HTML::FutureNodeManager;
    use XML::ITS;
    my $f_manager = XML::ITS::WICS::XML2HTML::FutureNodeManager->new();
    my $ITS = XML::ITS->new('xml', doc => 'myITSfile.xml');
    my ($ns) = $ITS->get_root->get_xpath('namespace::*');
    my $f_ns = create_future($ns);
    # change the document around, but don't delete any elements...
    $f_ns->new_node;

=head1 METHODS

=head2 C<new>

Creates a new FutureNode manager. This class should be instantiated
once for each document to be transformed.

=cut
sub new {
    my ($class) = @_;
    return bless {
        # this contains every FutureNode ever created.
        # This allows changing out nodes which are contained in
        # other structures via replace_el_future.
        future_cache => {},
        # all FutureNodes which create elements;
        # these must be tracked in order to create rules to
        # combat false inheritance
        elementals => [],
    }, $class;
}

=head2 C<create_future>

If the input node is an XML::ITS::DOM::Node (or Element), this method creates
a FutureNode object, caches it, and returns it.
If it is an XML::ITS::DOM::Value, it simply returns it.

If the input is a node and the node has already had a FutureNode created for it,
the same FutureNode object is returned.

The owning document as a second argument is required for namespace nodes, which
store no reference to any other nodes.

No changes are made to the owning DOM in this method.

=cut
sub create_future {
    my ($self, $node, $doc) = @_;

    # if this node has been saved in a FutureNode before,
    # return the pointer to that
    if($self->{future_cache}->{$node->unique_key}){
        return $self->{future_cache}->{$node->unique_key};
    }

    my $future = XML::ITS::WICS::XML2HTML::FutureNode->
        new($self, $node, $doc);

    # Cache FutureNodes so that we don't create one for the
    # same node multiple times.
    $self->{future_cache}->{$node->unique_key} = $future;

    #remember FutureNodes that are elementalized
    if($future->creates_element){
        push @{$self->{elementals}}, $future;
    }
    return $future;
}

=head2 C<replace_el_future>

Arguments: an old element and a new element.

If there exists a FutureNode representing the old element, this method
calls the C<replace_el> method on that FutureNode, with the new element
as the argument. This is useful for keeping track of matches while
replacing elements with new ones (which is required, for example, to
remove namespacing from an element with LibXML).

This only supports replacement of the original FutureNode. In other words,
you can't replace replace element A with element B and then call this
method with with element B as the old element.

=cut
sub replace_el_future {
    my ($self, $old_el, $new_el) = @_;
    my $key = $old_el->unique_key;
    if($self->{future_cache}->{$key}){
        $self->{future_cache}->{$key}->replace_el($new_el);
    }
}

=head2 C<elementals>

Returns all of the FutureNodes which create(d) new elements in
the DOM.

=cut
sub elementals {
    my ($self) = @_;
    return @{ $self->{elementals} };
}

=head2 C<realize_all>

Calls the C<new_node> method on all FutureNodes managed by this instance,
causing all DOM changes to occur.

=cut
sub realize_all {
    my ($self) = @_;
    for my $future_pointer (values %{ $self->{future_cache} }){
        $future_pointer->new_node;
    }
}

=head2 C<total_futures>

Returns the total number of FutureNodes maintained by this instance.

=cut
sub total_futures {
    my ($self) = @_;
    return scalar keys %{$self->{future_cache}};
}

1;
