# Test DOM parsing and other methods
use strict;
use warnings;
use Test::More 0.88;
plan tests => 2;
use XML::ITS qw(its_ns);
use Test::NoWarnings;

is(its_ns(), 'http://www.w3.org/2005/11/its', 'correct namespace for ITS');
