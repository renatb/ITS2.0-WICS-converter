#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
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
use ITS::WICS::XLIFF2HTML;

#convert the input XML into html and return the html string
sub htmlize {
    my ($self, $xml) = @_;
    my $converter = ITS::WICS::XLIFF2HTML->new();
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert($ITS) };
    $converted = $self->normalize_html($converted);
    return $converted;
}

#convert the input XML into html, adding labels, and
#return the html string
sub htmlize_with_labels {
    my ($self, $xml) = @_;
    my $converter = ITS::WICS::XLIFF2HTML->new();
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert($ITS, 1) };
    $converted = $self->normalize_html($converted);
    return $converted;
}

#convert the input XML into html and return the html string and the log
sub html_log {
    my ($self, $xml) = @_;
    $log->clear();

    my $converter = ITS::WICS::XLIFF2HTML->new();
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert($ITS) };
    $converted = $self->normalize_html($converted);
    # print $converted;
    return ($converted, _get_messages($log->msgs()) );
}

#convert the input XML into html and return the html string and the log
#add labels where applicable
sub html_log_with_labels {
    my ($self, $xml) = @_;
    $log->clear();

    my $converter = ITS::WICS::XLIFF2HTML->new();
    my $ITS = ITS->new('xml', doc => \$xml);
    my $converted = ${ $converter->convert($ITS, 1) };
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