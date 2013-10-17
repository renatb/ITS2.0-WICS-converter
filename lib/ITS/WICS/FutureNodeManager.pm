#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::FutureNodeManager;
use strict;
use warnings;
use ITS::WICS::FutureNode qw(new_future);
use Exporter::Easy (OK => [qw(new_manager)]);
use Carp;

our $VERSION = '0.02'; # VERSION
# ABSTRACT: Track and replace FutureNodes

sub new_manager {
    my ($dom) = @_;
    return __PACKAGE__->new($dom);
}

sub new {
    my ($class, $dom) = @_;
    croak 'missing required argument ITS::DOM'
        unless $dom;
    return bless {
        dom => $dom,
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

sub create_future {
    my ($self, $node) = @_;
    # print $node->name . ': ' . $node->unique_key . $node->text . "\n";

    # if this node has been saved in a FutureNode before,
    # return the pointer to that
    if($self->{future_cache}->{$node->unique_key}){
        return $self->{future_cache}->{$node->unique_key};
    }

    my $future = new_future($self, $node, $self->{dom});

    # Cache FutureNodes so that we don't create one for the
    # same node multiple times.
    $self->{future_cache}->{$node->unique_key} = $future;

    #remember FutureNodes that are elementalized
    if($future->creates_element){
        push @{$self->{elementals}}, $future;
    }
    return $future;
}

sub replace_el_future {
    my ($self, $old_el, $new_el) = @_;
    my $key = $old_el->unique_key;
    if($self->{future_cache}->{$key}){
        $self->{future_cache}->{$key}->replace_el($new_el);
    }
    #prevent any new elements from taking the old element's ID, which
    #would mess up our caches
    push @{$self->{old_els}}, $old_el;
    return;
}

sub elementals {
    my ($self) = @_;
    return @{ $self->{elementals} };
}

sub realize_all {
    my ($self) = @_;
    for my $future_pointer (
        sort {$a->name cmp $b->name} values %{ $self->{future_cache} }){
        $future_pointer->new_node;
    }
    return;
}

sub total_futures {
    my ($self) = @_;
    return scalar keys %{$self->{future_cache}};
}

1;

__END__

=pod

=head1 NAME

ITS::WICS::FutureNodeManager - Track and replace FutureNodes

=head1 VERSION

version 0.02

=head1 SYNOPSIS

    use ITS::WICS::FutureNodeManager;
    use ITS;
    my $ITS = ITS->new('xml', doc => 'myITSfile.xml');
    my $f_manager =
        ITS::WICS::FutureNodeManager->new($ITS->get_doc);

    #create one or more FutureNodes through this manager instance
    my ($ns) = $ITS->get_root->get_xpath('namespace::*');
    my $f_ns = create_future($ns);

    # change the document around, but don't delete any elements...

    # call new_node on all of the managed FutureNode instances
    $f_manager->realize_all;

=head1 EXPORTS

The following function may optionally be exported to the caller's namespace:

=head2 C<new_manager>

This is a convenience function for constructing an instance of this class
(saves some typing, since the class has such a long name). The ITS::DOM
object from which future_nodes will be created is the only required argument
(see C<new>).

=head1 METHODS

=head2 C<new>

Creates a new FutureNode manager. Single required argument is
an C<ITS::DOM> object. Every node to be made into a FutureNode
via this instance should be owned by the input DOM object. Though this
requirement is not enforced in any way, not following it will cause
incorrect behavior when processing document and namespace nodes.

=head2 C<create_future>

If the input node is an ITS::DOM::Node (or Element), this method creates
a FutureNode object, caches it, and returns it.
If it is an ITS::DOM::Value, it simply returns it.

If the input is a node and the node has already had a FutureNode created for it,
the same FutureNode object is returned.

The owning document as a second argument is required for namespace nodes, which
store no reference to any other nodes.

No changes are made to the owning DOM in this method.

=head2 C<replace_el_future>

Arguments: an old element and a new element.

If there exists a FutureNode representing the old element, this method
calls the C<replace_el> method on that FutureNode, with the new element
as the argument. This is useful for keeping track of matches while
replacing elements with new ones (which is required, for example, to
remove namespacing from an element with LibXML).

This only supports replacement of the original FutureNode. In other words,
you can't replace element A with element B and then call this
method with element B as the old element.

=head2 C<elementals>

Returns all of the FutureNodes which create(d) new elements in
the DOM.

=head2 C<realize_all>

Calls the C<new_node> method on all FutureNodes managed by this instance,
causing all DOM changes to occur.

=head2 C<total_futures>

Returns the total number of FutureNodes maintained by this instance.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
