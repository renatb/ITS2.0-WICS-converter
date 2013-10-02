#modified from "Effective Perl Programming" by Joseph N. Hall, et al.
package ITS::XML2XLIFF;
use strict;
use warnings;
use autodie;
# VERSION


# ABSTRACT: Default Module Template
=head1 SYNOPSIS

	use ITS::XML2XLIFF;
	my $obj = ITS::XML2XLIFF->new();
	$obj->message();

=head1 DESCRIPTION

Description here

=cut

__PACKAGE__->new->_run unless caller;

sub _run {
	my ($application) = @_;
	print { $application->{output_fh} }
		$application->message;
}

=head1 METHODS

=head2 C<new>

Creates a new instance of ITS::XML2XLIFF

=cut

sub new {
	my ($class) = @_;
	my $application = bless {}, $class;
	$application->_init;
	return $application;
}

sub _init {
	my ($application) = @_;
	$application->{output_fh} = \*STDOUT;
	$application->{input_fh} = \*STDIN;
	return;
}

=head2 C<output_fh>

Input: filehandle or filename

Sets the filehandle for this object to print to.

=cut

sub output_fh {
	my ( $application, $fh ) = @_;
	if ($fh) {
		if(ref($fh) eq 'GLOB'){
			$application->{output_fh} = $fh;
		}
		else{
			open my $fh2, '>', $fh;
			$application->{output_fh} = $fh2;
		}
	}
	return $application->{output_fh};
}

=head2 C<input_fh>

Input: filehandle or filename

Sets the filehandle for this object to read from.

=cut

sub input_fh {
	my ( $application, $fh ) = @_;
	if ($fh) {
		if(ref($fh) eq 'GLOB'){
			$application->{input_fh} = $fh;
		}
		else{
			open my $fh2, '<', $fh;
			$application->{input_fh} = $fh2;
		}
	}
	return $application->{input_fh};
}

=head2 C<other_subroutines>

PUT MORE SUBROUTINES HERE

=cut

sub other_subroutines {
	"YOUR WORK STARTS HERE\n";
}

1;

