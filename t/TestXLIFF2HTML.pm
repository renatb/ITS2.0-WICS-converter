#some test::base filters for HTML conversion
package t::TestXLIFF2HTML;
use Test::Base -base;

1;

package t::TestXLIFF2HTML::Filter;
use Test::Base::Filter -base;
use strict;
use warnings;
use Log::Any::Test;
use Log::Any qw($log);
use ITS::DOM;
use ITS::XLIFF2HTML;

#convert the input XML into html and return the html string
sub htmlize {
    my ($self, $xml) = @_;
    my $converter = ITS::XLIFF2HTML->new();
    my $converted = ${ $converter->convert(\$xml) };
    $converted = $self->normalize_html($converted);
    return $converted;
}

#convert the input XML into html, adding labels, and
#return the html string
sub htmlize_with_labels {
    my ($self, $xml) = @_;
    my $converter = ITS::XLIFF2HTML->new();
    my $converted = ${ $converter->convert(\$xml, 1) };
    $converted = $self->normalize_html($converted);
    return $converted;
}

#convert the input XML into html and return the html string and the log
sub html_log {
    my ($self, $xml) = @_;
    $log->clear();
    my $converter = ITS::XLIFF2HTML->new();
    my $converted = ${ $converter->convert(\$xml) };
    $converted = $self->normalize_html($converted);
    # print $converted;
    return ($converted, _get_messages($log->msgs()) );
}

#convert the input XML into html and return the html string and the log
#add labels where applicable
sub html_log_with_labels {
    my ($self, $xml) = @_;
    $log->clear();
    my $converter = ITS::XLIFF2HTML->new();
    my $converted = ${ $converter->convert(\$xml, 1) };
    $converted = $self->normalize_html($converted);
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

# given HTML string, remove spacing
# this makes comparing script elements easier
sub normalize_html {
     my ($self, $html) = @_;
     $html =~ s/\n\s*\n/\n/g;
     $html =~ s/  +/ /g;
     $html =~ s/^ //gm;
     return $html;
}