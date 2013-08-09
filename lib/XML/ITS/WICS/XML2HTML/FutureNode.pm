package XML::ITS::WICS::XML2HTML::FutureNode;

# several cases to handle:
# namespaces, attributes and PIs are destroyed during conversion;
# elements stay but are sometimes replaced
# text stays
# the document is replaced, but keeps same XPath
# comments stay, but XPath changes.

use strict;
use warnings;
use Exporter::Easy (
    OK => [qw(create_future clear_indices get_all_atts get_all_non_atts replace_el_future)]
);
use XML::ITS::DOM::Element qw(new_element);
use XML::ITS::WICS::LogUtils qw(node_log_id);
use Carp;
use Log::Any qw($log);
use Data::Dumper; #DEBUG

# VERSION
# ABSTRACT: Ensure the future existence of an element without changing the DOM now

# some indices to manage
my %future_cache;
#todo: change these to just holding ID, and return nodes retrieved from
#future_cache in get methods. Will help in document editing.
my %atts; #atts
my %non_atts; #everything but text, elements, and atts
my $id_num = 0;

sub clear_indices {
    %atts = ();
    %non_atts = ();
    %future_cache = ();
    $id_num = 0;
}

sub replace_el_future {
    my ($old_el, $new_el) = @_;
    ${ $future_cache{$old_el->unique_key} } = ${ create_future($new_el) };
}

sub get_all_atts {
    return values %atts;
}

sub get_all_non_atts {
    return values %non_atts;
}

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

If the input node is an XML::ITS::DOM::Node (or Element), this method creates
a FutureNode object and returns it. If it is an XML::ITS::DOM::Value,
it simply returns it.

The owning document as a second argument is required for namespace nodes, which
store no reference to any other nodes.

No changes are made to the owning DOM in this method.

=cut
sub create_future {
    my ($node, $doc) = @_;

    if($future_cache{$node->unique_key}){
        return $future_cache{$node->unique_key};
    }

    #store the state required to paste a representative node later
    my $type = $node->type;
    my $state = {type => $type};
    if($type eq 'ELT'){
        $state->{node} = $node;
    }elsif($type eq 'ATT'){
        $state->{parent} = create_future($node->parent, $doc);
        $state->{name} = $node->name;
        $state->{value} = $node->value;
    }elsif($type eq 'COM'){
        $state->{node} = $node;
    }
    #use sibling to keep exact location
    elsif($type eq 'PI'){
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
        ($state->{node}) = $node->children;
    }

    return _new($node, $state);
}

#create a FutureNode representing $node with the given $state,
# and add a pointer to it to the future cache. Return the pointer.
sub _new {
    my ($node, $state) = @_;

    my $future_node = bless $state, __PACKAGE__;
    # Cache FutureNodes so that we don't create one for the
    # same node multiple times.
    # Store pointers so that changes in future_cache can propagate.
    $future_cache{$node->unique_key} = \$future_node;
    return \$future_node;
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
        #paste in current version of original parent
        $el->paste(${$self->{parent}}->elemental, 'first_child');
        $self->{element} = $el;
        $atts{$el->unique_key} = $el;
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
        $el->paste(${$self->{parent}}->elemental);
        _log_new_el('PI');
        $self->{element} = $el;
        $non_atts{$el->unique_key} = $el;
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
        $el->paste(${ $self->{parent} }->elemental, 'first_child');
        _log_new_el('NS');
        $self->{element} = $el;
        $non_atts{$el->unique_key} = $el;
    }
    # paste the text node into a new element in its place,
    # to guarantee that the deletion of other nodes won't
    # merge it with another text node. Return value is still
    # the original text node
    elsif($self->{type} eq 'TXT'){
        my $el = new_element(
            'span',
            {
                 title => $self->{node}->name,
                 class => '_ITS_TXT',
            },
            $self->{value}
        );
        $el->paste($self->{node}, 'after');
        $self->{node}->paste($el);
        if($log->is_debug){
            $log->debug('wrapping ' .
                node_log_id($self->{node}) .
                ' with ' . node_log_id($el) .
                ' to prevent matching any merged text');
        }
        $self->{element} = $self->{node};
    }
    elsif($self->{type} eq 'DOC'){
        #return the root document
        $self->{element} = $self->{node}->doc_node('/');
    }

    return $self->{element};
}

#returns an XPath uniquely identifying this node
sub new_path {
    my ($self) = @_;
    my $node = $self->elemental;
    my $type = $node->type;
    if($type eq 'ELT'){
        return q{id('} .
            _get_or_set_id($node). q{')}
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

#returns the id attribute of the given element; creates one if none exists.
sub _get_or_set_id {
    my ($el) = @_;
    my $id = $el->att('id');
    if(!$id){
        $id = _next_id();
        if($log->is_debug){
            $log->debug('Setting id of ' . node_log_id($el) . " to $id");
        }
        $el->set_att('id', $id);
    }
    return $id;
}

#returns a unique string "ITS_#", '#' being some number.
sub _next_id {
    $id_num++;
    return "ITS_$id_num";
}

1;
