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
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert($ITS) };
    return $converted;
}

#convert the input XML into xlf and return the xlf string;
#use custom segmentation rules indicated by arguments:
#group,group...|tu,tu...
sub xlfize_custom {
    my ($self, $xml) = @_;

    my $args = $self->current_arguments;
    my ($group, $tu) = split '\|', $args;
    $group = [split ',', $group];
    $tu = [split ',', $tu];

    my $converter = ITS::XML2XLIFF->new();
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert(
        $ITS, group => $group, tu => $tu) };
    return $converted;
}

#convert the input XML into XLIFF and return the html string and the log
sub xlf_log {
    my ($self, $xml) = @_;
    $log->clear();
    my $converter = ITS::XML2XLIFF->new();
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert($ITS) };
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
