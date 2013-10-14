#!perl
#
# This file is part of ITS
#
# This software is copyright (c) 2013 by DFKI.  No
# license is granted to other entities.
#

use Test::More;

eval "use Test::Vars";
plan skip_all => "Test::Vars required for testing unused vars"
  if $@;
all_vars_ok();
