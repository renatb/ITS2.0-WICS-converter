package ITS::WICS;
use strict;
use warnings;
use autodie;
use Carp;
use ITS::WICS::XML2HTML;
use Exporter::Easy (
	OK => ['xml2html']
);
# VERSION


# ABSTRACT: Convert ITS-decorated XML into HTML
=head1 SYNOPSIS

	my $obj = ITS::WICS->new();
	$obj->message();

=head1 DESCRIPTION

This module allows one to convert various forms of ITS-decorated XML into HTML with equivalent ITS markup.

=cut

# __PACKAGE__->new->_run unless caller;

# sub _run {
# 	my ($application) = @_;
# 	print { $application->{output_fh} }
# 		$application->message;
# }

=head1 METHODS

=head2 C<xml2html>

Takes a named argument; if C<file>, the value should be the name of an XML file with ITS markup.
If C<string>), the value should be a pointer to a string containing XML with ITS markup.

Returns an XML::Twig::Elt object containing the root of the converted HTML.

=cut

sub xml2html {
	my $twig = ITS::WICS::XML2HTML::convert(@_);
	my $html = "<!DOCTYPE html>\n";
	$html .= $twig->sprint;
	return $html;
}

1;

