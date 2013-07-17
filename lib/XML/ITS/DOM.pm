package XML::ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use XML::ITS::DOM::Node;
use XML::ITS::DOM::Value;
use Carp;
our @CARP_NOT = qw(ITS::DOM ITS);
use Try::Tiny;
use Path::Tiny;
#the XML engine currently used
use XML::LibXML;

=head1 SYNOPSIS

    use XML::ITS::DOM;
    use feature 'say';
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
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
        # $source = $args{html};
        croak 'HTML parsing not supported yet';
    }

    my $base;
    if(ref $source eq 'SCALAR'){
        $base = path('.');
    }else{
        $base = path($source)->parent;
    }
    my $identifier = (ref $source eq 'SCALAR') ? 'STRING' : $source;

    return bless {dom => $dom, base => $base, source => $identifier}, $class;
}

=head2 C<get_root>

Returns the root document element.

=cut
sub get_root {
    my ($self) = @_;
    return XML::ITS::DOM::Node->new($self->{dom}->documentElement);
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

=head2 C<get_source>

Returns the path of the file used to create this document. If the
data used to create this document was a string, then this returns
'STRING'.

=cut
sub get_source {
    my ($self) = @_;
    return $self->{source};
}

sub _get_xml_dom {
    my ($xml) = @_;

    my $parser = XML::LibXML->new();
    my $dom;
    if(ref $xml eq 'SCALAR'){
        #string refs are xml content;
        try{
            $dom = $parser->load_xml( string => $xml );
        } catch {
            croak "error parsing string: $_";
        };
    }
    else{
        #strings are file names
        try{
            $dom = $parser->load_xml( location => $xml );
        } catch {
            croak "error parsing file '$xml': $_";
        };
    }
    return $dom;
}

1;
