package XML::ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use XML::ITS::DOM::Element;
use Carp;
our @CARP_NOT = qw(XML::ITS Try::Tiny);
# $Carp::Verbose++;
use Try::Tiny;
use Path::Tiny;
# the XML and HTML engines currently used
use XML::LibXML;
# returns an XML::LibXML document, unifying the APIs
use HTML::HTML5::Parser;

=head1 SYNOPSIS

    use XML::ITS::DOM;
    my $dom = XML::ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_xpath('//@foo');

=head1 DESCRIPTION

This module is meant for internal use by the XML::ITS::* modules only.
It abstracts away XML/HTML processing to quarantine 3rd party code.

=head1 METHODS

=head2 C<new>

Argument: a single named argument. The name should be either 'xml' or
'html', and the value is either a string filepath or a string pointer
containing the actual data to be parsed.

Parses the input document, creating a queryable DOM structure.

=cut
sub new {
    my ($class, @args) = @_;

    my $dom = _get_dom(@args);

    # either xml or html
    my $type = $args[0];
    # source of data
    my $source = $args[1];

    my $base;
    if(ref $source eq 'SCALAR'){
        $base = path('.');
    }else{
        $base = path($source)->parent;
    }
    my $identifier = (ref $source eq 'SCALAR') ? 'STRING' : $source;

    return bless {
        dom => $dom,
        base => $base,
        source => $identifier,
        type => $type
    }, $class;
}

=head2 C<get_root>

Returns the root document element.

=cut
sub get_root {
    my ($self) = @_;
    my $root = $self->{dom}->documentElement;
    if($root){
        return XML::ITS::DOM::Element->new($root);
    }
    return undef;
}

=head2 C<string>

Returns a stringified version of the entire document.
HTML documents are given an HTML5 doctype.

=cut
sub string {
    my ($self) = @_;
    if($self->{type} eq 'xml'){
        # 1 is for adding whitespace to prettify
        return $self->{dom}->toString(1);
    }else{
        return "<!DOCTYPE html>\n" . $self->{dom}->toStringHTML;
    }
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

#type is 'xml' or 'html'
#data is filename or pointer to string content
sub _get_dom {
    my ($type, $data) = @_;

    my $dom;
    if($type !~ /^(?:xml|html)$/){
        croak 'must specify either "xml" or "html"';
    }
    my $parser = $type eq 'xml' ?
        XML::LibXML->new() :
        HTML::HTML5::Parser->new;

    if(ref $data eq 'SCALAR'){
        #string refs are content;
        if($type eq 'xml'){
            try{
                $dom = $parser->load_xml( string => $data );
            } catch {
                croak "error parsing string: $_";
            };
        }else{
            $dom = $parser->parse_string( $$data );
            carp_parse_errors($parser);
        }
    }
    else{
        #strings are file names
        if($type eq 'xml'){
            try{
                $dom = $parser->load_xml( location => $data );
            } catch {
                croak "error parsing file '$data': $_";
            };
        }else{
            $dom = $parser->parse_html_file( $data );
            carp_parse_errors($parser);
        }
    }
    return $dom;
}

sub carp_parse_errors {
    my ($parser) = @_;
    if(my @err = $parser->errors){
        @err = grep {
            defined $_->level and
            $_->level ne 'INFO'} @err;
        carp @err if @err;
    }
}

1;
