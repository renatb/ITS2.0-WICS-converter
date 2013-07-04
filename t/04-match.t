# check that rule matches are found and iterated properly
use strict;
use warnings;
use ITS;
use Test::More 0.88;
plan tests => 1;
use Data::Section::Simple qw(get_data_section);

my $all_data = get_data_section;

ok(1);
my $ITS = ITS->new( string => \($all_data->{document}) );
my $rules = ITS->new( string => \($all_data->{basic_rule}) )->get_rules;

my $match = $ITS->get_match($rules->[0]);

__DATA__
@@ document
<?xml version="1.0"?>
<myDoc id="myDocId">
    <body id="bodyId">
    <par id="parId" title="Text">
        The <trmark id="trmarkId">World Wide Web Consortium</trmark>
        is making the World Wide Web worldwide!
    </par>
    </body>
</myDoc>

@@ basic_rule
<its:rules xml:id='ext1container'
    xmlns:its="http://www.w3.org/2005/11/its"
    version="2.0">
        <its:translateRule
            xml:id="ext_rule"
            selector="//*[@baz=$baz]"
            translate="yes"/>
</its:rules>
