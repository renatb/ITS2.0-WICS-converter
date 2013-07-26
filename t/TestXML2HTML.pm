#some test::base filters for HTML conversion
package t::TestXML2HTML;
use Test::Base -base;

1;

package t::TestXML2HTML::Filter;
use Test::Base::Filter -base;
use strict;
use warnings;
use Log::Any::Test;
use Log::Any qw($log);
use XML::ITS::DOM;
use XML::ITS::WICS::XML2HTML;

#convert the input XML into html and return the html string
sub htmlize {
    my ($self, $xml) = @_;
    $log->clear();
    my $wics = XML::ITS::WICS::XML2HTML->new();
    my $converted = ${ $wics->convert(\$xml) };
    # print $converted;
    return ($converted, [@{$log->msgs()}]);
}

#turn input lines into a list of debug log entries as created by Log::Any::Test
sub debug_log_entries {
    my ($self, @lines) = @_;
    my @entries;
    for(@lines){
        push @entries, {
            category => 'XML::ITS::WICS::XML2HTML',
            message => $_,
            level => 'debug'
        };
    }
    return \@entries;
}