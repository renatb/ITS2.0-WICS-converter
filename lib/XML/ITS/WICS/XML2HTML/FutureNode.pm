package XML::ITS::WICS::XML2HTML::FutureNode;
use strict;
use warnings;
use XML::ITS::DOM::Element qw(new_element);
use XML::ITS::WICS::LogUtils qw(node_log_id get_or_set_id);
use Carp;
use Log::Any qw($log);
use Exporter::Easy (OK => [qw(new_pointer)]);

#VERSION
#ABSTRACT: Save a single node during DOM transformation.

=head1 SYNOPSIS

    use XML::ITS::WICS::XML2HTML::FutureNodeManager;
    use XML::ITS;
    my $f_manager = XML::ITS::WICS::XML2HTML::FutureNodeManager->new();
    my $ITS = XML::ITS->new('xml', doc => 'myITSfile.xml');
    my ($ns) = $ITS->get_root->get_xpath('namespace::*');
    my $f_ns = create_future($ns);
    # change the document around, but don't delete any elements...
    $f_ns->realize;

=head1 DESCRIPTION

This class saves nodes during DOM transformation so that they will
still be in the document later.
If you create a FutureNode for an attribute node, for example, it
will remember it's spot and create an element representing that
attribute after you call the C<realize> method. This means
that you can delete the original attribute without losing information.
The document is not changed at all until you call C<realize>,
so no XPath selectors are broken before then.

This is only guaranteed to work if document elements are not deleted
after this object's creation. This is because some FutureNodes remember
their location by their original parent.

=head1 METHODS

=head2 C<realize>

Ensures that the information in the contained node is represented by an element
in the HTML DOM. This may cause changes to the owning DOM.

Returns the ITS::DOM::Element object representing the node.

=cut
sub realize {
    my ($self) = @_;
    #only realize a node once!
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
        #paste in current version of original parent
        $el->paste(${$self->{parent}}->realize, 'first_child');
        $self->{element} = $el;
        _log_new_el('ATT');
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
                 class => '_ITS_PI'
            },
            $self->{value}
        );
        #paste in current version of original parent
        $el->paste(${$self->{parent}}->realize);
        _log_new_el('PI');
        $self->{element} = $el;
    }
    elsif($self->{type} eq 'NS'){
        my $el = new_element(
            'span',
            {
                 title => $self->{name},
                 class => '_ITS_NS'
            },
            $self->{value}
        );
        $el->paste(${ $self->{parent} }->realize, 'first_child');
        _log_new_el('NS');
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
        $self->{element} = ${ $self->{node} }->realize->doc_node;
    }

    return $self->{element};
}

#returns an XPath uniquely identifying this node
sub new_path {
    my ($self) = @_;
    my $node = $self->realize;
    my $type = $node->type;
    if($type eq 'ELT'){
        return q{id('} .
            get_or_set_id($node, $log). q{')}
    }else{
        return $node->path;
    }
}

# pastes the given element in an appropriate location, given parent and possibly
# siblings stored in $self
sub _paste_el {
    my ($self, $el) = @_;
    # if there is no next sibling, then paste this
    # element as last child of parent
    if(my $sib = $self->{nextSib}){
        $el->paste($sib, 'before');
    }elsif(my $parent = $self->{parent}){
        $el->paste($parent);
    }elsif(my $node = $self->{node}){
        $el->paste($node, 'after');
    }else{
        croak 'Don\'t know where to paste ' . $el->name;
    }
    _log_new_el($self->{type});
}

#log the creation of a new element to represent the input node type.
sub _log_new_el {
    my ($type) = @_;
    if($log->is_debug){
        $log->debug('Creating new <span> element to represent node of type ' .
            $type);
    }
}

1;
