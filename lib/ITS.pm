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

=head2 C<get_match>

Argument: C<ITS::Rule> object.

Returns a list of matches on this ITS document against the input rule.
Each element of the list is an hash ref containing at least one key,
C<selector> wich value is the node which it matched. Any other keys
are names of pointer attributes and their matched nodes.

=cut

sub get_match {
    my ($self, $rule) = @_;
    my @matches;
    my $xpath = $rule->selector;
    return undef unless defined $xpath;

    my @selector_matches = $self->{twig}->findnodes($xpath);
    return \@selector_matches;
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
    return $doc->get_xpath(
        '//its:rules',
        {},
        {
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