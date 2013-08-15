package XML::ITS::WICS::XML2HTML::FutureNodeManager;
use strict;
use warnings;
use Exporter::Easy (
    OK => [qw(
        create_future
        clear_indices
        att_futures
        non_att_futures
        replace_el_future
    )]
);
use XML::ITS::WICS::XML2HTML::FutureNode;

# VERSION
# ABSTRACT: Track and replace FutureNodes

# this contains pointers to every FutureNode ever created. This allows changing
# out nodes which are contained in other structures.
my %future_cache;

# these contain futureNodes that create elements in the document;
# these must be saved so that special rules combating inheritance
# can be created
my @att_elements; #elements representing atts
my @non_att_elements; #elements representing PIs and namespaces

=head1 SYNOPSIS

    use XML::ITS::WICS::XML2HTML::FutureNodeManager qw(create_future);
    use XML::ITS;
    my $ITS = XML::ITS->new('xml', doc => 'myITSfile.xml');
    my ($comment) = $ITS->get_root->get_xpath(//comment());
    my $f_comment = create_future($comment);
    # change the document around, but don't delete any elements...
    $f_comment->realize;

=head1 EXPORTS

The following subroutines may be exported:

=head2 C<clear_indices>

This must be called to reset the global state in this package.
TODO: make a real class out of this.

=cut
sub clear_indices {
    @att_elements = ();
    @non_att_elements = ();
    %future_cache = ();
}

=head2 C<replace_el_future>

Arguments: an old element and a new element.

This method replaces the FutureNode pointer for the given element
with a FutureNode pointer for the new element. This is useful
for keeping track of matches while replacing nodes.

=cut
sub replace_el_future {
    my ($old_el, $new_el) = @_;
    ${ $future_cache{$old_el->unique_key} } = ${ create_future($new_el) };
}

=head2 C<att_futures>

This returns a list of all of the FutureNodes that represent attributes
(which are converted into attributes upon realization)

=cut
sub att_futures {
    return @att_elements;
}

=head2 C<non_att_futures>

This returns a list of all of the FutureNodes that represent non-attribute
nodes that are converted into elements.

=cut
sub non_att_futures {
    return @non_att_elements;
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
    my ($node, $doc) = @_;

    #don't create separate FutureNodes out of the same Node
    if($future_cache{$node->unique_key}){
        return $future_cache{$node->unique_key};
    }

    my $future = _new_future(
        'XML::ITS::WICS::XML2HTML::FutureNode',$node, $doc);

    # Cache FutureNodes so that we don't create one for the
    # same node multiple times.
    # Store pointers so that changes in future_cache can propagate
    # to other structures containing the same pointers.
    $future_cache{$node->unique_key} = \$future;

    #remember FutureNodes that are elementalized
    my $type = $node->type;
    if($type eq 'ATT'){
        push @att_elements, $future;
    }elsif($type eq 'PI' or $type eq 'NS'){
        push @non_att_elements, $future;
    }
    return \$future;
}

# note that the logic contained in this method is highly coupled with
# the realize() method logic in FutureNode.pm
sub _new_future {
    my ($class, $node, $doc) = @_;

    #store the state required to paste a representative node later
    my $type = $node->type;
    my $state = {type => $type};
    if($type eq 'ELT'){
        $state->{node} = $node;
    }elsif($type eq 'ATT'){
        $state->{parent} = create_future($node->parent);
        $state->{name} = $node->name;
        $state->{value} = $node->value;
    }elsif($type eq 'COM'){
        $state->{node} = $node;
    }elsif($type eq 'PI'){
        $state->{parent} = create_future($node->parent);
        $state->{value} = $node->value;
        $state->{name} = $node->name;
    }elsif($type eq 'TXT'){
        $state->{node} = $node;
    }elsif($type eq 'NS'){
        $state->{name} = $node->name;
        $state->{value} = $node->value;
        $state->{parent} = create_future($doc->get_root);
    }elsif($type eq 'DOC'){
        # just match the document root instead
        $state->{node} = ($node->children)[0];
    }
    return bless $state, $class;
}

1;
