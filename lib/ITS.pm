package ITS;
use strict;
use warnings;
# ABSTRACT: Work with ITS-decorated XML
# VERSION
use Carp;
our @CARP_NOT = qw(ITS);
use XML::Twig::XPath;
use Path::Tiny;
use Try::Tiny;
use ITS::Rule;
use feature 'say';

if(!caller){
    my $ITS =  ITS->new(file => $ARGV[0]);
    say 'Extracted rules:';
    say $_->att('xml:id') for @{ $ITS->get_rules() };
}

=head1 METHODS

=head2 C<new>

Returns an ITS object instance.
Takes one or more named parameters:

=over 3

=item C<file>

The name of an XML file with ITS markup. The file is parsed and rules are extracted
(unless a rules parameter is provided). External rule URIs are resolved relative
to the file URI.

=item C<string>

A pointer to a string containing XML with ITS markup. The string is parsed and rules
extracted (unless a rules parameter is provided). External rule URIs are resolved relative
to the current working directory.

=item C<rules>

A pointer to a string containing  XML from which to extract ITS rules. External
rule URIs are resolved relative to the current working directory.

=back

=cut

sub new {
    # TODO: also accept its:param values here
    # (not sure about precedence for them yet)
    my ($class, %args) = @_;
    my $twig;
    #either parse a file or a string
    if(exists $args{file}){
        unless(-e $args{file}){
            croak "file does not exist: $args{file}";
        }
        $twig = _create_twig();
        try{
            $twig->parsefile( $args{file} );
        } catch {
            croak "error parsing file '$args{file}': $_";
        };
    }elsif(exists $args{string}){
        $twig = _create_twig();
        try{
            $twig->parse( ${$args{string}} );
        } catch {
            croak "error parsing string: $_";
        };
    }else{
        croak 'Need to specify either a file or a string pointer with XML contents';
    }

    my $self = bless {
        twig => $twig,
    }, $class;

    my $rules_twig = $twig;
    if($args{rules}){
        $rules_twig = _create_twig();
        try{
            $rules_twig->parse( ${$args{rules}} );
        } catch {
            croak "error parsing string: $_";
        };
    }

    $self->{rules} = _resolve_rules(
        $rules_twig,
        ($args{file} ? path($args{file})->parent : path('.') ),
        $args{file} || 'string'
    );
    return $self;
}

#Returns an XML::Twig object with proper settings for parsing ITS

sub _create_twig {
    my $twig = new XML::Twig::XPath(
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

=head2 C<get_rules>

Returns an arrayref containing the ITS rule elements
(in the form of XML::Twig::XPath::Elt objects) which are to be
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
    my ($twig, $base, $name, %params) = @_;
    # first, grab internal its:rules elements
    my @rule_containers;
    my @internal_rules_containers = $twig->get_xpath('//its:rules');
    if(@internal_rules_containers == 0){
        carp "$name contains no its:rules elements!";
        return [];
    }

    # then store their rules, placing external file rules before internal ones
    my @rules;
    for my $container(@internal_rules_containers){
        my @children = $container->children();
        while($children[0]->tag eq 'its:param'){
            my $param = shift @children;
            $params{$param->att('name')} = $param->text;
        }
        if($container->att('xlink:href')){
            #path to file is relative to current file
            my $path = path($container->att('xlink:href'))->
                absolute($base);
            push @rules, @{ _get_external_rules($path, \%params) };
        }
        push @rules, map {ITS::Rule->new($_, %params)} @children;
    }

    if(@rules == 0){
        carp "no rules found in $name";
    }
    return \@rules;
}

# return list of its:*Rule's, in application order, given the name of a file
# containing an its:rules element
sub _get_external_rules {
    my ($path, $params) = @_;
    my $twig = _create_twig();
    try{
        $twig->parsefile( $path );
    } catch {
        carp "Skipping rules in file '$path': $_";
        return [];
    };
    return _resolve_rules($twig, $path->parent, $path, %$params);
}

1;