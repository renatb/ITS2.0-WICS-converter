package XML::ITS;
use strict;
use warnings;
# ABSTRACT: Work with ITS-decorated XML
# VERSION
use XML::ITS::XMLRuleExtractor;
use XML::ITS::HTMLRuleExtractor;
use XML::ITS::DOM;
use XML::ITS::RuleContainer;
use XML::ITS::Rule;

use Carp;

use Path::Tiny;
use Try::Tiny;
use feature 'say';
# use Data::Dumper; #debug
use Exporter::Easy (
    OK => [qw(its_ns xlink_ns)],
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
    use feature 'say';
    my $ITS = XML::ITS->new(file => 'myITSfile.xml');
    my $rules = $ITS->get_rules;
    for my $rule (@$rules){
        say $rule->type;
        for my $match(@{ $ITS->get_matches($rule) }){
            say "$_ => $match{$_}" for keyes %$match;
        }
    }

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

=head2 C<xlink_ns>

Returns the xlink namespace URI (C<xlink:href> is used by the C<its:rules>
element to import external rules).

=cut
sub xlink_ns{
    return $XLINK_NS;
}

=head1 METHODS

=head2 C<new>

Returns an XML::ITS object instance.
Arguments: The first is either 'xml' or 'html' to indicate the type of
document being parsed. After that, you must specify 'doc' and
may also optionally specify 'rules' parameters. The value of these parameters
should be either a string containing a file path or a string reference
containing actual ITS data. The 'doc' argument should point to the
document to which ITS data is being applied, and the 'rules' argument
should point to a document containing the ITS rules to apply (this may only
be an XML document, not an HTML document).

=cut

sub new {
    # TODO: also accept its:param values here
    # (not sure about precedence for them yet)
    my ($class, $file_type, %args) = @_;

    if($file_type !~ /^(?:xml|html)$/ || !$args{doc}){
        croak 'usage: ITS->new("(xml|html)", doc => "file", [rules => "file"]';
    }
    my $doc = XML::ITS::DOM->new($file_type => $args{doc});

    my $self = bless {
        doc => $doc,
        file_type => $file_type
    }, $class;

    $self->{rules_doc} = $doc;
    if($args{rules}){
        #rules docs are only allowed to be XML
        $self->{rules_doc} = XML::ITS::DOM->new('xml' => $args{rules});
    }

    $self->eval_rules;
    return $self;
}

=head2 C<eval_rules>

This method detects any ITS rules contained or referenced by the document (or
the separate rules document), setting the values that can be obtained via
C<get_containers> and C<get_rules>. This is always run by the C<new> method,
but if the document (retrievable via C<get_dom>) is edited, the ITS rules contents
may have changed, making it necessary to call this method.

=cut
sub eval_rules {
    my ($self) = @_;
    # rules docs are only allowed to be XML
    if($self->{file_type} eq 'xml' or $self->{doc} != $self->{rules_doc}){
        $self->{rule_containers} =
            XML::ITS::XMLRuleExtractor::_resolve_doc_containers(
                $self->{rules_doc});
    }else{
        $self->{rule_containers} =
            XML::ITS::HTMLRuleExtractor::_resolve_doc_containers(
                $self->{rules_doc});
    }
    return;
}

=head2 C<get_doc_type>

Returns either 'html' or 'xml' indicating the type of file being represented.

=cut
sub get_doc_type {
    my ($self) = @_;
    return $self->{file_type};
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
be applied.

=cut
sub get_rules {
    my ($self) = @_;
    my @rules;
    # return a list of rules taken from all of the
    # rule containers
    for my $container (@{ $self->{rule_containers} }){
        push @rules, @{$container->rules};
    }
    return \@rules;
}

=head2 C<get_containers>

Returns an arrayref containing ITS::RuleContainer objects, one for each C<its:rules>
or C<script type="application/its+xml"> element found in the document or externally.
The containers are returned in application order (the order that their rules should
be applied in).

=cut
sub get_containers {
    my ($self) = @_;
    # shallow copy
    return [@{ $self->{rule_containers} }];
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

1;

=head1 CAVEATS

In browsers, all HTML is considered to be in the C<http://www.w3.org/1999/xhtml>
namespace, XPath but XPath expressions use this as a default namespace. This is
not currently possible with this module, so the XHTML namespace must be used
explicitly in rules for HTML documents, like so:

    <its:rules xmlns:its="http://www.w3.org/2005/11/its"
        xmlns:h="http://www.w3.org/1999/xhtml"
        version="2.0">
          <its:translateRule selector="//h:p" translate="yes"/>
    </its:rules>

Currently rule selection will not work for the C<id()> XPath expression
in HTML documents.

=head1 TODO

This module does not support querying individual elements for ITS information.
This would be very useful, but it would require the implementation of
inheritance and per-category knowledge (currently there is none!). Reference
L<http://www.w3.org/International/its/wiki/ITS_Processor_Interface> for an
idea of what is wanted.

ITS allows for other types of selectors. This module, however,
only allows XPath selectors. CSS selectors could be implemented,
for example, with C<HTML::Selector::XPath>.

Currently this module does not check ITS version. All rules
are assumed to be ITS version 2.0.

Section 5.3.5 of the ITS spec mentions that implementors should provide
a way to set default values for parameters. This would be useful, but what
is the menaing of i<default> value here? Are there documents without param
declarations but with XPaths that contain variables? Or should this just be
a mechanism to allow the user to set the value of a param, no matter what
values are present in the document?