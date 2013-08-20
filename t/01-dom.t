# Test DOM parsing and other methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 11;
use XML::ITS::DOM;
use Test::Exception;
use Test::NoWarnings;

use Path::Tiny;
use FindBin qw($Bin);
my $corpus_dir = path($Bin, 'corpus');

my $dom_path = path($corpus_dir, 'dom_test.xml');
test_errors($dom_path);

my $dom = XML::ITS::DOM->new( 'xml' => $dom_path );

test_dom_props($dom, $dom_path);
test_counter($dom);


# make sure that errors are thrown for bad input
# and that none are thrown for good input.
# The '.*01-dom.t' part of the regexes make sure
# the error location reported is for this file
# (not the library file)
sub test_errors {
    my ($dom_path) = @_;

    throws_ok {
        XML::ITS::DOM->new(
            'xml' => path($corpus_dir, 'nonexistent.xml')
        )
    } qr/error parsing file.*No such file or directory.*01-dom.t/s,
        'dies for nonexistent file';
    throws_ok {
        XML::ITS::DOM->new(
            'xml' => \'<xml>stuff</xlm>'
        );
    } qr/error parsing string:.*mismatch.*01-dom.t/s,
        'dies for bad XML';

    lives_ok{
        XML::ITS::DOM->new(
            'xml' => \'<xml><first foo="bar"/></xml>'
        )
    } 'valid XML parses without error';

    # use a script with XML in it to make sure
    # HTML5 is ok. See http://mathiasbynens.be/notes/etago
    lives_ok{
        XML::ITS::DOM->new(
            'html' => \"
            <!DOCTYPE html>
            <html>
                <head>
                    <title>WICS</title>
                    <script type='application/xml'>
                        <xml>some stuff</xml>
                    </script>
                </head>
            <body></body>
            </html>")
    } 'valid HTML5 parses without error';

    lives_ok{
        $dom = XML::ITS::DOM->new(
            'xml' => $dom_path,
            'rules' => $dom_path
        )
    } 'valid XML file parses without error' or
        BAIL_OUT "can't test with basic XML file";
    return;
}

#test properties of entire document
sub test_dom_props {
    my ($dom, $dom_path) = @_;

    is($dom->get_base_uri, $dom_path->parent, 'Base URI');
    is($dom->get_source, $dom_path, 'Source name');
    is(ref $dom->get_root, 'XML::ITS::DOM::Element', 'retrieve root element');
    return;
}

sub test_counter {
    my ($dom) = @_;
    is($dom->next_id, 1, 'first ID is 1');
    is($dom->next_id, 2, 'second ID is 2');
}
