package ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use Carp;
our @CARP_NOT = qw(ITS::DOM ITS);
use Try::Tiny;
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
    if($args{xml}){
        $dom = _get_xml_dom($args{xml});
    }elsif($args{html}){
        croak 'HTML parsing not supported yet';
    }
    return bless {dom => $dom}, $class;
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
