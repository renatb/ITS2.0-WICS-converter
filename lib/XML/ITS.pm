package XML::ITS;
use strict;
use warnings;
# ABSTRACT: Work with ITS-decorated XML
# VERSION
use XML::ITS::DOM;
use XML::ITS::Rule;

use Carp;
our @CARP_NOT = qw(ITS);

use Path::Tiny;
use Try::Tiny;
use feature 'say';
# use Data::Dumper; #debug
use Exporter::Easy (
    OK => [qw(its_ns)],
);

my $ITS_NS = 'http://www.w3.org/2005/11/its';

my $XLINK_NS = 'http://www.w3.org/1999/xlink';

# as script: extract ITS rules from input doc and list IDs
if(!caller){
    my $ITS =  XML::ITS->new('xml', doc => $ARGV[0]);
    say 'Extracted rules:';
    say $_->element->att('xml:id') for @{ $ITS->get_rules() };
}

=head1 SYNOPSIS

    use XML::ITS;
    my $ITS = XML::ITS->new(file => 'myITSfile.xml');
    my $rules = $ITS->get_rules;
    $ITS->iterate_matches(sub{
        my ($rule, $matches) = @_;
        # do something with matches here
    });

=head1 DESCRIPTION

This module is for working with ITS decorated XML or HTML documents.
It allows you to resolve all of the global and find matches for each
of them.

=head1 EXPORTS

The following function may be exported:

=head2 C<its_ns>

Returns the ITS namespace URI.

=cut
sub its_ns{
    return $ITS_NS;
}

=head1 METHODS

=head2 C<new>

Returns an ITS object instance.
Arguments: The first is either 'xml' or 'html' to indicate the type of
document being parsed. After that, you must specify 'doc' and
may also specify 'rules' parameters. The value of these parameters
should be either a string containing a file path or a string reference
containing actual ITS data. The 'document' argument should point to the
document to which ITS data is being applied, and the 'rules' argument
should point to the document containing the ITS rules to apply.

=cut

sub new {
    # TODO: also accept its:param values here
    # (not sure about precedence for them yet)
    my ($class, $file_type, %args) = @_;

    if($file_type !~ /^xml|html$/ || !$args{doc}){
        croak 'usage: ITS->new("(xml|html)", doc => "file", [rules => "file"]';
    }
    my $doc = XML::ITS::DOM->new($file_type => $args{doc});

    my $self = bless {
        doc => $doc,
    }, $class;

    my $rules_doc = $doc;
    if($args{rules}){
        $rules_doc = XML::ITS::DOM->new($file_type => $args{rules});
    }

    $self->{rules} = _resolve_doc_rules($rules_doc);
    return $self;
}

=head2 C<get_doc>

Returns the XML::ITS::DOM object created from the input
document.

=cut
sub get_doc {
    my ($self) = @_;
    return $self->{doc};
}

=head2 C<get_rules>

Returns an arrayref containing the ITS rule elements
(in the form of XML::ITS::Rule objects) which are to be
applied to the document, in the order in which they will
be applied. The returned arrayref is the one used to store
rules internally, making it possible to add, remove, or
rearrange them.

Keep in mind that, while it is useful to be able to edit these
rules, there isn't much in the way of validity checking
for them, so you must be careful in what you do to them.

=cut

sub get_rules {
    my ($self) = @_;
    return $self->{rules};
}

=head2 C<iterate_matches>

Iterates over each match of each document rule, in order of
application.

The first argument is a subroutine reference to be called for each
match. The arguments to the subroutine are first the matching rule and
then a hash reference representing the hash object (see C<get_matches>
below).

The second argument is optionally an array ref of rules to find matches
for (no argument uses internal rules).

=cut

sub iterate_matches {
    my ($self, $sub, $rules) = @_;
    croak 'subroutine required!'
        unless $sub and (ref $sub eq 'CODE');
    if(!$rules){
        $rules = $self->get_rules;
    }
    for my $rule(@$rules){
        my $matches = $self->get_matches($rule);
        for my $match (@$matches){
            $sub->($rule, $match);
        }
    }
    return;
}

=head2 C<get_matches>

Argument: C<ITS::Rule> object.

Returns an array ref of matches on this ITS document against the input
rule. Each element of the list is a hash ref containing at least one
key, C<selector>, whose value is the document node which the rule
selector matched.
Any other keys are names of pointer attributes, and their values are
their matched document nodes.

=cut
sub get_matches {
    my ($self, $rule) = @_;
    my @matches;
    return [] unless defined $rule->selector;

    # first, find the matches for the selector attribute
    my $selector_matches = $self->_selector_matches($rule);
    my $namespaces = $rule->element->get_namespaces;
    my $params = $rule->params;

    # $selector_matches is the "current node list", which is
    # used to calculate context size and position for pointer XPaths
    my $context_size = scalar @$selector_matches;
    my $context_pos = 0;

    for my $selector_match ( @{ $selector_matches } ){
        $context_pos++;
        if($selector_match->type !~ /^(?:ELT|ATT)$/){
            carp 'skipping match of illegal type ' .
                $selector_match->type .
                ' (only ELT or ATT are allowed) from selector: ' .
                $rule->selector;
             next;
        }
        my $match;
        $match->{selector} = $selector_match;
        for my $pointer(@{ $rule->pointers }){
            my $pointer_match =
                _pointer_match(
                    $selector_match,
                    $rule->element->att($pointer),
                    $namespaces,
                    $params,
                    $context_size,
                    $context_pos
                );
            #don't save the pointer match if there was none
            if($pointer_match){
                $match->{$pointer} = $pointer_match;
            }
        }
        push @matches, $match;
    }
    return \@matches;
}

