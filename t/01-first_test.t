#basic test file

use strict;
use warnings;
use Test::More;
use ITS::WICS;
use FindBin qw($Bin);
use Path::Tiny;

my $corpus_dir = path($Bin,'corpus');
my $first_test = path($corpus_dir, 'withintext1xml.xml');

plan tests => 1;
my $twig = ITS::WICS::xml2html(file => $first_test);
$twig->print;