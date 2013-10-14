#!perl
#
# This file is part of ITS
#
# This software is copyright (c) 2013 by DFKI.  No
# license is granted to other entities.
#

use Test::More;
eval 'use Test::CPAN::Meta::JSON';
plan skip_all => 'Test::CPAN::Meta::JSON required for testing META.json' if $@;
meta_json_ok();
