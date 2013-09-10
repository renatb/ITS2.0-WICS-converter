#basic test file

use strict;
use warnings;
use Test::More;
plan tests => 0;
use ITS::WICS;
use FindBin qw($Bin);
use Path::Tiny;

my $corpus_dir = path($Bin, 'corpus');
my $wics = ITS::WICS->new();