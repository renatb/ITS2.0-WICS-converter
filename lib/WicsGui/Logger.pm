#small logging class to forward Log::Any logs to Wx logging
package WicsGui::Logger;
use strict;
use warnings;
#VERSION
use base qw(Log::Any::Adapter::Base);
use Log::Any::Adapter::Util qw(make_method);
use Wx;

# Create logging methods: debug, info, etc.
foreach my $method ( Log::Any->logging_methods() ) {
    # TODO: would rather use WX::Log::GetActiveTarget()->DoLogString,
    # but this causes errors.
    make_method($method, sub { Wx::LogMessage($_[1], undef) });
}

# Create detection methods: is_debug, is_info, etc.
foreach my $method ( Log::Any->detection_methods() ) {
    make_method($method, sub { 1 });
}

1;