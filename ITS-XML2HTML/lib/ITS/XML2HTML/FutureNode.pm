package ITS::XML2HTML::FutureNode;
use strict;
use warnings;
use Exporter::Easy (OK => [qw(new_future)]);
use ITS::DOM::Element qw(new_element);
use ITS::XML2HTML::LogUtils qw(get_or_set_id);
use Carp;
use Log::Any qw($log);

# VERSION
# ABSTRACT: Save a single node during DOM transformation.

=head1 SYNOPSIS

    use ITS::XML2HTML::FutureNodeManager;
    use ITS;
    my $f_manager = ITS::XML2HTML::FutureNodeManager->new();
    my $ITS = ITS->new('xml', doc => 'myITSfile.xml');
    my ($ns) = $ITS->get_root->get_xpath('namespace::*');
    my $f_ns = create_future($ns);
    # change the document around, but don't delete any elements...
    $f_ns->new_node;

=head1 DESCRIPTION

This class saves nodes during DOM transformation so that they will
still be in the document later.
If you create a FutureNode for an attribute node, for example, it
will remember it's spot and create an element representing that
attribute after you call the C<new_node> method. This means
that you can delete the original attribute without losing information.
The document is not changed at all until you call C<new_node>,
so no XPath selectors are broken before then.

This is only guaranteed to work if document elements are not deleted
after this object's creation. This is because some FutureNodes remember
their location by their original parent, and deleting these will cause
dereference errors.

=head1 EXPORTS

The following function may optionally be exported to the caller's namespace:

=head2 C<new_future>

This is a convenience function for constructing an instance of this class
(saves some typing, since the class has such a long name).
The required arguments are the same as for C<new>.

=cut
sub new_future {
    my ($manager, $node, $doc) = @_;
    return __PACKAGE__->new($manager, $node, $doc);
}

=head1 METHODS

=head2 C<new>

Create a new FutureNode. The arguments are the FutureNodeManager
which will manage this instance, the node to be represented, and
the ITS::DOM instance containing it.

=cut
sub new {
    my ($class, $manager, $node, $doc) = @_;

    #store the state required to paste a representative node later
    my $type = $node->type;
    my $state = {type => $type, dom => $doc};
    if($type eq 'ELT'){
        $state->{node} = $node;
    }elsif($type eq 'ATT' or $type eq 'PI'){
        # maintainer note: don't try to store the actual attribute node;
        # It causes perl to crash!
        $state->{parent} = $manager->create_future($node->parent);
        $state->{name} = $node->name;
        $state->{value} = $node->value;
        $state->{creates_element} = 1;
    }elsif($type eq 'COM' or $type eq 'TXT'){
        $state->{node} = $node;
    }elsif($type eq 'NS'){
        # save document root for pasting
        $state->{name} = $node->name;
        $state->{value} = $node->value;
        $state->{parent} = $manager->create_future($doc->get_root);
        $state->{creates_element} = 1;
    }elsif($type eq 'DOC'){
        #nothing needed. Final XPath will always just be '/'.
        $state->{node} = $manager->create_future($node->children);
    }else{
        croak "Unknown node type $type";
    }
    return bless $state, $class;
}

=head2 C<replace_el>

If this FutureNode represents an element, this method trades out
the element represented by this instance. Otherwise it croaks.

=cut
sub replace_el {
    my ($self, $el) = @_;
    my $type = $self->type;
    if($type eq 'ELT'){
        $self->{node} = $el;
    }else{
        croak "Attempt to replace element in FutureNode of type " . $type;
    }
    return;
}

=head2 C<creates_element>

True if the new_node method of this instance will cause the creation of
a new element in the DOM, false otherwise.

=cut
sub creates_element {
    my ($self) = @_;
    return exists $self->{creates_element};
}

=head2 C<type>

Returns the type of node being represented (one of the strings returned
by C<ITS::DOM::Node::type>).

=cut
sub type {
    my ($self) = @_;
    return $self->{type};
}

=head2 C<new_node>

Ensures that the information in the contained node is represented
in the HTML DOM. This may cause changes to the owning DOM (see
C<creates_element>). Calling this method multiple times, however,
only changes the DOM once and always returns the same node.

Returns an ITS::DOM::Node object corresponding to the original Node
(which might or might not be the same Node object).

=cut
sub new_node {
    my ($self) = @_;
    #only realize a node once!
    if(exists $self->{element}){
        return $self->{element};
    }
    #elements are already visible
    if($self->{type} eq 'ELT'){
        $self->{element} = $self->{node};
    }elsif($self->{type} eq 'ATT'){
        # paste an element with the same content
        # in current version of original parent
        my $el = new_element(
            'span',
            {
                 title => $self->{name},
                 class => "_ITS_ATT",
                 'its-within-text' => 'no',
            },
            $self->{value}
        );
        $el->set_namespace('http://www.w3.org/1999/xhtml');
        $el->paste($self->{parent}->new_node, 'first_child');
        $self->{element} = $el;
        $self->_log_new_el if $log->is_debug;
    }
    # comments aren't deleted, so just place a new element next to them.
    # TODO: might be better just to leave it as a comment and use nodePath
    # or something like that.
    elsif($self->{type} eq 'COM'){
        $self->{element} = $self->{node};
    }
    #create an elemental representation in an appropriate location
    elsif($self->{type} eq 'PI'){
        my $el = new_element(
            'span',
            {
                 title => $self->{name},
                 'its-within-text' => 'no',
                 class => '_ITS_PI'
            },
            $self->{value}
        );
        $el->set_namespace('http://www.w3.org/1999/xhtml');
        #paste in current version of original parent
        $el->paste($self->{parent}->new_node);
        $self->_log_new_el if $log->is_debug;
        $self->{element} = $el;
    }
    elsif($self->{type} eq 'NS'){
        my $el = new_element(
            'span',
            {
                 title => $self->{name},
                 'its-within-text' => 'no',
                 class => '_ITS_NS'
            },
            $self->{value}
        );
        $el->paste($self->{parent}->new_node, 'first_child');
        $el->set_namespace('http://www.w3.org/1999/xhtml');
        $self->_log_new_el;
        $self->{element} = $el;
    }
    # Return the original text node. Don't wrap with an
    # element (that would prevent application of rules with
    # no inheritance, like termRule). Just make sure not to
    # paste extra text as a sibling, or the final match will
    # be different.
    elsif($self->{type} eq 'TXT'){
        $self->{element} = $self->{node};
    }
    elsif($self->{type} eq 'DOC'){
        # return the root document
        $self->{element} = $self->{node}->new_node->doc_node;
    }

    return $self->{element};
}

=head2 C<new_path>

Returns an XPath uniquely identifying the new node returned by
C<new_node>.

=cut
sub new_path {
    my ($self) = @_;
    my $node = $self->new_node;
    my $type = $node->type;
    if($type eq 'ELT'){
        return q{id('} .
            get_or_set_id($node, $self->{dom}, $log). q{')}
    }else{
        return $node->path;
    }
}

#log the creation of a new element to represent the input node type.
sub _log_new_el {
    my ($self) = @_;
    my $msg = 'Creating new <span> element to represent node of type ';
    $msg .= $self->type;
    $msg .= q< (> . $self->{name} . q<)>;
    $log->debug($msg);
    return;
}

1;
