# Test matching elements globally
use strict;
use warnings;
use Test::More 0.88;
plan tests => 1;
use Test::Exception;
use XML::ITS::WICS::XML2HTML;
use Path::Tiny;
use FindBin qw($Bin);

my $file = path($Bin, 'corpus', 'external_rules_XML3.xml');

throws_ok {
    my $converter = XML::ITS::WICS::XML2HTML->new();
    return $converter->convert($file);
} qr/cannot process a file containing only rules.*08-rules_only_file\.t/is,
    'dies with warning for trying to process rules-only file';
