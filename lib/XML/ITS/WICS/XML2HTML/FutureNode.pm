package XML::ITS::WICS::XML2HTML::FutureNode;


use strict;
use warnings;
use Exporter::Easy (
    OK => [qw(create_future)]
);
use XML::ITS::DOM::Element qw(new_element);

# VERSION
# ABSTRACT: Ensure the future existence of an element without changing the DOM now

=head1 SYNOPSIS

    use XML::ITS::WICS::XML2HTML::FutureNode qw(create_future);
    use XML::ITS;
    my $ITS = XML::ITS->new('xml', doc => 'myITSfile.xml');
    my ($comment) = $ITS->get_root->get_xpath(//comment());
    my $f_comment = create_future($comment);
    # change the document around, but don't delete any elements...
    $f_comment->ensure_visible;

=head1 DESCRIPTION

This class provides a way to ensure the existence of a visible,
selectable HTML element to represent a given node.
If you pass in an attribute node, for example, it will remember
it's spot and make sure that there is a visible element representing
that attribute after you call the ensure_visible method. This means
that you can delete the original attribute without losing information.
The document is not changed at all until you call ensure_visible,
so that no XPath selectors are broken.

This is only guaranteed to work if document elements are not deleted
after this object's creation.

=head1 EXPORTS

The following subroutine may be exported:

=head2 C<create_future>

If the input is an XML::ITS::DOM::Node (or Element), this method creates
a FutureNode object and returns it. If it is an XML::ITS::DOM::Value,
it simply returns it.

No changes are made to the owning DOM in this method.

=cut
sub create_future {
    my ($node) = @_;
    #Values
    if(ref $node eq 'XML::ITS::DOM::Value'){
        return $node;
    }

    my $type = $node->type;
    my $state = {type => $type};
    if($type eq 'ELT'){
        $state->{node} = $node;
    }
    if($type eq 'ATT'){
        $state->{parent} = $node->parent;
        $state->{name} = $node->name;
        $state->{value} = $node->value;
    }
    elsif($type eq 'COM'){
        $state->{parent} = $node->parent;
        $state->{value} = $node->value;
    }
    return bless $state, __PACKAGE__;

        # case ELEMENT:
        #     return placeholder object
        #         (use existing placeholder if found in %placeholders)
        #         (placeholder just holds element, and paste does nothing)
        #     return $domNode;
        #     break;
        # case ATTRIBUTE, COMMENT, PI, DOCUMENT, NAMESPACE:
        #     return placeholder object
        #         (use existing placeholder if found in %placeholders)
        #         (create new element representing $domNode;
        #             also save prev/next sibling/parent)
        # case TEXT:
        #     push @{$matchIndex->{$rule}}, placeholder object
        #         (use existing placeholder if found in %placeholders)
        #         (create new element representing $domNode;
        #             also save prev/next sibling/parent;
        #             should destroy original text when pasted into document)
}

=head1 METHODS

=head2 C<elemental>

Ensures that the information in the contained node is represented by an element
in the HTML DOM. This may cause changes to the owning DOM.

Returns the ITS::DOM::Element object representing the node.

=cut
sub elemental {
    my ($self) = @_;
    #only elementalize a node once!
    if(exists $self->{element}){
        return $self->{element};
    }
    #elements are already visible
    if($self->{type} eq 'ELT'){
        $self->{element} = $self->{node};
    }elsif($self->{type} eq 'ATT'){
        my $el = new_element(
            'span',
            {
                 title => $self->{name},
                 class => "_ITS_ATT"
            },
            $self->{value}
        );
        $el->paste($self->{parent}, 'first_child');
        $self->{element} = $el;
    }

    return $self->{element};
}

1;
