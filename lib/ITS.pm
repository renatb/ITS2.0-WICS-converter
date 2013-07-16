package ITS;
use strict;
use warnings;
# ABSTRACT: Work with ITS-decorated XML
# VERSION
use Carp;
our @CARP_NOT = qw(ITS);
use ITS::DOM;
use Path::Tiny;
use Try::Tiny;
use ITS::Rule;
use feature 'say';
use Data::Dumper; #debug

# as script: extract ITS rules from input doc and list IDs
if(!caller){
    my $ITS =  ITS->new(file => $ARGV[0]);
    say 'Extracted rules:';
    say $_->att('xml:id') for @{ $ITS->get_rules() };
}

=head1 SYNOPSIS

    use ITS;
    use feature 'say';
    my $ITS = ITS->new(file => 'myfile.xml', rules);
    my $rules = $ITS->get_rules;
    $ITS->iterate_matches(sub{
        my ($rule, $selectorMatch, $pointerMatches) = @_;
        say "$rule matched " . $selectorMatch->id . " and pointers " .
            join ', ', map {$_->id} @$pointerMatches;
    });

=head1 DESCRIPTION

This module is for working with ITS decorated XML or HTML documents.
It allows you to resolve all of the global and find matches for each
of them.

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

    if($file_type !~ /^xml|html$/ or !$args{doc}){
        croak 'usage: ITS->new("(xml|html)", doc => "file", [rules => "file"]';
    }
    my $doc = ITS::DOM->new($file_type => $args{doc});

    my $self = bless {
        doc => $doc,
    }, $class;

    my $rules_doc = $doc;
    if($args{rules}){
        $rules_doc = ITS::DOM->new($file_type => $args{rules});
    }

    $self->{rules} = _resolve_rules($rules_doc);
    return $self;
}


=head2 C<get_rules>

Returns an arrayref containing the ITS rule elements
(in the form of ITS::Rule objects) which are to be
applied to the document, in the order in which they will
be applied.

Keep in mind that, while it is useful to be able to edit these
rules, there isn't much in the way of validity checking
for them, so you must be careful in what you do to them.

=cut

sub get_rules {
    my ($self) = @_;
    return $self->{rules};
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
    my $namespaces = $rule->node->get_namespaces;
    my $params = $rule->params;

    # $selector_matches is the "current node list", which is
    # used to calculate context size and position for pointer XPaths
    my $context_size = scalar @$selector_matches;
    my $context_pos = 0;

    for my $selector_match ( @{ $selector_matches } ){
        $context_pos++;
        my $match;
        $match->{selector} = $selector_match;
        for my $pointer(@{ $rule->pointers }){
            $match->{$pointer} =
                _pointer_match(
                    $selector_match,
                    $rule->node->att($pointer),
                    $namespaces,
                    $params,
                    $context_size,
                    $context_pos);
        }
        push @matches, $match;
    }
    return \@matches;
}

# return an array ref of ITS::DOM::Nodes matching selector of given rule
# From the spec, the selector is an "absolute selector":
# Context for evaluation of the XPath expression is as follows:
# Context node is set to Root Node.
# Both context position and context size are 1.
# All variables defined by param elements are bind.
# All functions defined in the XPath Core Function Library are available. It is an error for an expression to include a call to any other function.
# The set of namespace declarations are those in scope on the element which has the attribute in which the expression occurs. This includes the implicit declaration of the prefix xml required by the XML Namespaces Recommendation; the default namespace (as declared by xmlns) is not part of this set.
sub _selector_matches {
    my ($self, $rule) = @_;

    my $xpath = $rule->selector;
    return [] unless defined $xpath;

    my $context_node = $self->{doc}->get_root;
    my $context_pos  = 1;
    my $context_size = 1;
    my $params = $rule->params;
    my $namespaces = $rule->node->get_namespaces;
    my @nodes = $context_node->get_xpath(
        $xpath,
        position => $context_pos,
        size => $context_size,
        params => $params,
        namespaces => $namespaces,
    );
    return \@nodes;
}

#Context for evaluation of the XPath expression is same as for absolute selector with the following changes:
# Nodes selected by the expression in the selector attribute form the current node list.
# Context node comes from the current node list.
# The context position comes from the position of the current node in the current node list; the first position is 1.
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

    # TODO: not sure about parameters
    # my $params = $rule->params;
    my @nodes = $context_node->get_xpath(
        $xpath,
        size => $context_size,
        position => $context_pos,
        params => $params,
        namespaces => $namespaces,
    );
    if(scalar @nodes > 1){
        carp "relative selector $xpath selects more than 1 node. Using just the first.";
    }
    return $nodes[0];
}

=head2 C<get_twig>

Returns the XML::Twig::XPath object used internally to represent and process
the ITS document.

=cut

sub get_twig {
    my ($self) = @_;
    return $self->{twig};
}


# find and save all its:*Rule's elements to be applied in
# $twig, in order of application
# $base is the base URI to resolve relative ones
# $name is a name for the input to use in errors
# (like filename or 'string')
sub _resolve_rules {
    my ($doc, %params) = @_;
    # first, grab internal its:rules elements
    my @rule_containers;
    my @internal_rules_containers = _get_its_rules_els($doc);
    if(@internal_rules_containers == 0){
        return [];
    }

    # then store their rules, placing external file rules before internal ones
    my @rules;
    for my $container(@internal_rules_containers){
        my $children = $container->children();
        #todo: use URI, not prefix
        while($children->[0]->name eq 'its:param'){
            my $param = shift @$children;
            $params{$param->att('name')} = $param->text;
        }
        # warn $children->[0]->name;
        if($container->att('xlink:href')){
            #path to file is relative to current file
            my $path = path($container->att('xlink:href'))->
                absolute($doc->get_base_uri);
            push @rules, @{ _get_external_rules($path, \%params) };
        }
        push @rules, map {ITS::Rule->new($_, %params)} @$children;
    }

    if(@rules == 0){
        carp 'no rules found in ' . $doc->get_source;
    }
    return \@rules;
}

sub _get_its_rules_els {
    my ($doc) = @_;
    return $doc->get_root->get_xpath(
        '//its:rules',
        namespaces => {
            its => 'http://www.w3.org/2005/11/its'
        }
    );
}

# return list of its:*Rule's, in application order, given the name of a file
# containing an its:rules element
sub _get_external_rules {
    my ($path, $params) = @_;
    my $doc;
    try{
        #TODO: will it always be 'xml'?
        $doc = ITS::DOM->new('xml' => $path );
    } catch {
        carp "Skipping rules in file '$path': $_";
        return [];
    };
    return _resolve_rules($doc, %$params);
}

1;