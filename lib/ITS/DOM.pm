package ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use Carp;
our @CARP_NOT = qw(ITS::DOM ITS);
use Try::Tiny;
use Path::Tiny;
#the XML engine currently used
use XML::Twig::XPath;

=head1 SYNOPSIS

    use ITS::DOM;
    use feature 'say';
    my $dom = ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_nodes('//@foo');

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It abstracts away XML/HTML processing to quarantine 3rd party code.

=head1 METHODS

=head2 C<new>

Argument: a single named argument. The name should be either 'xml' or
'html', and the value is either a string filepath or a string pointer
containing the actual data to be parsed.

Parses the input document, creating a queryable DOM structure.

=cut

sub new {
    my ($class, %args) = @_;
    my $dom;
    my $source;
    if($args{xml}){
        $dom = _get_xml_dom($args{xml});
        $source = $args{xml};
    }elsif($args{html}){
        croak 'HTML parsing not supported yet';
        $source = $args{html};
    }

    my $base;
    if(ref $source eq 'SCALAR'){
        $base = path('.');
    }else{
        $base = path($source)->parent;
    }

    return bless {dom => $dom, base => $base}, $class;
}

=head2 C<get_xpath>

Argument: XPath string to query document with

Returns a list of ITS::DOM::Node objects matching the given XPath.

=cut

sub get_xpath {
    my ($self, $xpath) = @_;
    my @nodes =
        map {ITS::DOM::Node->new($_)}
        $self->{dom}->findnodes($xpath);
    return @nodes;
}

=head2 C<get_base_uri>

Returns the path of the directory containing the DOM content
(which is '.' for strings). This is useful for resolving relative
URIs.

=cut
sub get_base_uri {
    my ($self) = @_;
    return $self->{base};
}

sub _get_xml_dom {
    my ($xml) = @_;

    my $dom = _create_twig();
    if(ref $xml eq 'SCALAR'){
        #string refs are xml content;
        try{
            $dom->parse( $$xml );
        } catch {
            croak "error parsing string: $_";
        };
    }
    else{
        #strings are file names
        try{
            $dom->parsefile( $xml );
        } catch {
            croak "error parsing file '$xml': $_";
        };
    }
    return $dom;
}

#Returns an XML::Twig object with proper settings for parsing ITS
sub _create_twig {
    my $twig = XML::Twig::XPath->new(
        map_xmlns               => {
            'http://www.w3.org/2005/11/its' => 'its',
            'http://www.w3.org/1999/xlink' => 'xlink'
        },
        # empty_tags              => 'html',
        pretty_print            => 'indented',
        output_encoding         => 'UTF-8',
        keep_spaces             => 0,
        no_prolog               => 1,
        #can be important when things get complicated
        do_not_chain_handlers   => 1,
    );
    return $twig;
}

1;

package ITS::DOM::Node;

use strict;
use warnings;
# VERSION
# ABSTRACT: thin wrapper around underlying XML engine node objects
use Carp;
use feature 'switch';

=head1 SYNOPSIS

    use ITS::DOM;
    use feature 'say';
    my $dom = ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_nodes('//@foo');
    for(@nodes){
        say $node->text;
    }

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It is a thin wrapper around an XML::Twig::XPath nodes.

=head1 METHODS

=head2 C<new>

Argument: a single XML/HTML node

=cut
sub new {
    my ($class, $node) = @_;
    # print $node->tag . "---\n";
    return bless {
        node => $node,
        type => _get_type($node),
    }, $class;
}

sub _get_type {
    my ($node) = @_;
    my $type;
    given($node){
        when($node->isElementNode){$type = 'ELT'; break;}
        when($node->isAttributeNode){$type = 'ATT'; break;}
        when($node->isTextNode){$type = 'TXT'; break;}
        when($node->isNamespaceNode){$type = 'NS'; break;}
        when($node->isPINode){$type = 'PI'; break;}
        when($node->isCommentNode){$type = 'COM'; break;}
        when(ref $node eq 'XML::Twig::XPath'){$type = 'DOC'; break;}
        default{croak "unknown node type for $node";}
    }
    return $type;
}

=head2 C<type>

Returns a string representing the type of the node:
C<ELT>, C<ATT>, C<TXT>, C<NS>, C<PI>, C<COM> or C<DOC>.

=cut
sub type {
    my ($self) = @_;
    return $self->{type};
}

=head2 C<name>

Returns the name of the node. This is the tag name for elements,
the name for attributes and PIs, etc.

=cut
sub name {
    my ($self) = @_;
    return $self->{node}->getName;
}

=head2 C<local_name>

If this node is an element, this method returns its name without
the namespace prefix.
=cut
sub local_name {
    my ($self) = @_;
    return $self->{node}->local_name;
}

=head2 C<value>

Returns the value of the node. This is text content of some kind.

=cut
sub value {
    my ($self) = @_;
    return $self->{node}->getValue;
}

=head2 C<att>

If this node is an element, returns the value of the given attribute.

=cut
sub att {
    my ($self, $name) = @_;
    return $self->{node}->att($name);
}

=head2 C<atts>

If this node is an element, returns a hash pointer containing all of its
attributes and their values.

=cut
sub atts {
    my ($self, $name) = @_;
    return \%{$self->{node}->atts};
}

=head2 C<children>

If this node is an element, returns an array pointer containing the
child nodes of this element.

=cut
sub children {
    my ($self) = @_;
    my @children = map {ITS::DOM::Node->new($_)} $self->{node}->children;
    return \@children;
}
