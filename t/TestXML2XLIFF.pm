#some test::base filters for XLIFF conversion
package t::TestXML2XLIFF;
use Test::Base -base;

1;

package t::TestXML2XLIFF::Filter;
use Test::Base::Filter -base;
use strict;
use warnings;
use Log::Any::Test;
use Log::Any qw($log);
use ITS::DOM;
use ITS::XML2XLIFF;

#convert the input XML into xlf and return the xlf string
sub xlfize {
    my ($self, $xml) = @_;
    my $converter = ITS::XML2XLIFF->new();
    my $converted = ${ $converter->convert(\$xml) };
    # $converted = $self->normalize_xlf($converted);
    # print $converted;
    return $converted;
}

#convert the input XML into XLIFF and return the html string and the log
sub xlf_log {
    my ($self, $xml) = @_;
    $log->clear();
    my $converter = ITS::XML2XLIFF->new();
    my $converted = ${ $converter->convert(\$xml) };
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
