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
use ITS::DOM;
use ITS::XML2HTML;

#convert the input XML into html and return the html string
sub htmlize {
    my ($self, $xml) = @_;
    $log->clear();
    my $wics = ITS::XML2HTML->new();
    my $converted = ${ $wics->convert(\$xml) };
    # print $converted;
    return ($converted, _get_messages($log->msgs()) );
}

sub _get_messages {
    my ($logs) = @_;
    my $messages = [];
    for(@$logs){
        push @$messages, $_->{message};
    }
    return $messages;
}