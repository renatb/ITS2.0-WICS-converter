#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::GuiLogger;
use strict;
use warnings;
# ABSTRACT: forward Log::Any logs to Wx loggers
our $VERSION = '0.03'; # VERSION
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

__END__

=pod

=head1 NAME

ITS::WICS::GuiLogger - forward Log::Any logs to Wx loggers

=head1 VERSION

version 0.03

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
