#!perl
#
# This file is part of ITS
#
# This software is copyright (c) 2013 by DFKI.  No
# license is granted to other entities.
#

use Test::More;

eval "use Test::CPAN::Meta";
plan skip_all => "Test::CPAN::Meta required for testing META.yml" if $@;
meta_yaml_ok();
