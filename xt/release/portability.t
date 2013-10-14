#!perl
#
# This file is part of ITS
#
# This software is copyright (c) 2013 by DFKI.  No
# license is granted to other entities.
#

use Test::More;

eval 'use Test::Portability::Files';
plan skip_all => 'Test::Portability::Files required for testing portability'
    if $@;
run_tests();
