#basic test file

use strict;
use warnings;
use Test::More;
plan tests => 0;
use ITS::XML2XLIFF;
use FindBin qw($Bin);
use Path::Tiny;

my $corpus_dir = path($Bin, 'corpus');
my $xml2xliff = ITS::XML2XLIFF->new();