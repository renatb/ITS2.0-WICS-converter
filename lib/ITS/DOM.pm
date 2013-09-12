package ITS::DOM;
use strict;
use warnings;
# VERSION
# ABSTRACT: Work with XML and HTML documents
use ITS::DOM::Element;
use Carp;
our @CARP_NOT = qw(ITS Try::Tiny);
use Try::Tiny;
use Path::Tiny;
# the XML and HTML engines currently used
use XML::LibXML;
# returns an XML::LibXML document, unifying the APIs
use HTML::HTML5::Parser;
use HTML::HTML5::Writer;
my $writer = HTML::HTML5::Writer->new();
use Encode qw(decode);

=head1 SYNOPSIS

    use ITS::DOM;
    my $dom = ITS::DOM->new(xml => 'path/to/file');
    my @nodes = $dom->get_xpath('//@foo');

=head1 DESCRIPTION

This module is meant for internal use by the ITS::* modules only.
It abstracts away XML/HTML processing to quarantine 3rd party code.

=head1 METHODS

=head2 C<new>

The first argument should be named either 'xml' or
'html', and the value should either be a string filepath, a string pointer
containing the actual data to be parsed, or a filehandle for
a file containing the data.

For HTML documents, an optional 'namespace' argument can be set to false
to prevent setting the default namespace to C<http://www.w3.org/1999/xhtml>.

Parses the input document, creating a queryable DOM structure.

=cut
sub new {
    my ($class, $type, $source, %args) = @_;

    my $dom = _get_dom($type, $source, %args);

    my $base;
    if(ref $source eq 'SCALAR'){
        $base = path(q{.});
    }else{
        $base = path($source)->parent;
    }
    my $identifier = (ref $source eq 'SCALAR') ? 'STRING' : $source;

    my $self = bless {
        dom => $dom,
        base => $base,
        source => $identifier,
        type => $type,
        #a running counter for creating unique IDs
        id => 0
    }, $class;

    # HTML::HTML5::Parser always sets namespace. If user doesn't want that,
    # then strip it from all of the elements.
    if($type eq 'html'
        && exists $args{namespace}
        && !$args{namespace}){
        $_->strip_ns for $self->get_root->get_xpath('//*');
    }
    return $self;
}

=head2 C<get_root>

Returns the root document element, or undef if there is none (this
node is not associated with a document).

=cut
sub get_root {
    my ($self) = @_;
    my $root = $self->{dom}->documentElement;
    if($root){
        return ITS::DOM::Element->new($root);
    }
    return;
}

=head2 C<string>

Returns a stringified version of the entire document.
HTML documents are given an HTML5 doctype.

The returned string is always a UTF-8 character string.

=cut
sub string {
    my ($self) = @_;
    if($self->{type} eq 'xml'){
        # 1 is for adding whitespace to prettify
        my $string = $self->{dom}->toString(1);
        return decode('utf-8', $string);
    }else{
        return $writer->document($self->{dom})
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

=head2 C<get_type>

Returns either 'xml' or 'html', depending on the type of this
document.

=cut
sub get_type {
    my ($self) = @_;
    return $self->{type};
}

# type is 'xml' or 'html'
# data is filename, pointer to string content, or file glob
# returns an XML::LibXML::Document object
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
            _carp_parse_errors($parser);
        }
    }
    elsif(ref $data eq 'GLOB'){
        #$data is a filehandle
        if($type eq 'xml'){
            try{
                $dom = $parser->load_xml( IO => $data );
            } catch {
                croak "error parsing file '$data': $_";
            };
        }else{
            $dom = $parser->parse_fh( $data );
            _carp_parse_errors($parser);
        }
    }else{
        #strings are file names
        if($type eq 'xml'){
            try{
                $dom = $parser->load_xml( location => $data );
            } catch {
                croak "error parsing file '$data': $_";
            };
        }else{
            $dom = $parser->parse_html_file( $data );
            _carp_parse_errors($parser);
        }
    }
    $dom->setEncoding('utf-8');
    return $dom;
}

sub _carp_parse_errors {
    my ($parser) = @_;
    if(my @err = $parser->errors){
        @err = grep {
            defined $_->level and
            $_->level ne 'INFO'} @err;
        carp @err if @err;
    }
    return;
}


=head2 C<next_id>

Returns a unique number each time it is called with a given
DOM instance. This can be used to created unique id values.

=cut
sub next_id {
    my ($self) = @_;
    return ++$self->{id};
}
1;
