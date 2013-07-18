package XML::ITS::WICS::XML2HTML::FutureNode;


use strict;
use warnings;
use Exporter::Easy (
    OK => [qw(create_future)]
);

# VERSION
# ABSTRACT: Ensure the future existence of an element without changing the DOM now

=head1 SYNOPSIS

    use XML::ITS::WICS::XML2HTML::FutureNode;
    use XML::ITS;
    my $ITS = XML::ITS->new('xml', doc => 'myITSfile.xml');
    my $comment = $ITS->get_root->get_xpath(/*/comment());
    my $f_comment = XML::ITS::WICS::XML2HTML::FutureNode->new($comment);
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

Creates a FutureNode object and returns it. No changes are made
to the owning DOM.

=cut
sub create_future {
    my ($node) = @_;

}

=head1 METHODS

=head2 C<ensure_visible>

Ensures that the information in the contained node is visible in the
HTML DOM. This causes changes to the owning DOM.

=cut
sub ensure_visible {
    my ($self) = @_;
}

1;
