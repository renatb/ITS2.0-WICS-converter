#test correct operation of the FutureNode class
use strict;
use warnings;
use XML::ITS::DOM;
use Test::More 0.88;
plan tests => 1;
use_ok('XML::ITS::WICS::XML2HTML::FutureNode');


__DATA__
=== ELT
--- doc
<xml/>
--- future
/*
--- new_path