=head2 C<filter_rules>

This method takes one argument: a subroutine which should return a boolean value.
This method loops through all of the ITS rules associated with this document,
calls the input subroutine with the rule as an argument, and removes the rule
from the document if the subroutine does not return a true value. For example,
the following can be used to remove all C<preserveSpace> rules from the document:

  $ITS->filter_rules(sub {
    return $_[0]->type ne 'preserveSpace';
  });

=cut
sub filter_rules {
    my ($self, $filter) = @_;
    my $rules = $self->get_rules;
    @$rules = grep {$filter->($_)} @$rules;
    return;
}

# return an array ref of XML::ITS::DOM::Nodes matching selector of given rule
# From the spec, the selector is an "absolute selector":
# Context for evaluation of the XPath expression is as follows:
# Context node is set to Root Node.
# Both context position and context size are 1.
# All variables defined by param elements are bind.
# All functions defined in the XPath Core Function Library are available. It
# is an error for an expression to include a call to any other function.
# The set of namespace declarations are those in scope on the element which
# has the attribute in which the expression occurs. This includes the implicit
# declaration of the prefix xml required by the XML Namespaces Recommendation;
# the default namespace (as declared by xmlns) is not part of this set.
sub _selector_matches {
    my ($self, $rule) = @_;

    my $xpath = $rule->selector;
    return [] unless defined $xpath;

    my $context_node = $self->{doc}->get_root;
    my $context_pos  = 1;
    my $context_size = 1;
    my $params = $rule->params;
    my $namespaces = $rule->element->get_namespaces;
    my @nodes = $context_node->get_xpath(
        $xpath,
        position => $context_pos,
        size => $context_size,
        params => $params,
        namespaces => $namespaces,
    );
    return \@nodes;
}

# return XML::ITS::DOM::Node or XML::ITS::DOM::Value object, or, if nothing matched, undef.
# Context for evaluation of the XPath expression is same as for absolute selector
# with the following changes:
# Nodes selected by the expression in the selector attribute form the current node list.
# Context node comes from the current node list.
# The context position comes from the position of the current node in the current
# node list; the first position is 1.
# The context size comes from the size of the current node list.
sub _pointer_match {
    my (
        $context_node,
        $xpath,
        $namespaces,
        $params,
        $context_size,
        $context_pos
    ) = @_;

    my @nodes = $context_node->get_xpath(
        $xpath,
        size => $context_size,
        position => $context_pos,
        params => $params,
        namespaces => $namespaces,
    );
    if((my $num_nodes = scalar @nodes) != 1){
        my $warning = "Relative selector $xpath returned $num_nodes nodes";
        if(my $id = $context_node->att('xml:id')){
            $warning .= " in element $id";
        }
        if($num_nodes > 1){
            $warning .= "\nUsing first match";
        }
        carp $warning;
    }
    return $nodes[0]
        if $nodes[0];
    return;
}

# find and save all its:*Rule's elements to be applied in
# the given document, in order of application, including external ones
# %params are all of the parameters already defined for this document
sub _resolve_doc_rules {
    # note that we don't pass around hash pointers for the params so that
    # all parameters are correctly scoped for each document or its:rules element.
    my ($doc, %params) = @_;

    # first, grab internal its:rules elements
    my @internal_rules_containers = _get_its_rules_els($doc);
    if(@internal_rules_containers == 0){
        return [];
    }

    # then store individual rules in application order (external first)
    my @rules;
    for my $container(@internal_rules_containers){
        my $container_rules =
        _resolve_container_rules(
            $doc,
            $container,
            %params
        );
        push @rules, @{$container_rules};
    }

    if(@rules == 0){
        carp 'no rules found in ' . $doc->get_source;
    }
    return \@rules;
}

# input: document, its:rules element, and list of param names/values.
# return an array ref containing application-order rules retreived from
# given container (and referenced external rules).
sub _resolve_container_rules {
    my ($doc, $container, %params) = @_;

    my $children = $container->child_els();

    if(@$children){
        while($children->[0]->local_name eq 'param' and
            $children->[0]->namespace_URI eq $ITS_NS){
            my $param = shift @$children;
            $params{$param->att('name')} = $param->text;
        }
    }
    my @rules;
    if($container->att('href', $XLINK_NS)){
        #path to file is relative to current file
        my $path = path( $container->att('href', $XLINK_NS) )->
            absolute($doc->get_base_uri);
        push @rules, @{ _get_external_rules($path, \%params) };
    }
    push @rules, map {ITS::Rule->new($_, %params)} @$children;
    return \@rules;
}

#returns the set of its:rules nodes from the input document
sub _get_its_rules_els {
    my ($doc) = @_;
    return $doc->get_root->get_xpath(
        "//*[namespace-uri()='$ITS_NS'" .
            q{and local-name()='rules']},
    );
}

# return list of its:*Rule's, in application order, given the name of a file
# containing an its:rules element, and parameters so far
sub _get_external_rules {
    my ($path, $params) = @_;
    my $doc;
    try{
        #TODO: will it always be 'xml'?
        $doc = XML::ITS::DOM->new('xml' => $path );
    } catch {
        carp "Skipping rules in file '$path': $_";
        return [];
    };
    return _resolve_doc_rules($doc, %$params);
}

1;

=head1 TODO

ITS allows for other types of selectors. This module, however,
only allows XPath selectors. CSS selectors could be implemented,
for example, with C<HTML::Selector::XPath>.

Currently this module does not check ITS version. All rules
are assumed to be ITS version 2.0.
