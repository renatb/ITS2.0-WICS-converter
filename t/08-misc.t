# Test DOM parsing and other methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 5;
use ITS qw(its_ns xlink_ns);
use Test::NoWarnings;

is(its_ns(), 'http://www.w3.org/2005/11/its', 'correct namespace for ITS');
is(xlink_ns(), 'http://www.w3.org/1999/xlink', 'correct namespace for XLink');

my $ITS = ITS->new('xml', doc => \'<xml/>');
is($ITS->get_doc_type, 'xml', 'correct type returned for XML doc');

$ITS = ITS->new('html', doc => \'<!doctype HTML><html>');
is($ITS->get_doc_type, 'html', 'correct type returned for HTML doc');