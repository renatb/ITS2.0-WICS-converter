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
        # this contains pointers to every FutureNode ever created.
        # This allows changing out nodes which are contained in
        # other structures.
        future_cache => {},
        # these contain futureNodes that create elements in the document;
        # these must be saved so that special rules combatting inheritance
        # can be created
        att_elements => [], #elements for attributes
        non_att_elements => [], #elements for PIs and namespaces
    }, $class;
}

=head2 C<replace_el_future>

Arguments: an old element and a new element.

This method replaces the FutureNode pointer for the given element
with a FutureNode pointer for the new element. This is useful
for keeping track of matches while replacing nodes.

=cut
sub replace_el_future {
    my ($self, $old_el, $new_el) = @_;
    ${ $self->{future_cache}->{$old_el->unique_key} } =
        ${ $self->create_future($new_el) };
}

=head2 C<att_futures>

This returns a list of all of the FutureNodes that represent attributes
(which are converted into attributes upon realization)

=cut
sub att_futures {
    my ($self) = @_;
    return @{$self->{att_elements}};
}

=head2 C<non_att_futures>

This returns a list of all of the FutureNodes that represent non-attribute
nodes that are converted into elements.

=cut
sub non_att_futures {
    my ($self) = @_;
    return @{$self->{non_att_elements}};
}

=head2 C<create_future>

If the input node is an XML::ITS::DOM::Node (or Element), this method creates
a FutureNode object and returns it. If it is an XML::ITS::DOM::Value,
it simply returns it.

The owning document as a second argument is required for namespace nodes, which
store no reference to any other nodes.

No changes are made to the owning DOM in this method.

=cut
sub create_future {
    my ($self, $node, $doc) = @_;

    #don't create separate FutureNodes out of the same Node
    if($self->{future_cache}->{$node->unique_key}){
        return $self->{future_cache}->{$node->unique_key};
    }
    # warn $node->name . $node->unique_key . join '|', caller();

    my $future = $self->_new_future($node, $doc);

    # Cache FutureNodes so that we don't create one for the
    # same node multiple times.
    # Store pointers so that changes in future_cache can propagate
    # to other structures containing the same pointers.
    $self->{future_cache}->{$node->unique_key} = \$future;

    #remember FutureNodes that are elementalized
    my $type = $node->type;
    if($type eq 'ATT'){
        push @{$self->{att_elements}}, $future;
    }elsif($type eq 'PI' or $type eq 'NS'){
        push @{$self->{non_att_elements}}, $future;
    }
    return \$future;
}

# note that the logic contained in this method is highly coupled with
# the new_node() method logic in FutureNode.pm
sub _new_future {
    my ($self, $node, $doc) = @_;

    #store the state required to paste a representative node later
    my $type = $node->type;
    my $state = {type => $type};
    if($type eq 'ELT'){
        $state->{node} = $node;
    }elsif($type eq 'ATT' or $type eq 'PI'){
        # maintainer note: don't try to store the actual attribute node;
        # It causes perl to crash!
        $state->{parent} = $self->create_future($node->parent);
        $state->{name} = $node->name;
        $state->{value} = $node->value;
    }elsif($type eq 'COM'){
        $state->{node} = $node;
    }elsif($type eq 'TXT'){
        $state->{node} = $node;
    }elsif($type eq 'NS'){
        # save document root for pasting
        $state->{name} = $node->name;
        $state->{value} = $node->value;
        $state->{parent} = $self->create_future($doc->get_root);
    }elsif($type eq 'DOC'){
        #nothing needed. Final XPath will always just be '/'.
        $state->{node} = $self->create_future($node->children);
    }else{
        croak "Unknown node type $type";
    }
    return bless $state, 'XML::ITS::WICS::XML2HTML::FutureNode';
}


=head2 C<realize_all>

Calls the C<new_node> method on all FutureNodes managed by this instance,
causing all DOM changes to occur.

=cut
sub realize_all {
    my ($self) = @_;
    for my $future_pointer (values %{ $self->{future_cache} }){
        ${$future_pointer}->new_node;
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
