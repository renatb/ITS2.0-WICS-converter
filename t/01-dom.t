# Test DOM parsing and other methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 19;
use XML::ITS::DOM;
use Test::Exception;
use Test::NoWarnings;
use utf8;

use Path::Tiny;
use FindBin qw($Bin);
my $corpus_dir = path($Bin, 'corpus');

my $dom_path = path($corpus_dir, 'dom_test.xml');
my $html_dom_path = path($corpus_dir, 'basic_html5.html');
test_errors($dom_path, $html_dom_path);

my $dom = XML::ITS::DOM->new( 'xml' => $dom_path );

test_dom_props($dom, $dom_path);
test_next_id($dom);
test_string($dom);
test_html_options();

# make sure that errors are thrown for bad input
# and that none are thrown for good input.
# The '.*01-dom.t' part of the regexes make sure
# the error location reported is for this file
# (not the library file)
sub test_errors {
    my ($dom_path, $html_dom_path) = @_;

    dies_ok {
        XML::ITS::DOM->new(
            'xml' => path($corpus_dir, 'nonexistent.xml')
        )
    },  'dies for nonexistent file';
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

    lives_ok{
        open my $fh, '<:encoding(UTF-8)', $dom_path
            or die $_;
        $dom = XML::ITS::DOM->new(
            'xml' => $fh
        )
    } 'valid XML file handle parses without error';

    lives_ok{
        $dom = XML::ITS::DOM->new(
            'xml' => $dom_path,
        )
    } 'valid XML file parses without error' or
        BAIL_OUT "can't test with basic XML file";

    # use a script with XML in it to make sure
    # HTML5 is ok. See http://mathiasbynens.be/notes/etago
    my $test_html = <<END_HTML;
<!DOCTYPE html>
<html>
    <head>
        <title>WICS</title>
        <script type='application/xml'>
            <xml>some stuff</xml>
        </script>
    </head>
<body></body>
</html>
END_HTML

    lives_ok{
        XML::ITS::DOM->new(
            'html' => \$test_html)
    } 'valid HTML5 parses without error';

    lives_ok{
        open my $fh, '<:encoding(UTF-8)', $html_dom_path
            or die $_;
        XML::ITS::DOM->new(
            'html' => $fh)
    } 'valid HTML5 file parses without error';

    lives_ok{
        XML::ITS::DOM->new(
            'html' => $html_dom_path)
    } 'valid HTML5 file parses without error';
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

#test that the next_id method returns unique values in order
sub test_next_id {
    my ($dom) = @_;
    is($dom->next_id, 1, 'first ID is 1');
    is($dom->next_id, 2, 'second ID is 2');
}

#test to_string method output
sub test_string {
    my ($dom) = @_;
    my $string = $dom->string;
    ok($string =~ m/ encoding="utf-8"\?/,
        'declared encoding is utf-8');
    # use re 'debug';

    ok($string =~ m/日本語 한국어 Tiếng Việt/,
        'characters are not converted to NCRs')
        or note $string;
}

#there's only one option to test: namespace => 0
sub test_html_options {
    my $html = XML::ITS::DOM->new('html' => \"<!DOCTYPE html><html>");
    is(
        $html->get_root->namespace_URI,
        'http://www.w3.org/1999/xhtml',
        'HTML doc has namespace by default');

    $html = XML::ITS::DOM->new(
        'html' => \"<!DOCTYPE html><html>",
        namespace => 1);
    is(
        $html->get_root->namespace_URI,
        'http://www.w3.org/1999/xhtml',
        'HTML doc has namespace when specified');

    $html = XML::ITS::DOM->new(
        'html' => \"<!DOCTYPE html><html>",
        namespace => 0);
    is(
        $html->get_root->get_xpath('//namespace::*'),
        0,
        'HTML doc has no namespace when specified');
}