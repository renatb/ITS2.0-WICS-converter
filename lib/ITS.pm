package ITS;
use strict;
use warnings;
# ABSTRACT: Work with ITS-decorated XML
# VERSION
use Carp;
our @CARP_NOT = qw(ITS);
use XML::Twig;
use XML::Twig::XPath;
use Path::Tiny;
use Try::Tiny;
use feature 'say';

if(!caller){
    my $ITS =  ITS->new(file => $ARGV[0]);
    say 'Extracted rules:';
    say $_->att('xml:id') for @{ $ITS->get_rules() };
}

=head1 METHODS

=head2 C<new>

Returns an object instance after parsing the given XML.
Takes a named argument; if C<file>, the value should be the name of an XML file with ITS markup.
If C<string>), the value should be a pointer to a string containing XML with ITS markup.

=cut

sub new{
    my ($class, %args) = @_;
    my $twig;
    #either parse a file or a string using the XML2HTML twig
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

    $self->{rules} = _resolve_rules(
        $twig,
        ($args{file} ? path($args{file})->parent : path('.') ),
        $args{file} || 'string'
    );
    return $self;

    # my $rules = _get_rules($twig, path($args{file}) || '.');
    # say scalar @$rules;
    # say $_->att('xml:id') for @$rules;
    # exit;
}

#Returns an XML::Twig object with proper settings for parsing ITS

sub _create_twig {
    my $twig = new XML::Twig(
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

=head2 get_rules

Returns an arrayref containing the ITS rule elements
(in the form of XML::Twig::Elt objects) which are to be
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

# find and save all its:*Rule's elements to be applied in
# $twig, in order of application
# $base is the base URI to resolve relative ones
# $name is a name for the input to use in errors
# (like filename or 'string')
sub _resolve_rules {
    my ($twig, $base, $name) = @_;

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
        if($container->att('xlink:href')){
            #path to file is relative to current file
            my $path = path($container->att('xlink:href'))->
                absolute($base);
            push @rules, @{ _get_external_rules($path) };
        }
        push @rules, $container->children;
    }

    if(@rules == 0){
        carp "no rules found in $name";
    }
    return \@rules;
}

# return list of its:*Rule's, in application order, given the name of a file
# containing an its:rules element
sub _get_external_rules {
    my ($path) = @_;
    my $twig = _create_twig();
    $twig->parsefile($path);
    return _resolve_rules($twig, $path->parent, $path);
}

1;