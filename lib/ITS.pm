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

sub new {
    # TODO: also accept its:param values here
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

=head2 C<localize_all_rules>

Loops through document rules, in application order, and creates
corresponding local attributes on their selected elements. See
C<localize_rule> for how this is done.

This method avoids the selction-breaking corner cases of
C<localize_rule> by computing all rule matches before making any
changes to the document.

=cut

sub localize_all_rules {
    my ($self) = @_;

    #first loop document and create match index
    my $matchIndex;
    for my $rule($self->get_rules){

        #TODO: make separate classes for rules. That class
        #should check that selector is present, and hold
        #important attributes with HTML equivalents,
        #inheritance information, and variable references.

        # immediately apply document-changing rules
        if($rule->tag =~
            /^(?:idValueRule|langRule|preserveSpaceRule)$/){
            $self->localize_rule($rule);
            next;
        }
        my @matches = $self->get_twig->findnodes($rule->att('selector'));
        for my $match(@matches){

        }
    }
}

=head2 C<localize_rule>

Localizes the input rule onto its selected elements. This is done
by creating local attributes which correspond to the rule contents.
For example, the following global rule:

 <its:locNoteRule locNoteType="description" selector="//a">
     <its:locNote>Note XYZ</its:locNote>
 </its:locNoteRule>

would change an element C<a> with no attributes into the following:

 <a its:locNoteType="description" its:locNote="Note XYZ."/>

All pointer-type attributes are resolved into non-pointers. For
example, the following global rule:

 <its:locNoteRule
     locNoteType="description"
     selector="//a"
     locNotePointer="../note"/>

would turn to the following:

 <xml>
  <note>Note ABC</note>
  <a>Foo bar</a>
 </xml>

into this:

 <xml>
  <note>Note ABC</note>
  <a its:locNoteType="description" its:locNote="Note ABC">Foo bar</a>
 </xml>

Keep in mind that localizing a rule means changing a document. You may,
if you are not careful, break some of the ITS rule selectors. For example,
For example, say someone creates a rule with the selector
C<//msg[count(@*)=0]>, and that it matches an element C<msg> with no attributes.
If another rule (say, a C<translateRule>) matches C<msg> and we localize
the information onto the element so that it becomes C<msg translate="yes">,
then the above  selector will no longer be able to match the element it
was intended for. To avoid this kind of corner case, use C<localize_all_rules>,
which computes all matches before changing the document.

=cut

sub localize_rule {
    my ($self, $rule) = @_;
    carp 'localize_rule is not supported';
    #TODO: probably won't do
}

# sub apply_rule {
#     my ($self, $rule, $el) = @_;
# }

# TODO: not sure if this will be needed/wanted, but
# sub trickle_atts {
#
# }

# find and save all its:*Rule's elements to be applied in
# $twig, in order of application
# $base is the base URI to resolve relative ones
# $name is a name for the input to use in errors
# (like filename or 'string')
sub _resolve_rules {
    my ($twig, $base, $name) = @_;
    # TODO: deal with its:param elements
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