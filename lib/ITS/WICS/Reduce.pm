#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::Reduce;
use strict;
use warnings;
use ITS qw(its_ns);
use ITS::DOM::Element qw(new_element);
use Carp;
use Exporter::Easy (
	OK => [qw(reduce)]
);
use Log::Any qw($log);
our $VERSION = '0.04'; # VERSION
# ABSTRACT: Reduce and consolidate ITS-decorated HTML documents
my $indent = '  ';#two spaces

# reduce the input file if called as a script
do {
	my $ITS = ITS->new('html', doc => $ARGV[0]);
	reduce($ITS);
	print $ITS->get_doc->string;
} unless caller;


sub reduce {
	my ($ITS) = @_;
	if($ITS->get_doc_type ne 'html'){
		croak 'Can only process HTML documents';
	}

	my $doc = $ITS->get_doc;

	_strip_containers($ITS);

	my ($head) = $doc->get_root->get_xpath(
		'/h:html/h:head',
		namespaces => {h => 'http://www.w3.org/1999/xhtml'});

	# for each container, check for correct parameters and
	# paste it in a new script element
	for my $container (@{$ITS->get_containers}){
		my $el = $container->element;
		_log_rewrite($el);
		$el->remove;

		_rewrite_params($el, $container->params);

		# place the container in a script in the head
		$head->append_text("\n" . $indent x 2);
		my $id = $el->att('xml:id');
		my $script = new_element(
			'script', {
				type => 'application/its+xml',
				$id ? (id => $id) : ()
			}
		);
		$script->set_namespace('http://www.w3.org/1999/xhtml');
		$script->append_text("\n" . $indent x 3);
		$el->paste($script);
		$script->append_text("\n" . $indent x 2);
		$script->paste($head, 'last_child');
	}

	return;
}

# remove internal rules scripts and links to external ones;
# these can then be retrieved and repasted from RulesContainer objects
sub _strip_containers {
	my ($ITS) = @_;
	my @links = $ITS->get_doc->get_root->get_xpath(
		'/h:html/h:head/h:link[@rel="its-rules"]',
		namespaces => {h => 'http://www.w3.org/1999/xhtml'});
	for my $link (@links){
		$link->remove;
		_log_link_removal($link);
	}
	#remove the script elements containing the rules text
	for my $container (@{ $ITS->get_containers }){
		my $script = $container->script;
		$script->remove if $script;
	}
	return;
}

#log the fact that a container is being rewritten in the <head> element
sub _log_rewrite {
	my ($el) = @_;
	my $id;
	if($id = $el->att('xml:id') || $el->att('id') || ''){
		$id = " ($id)";
	}
	$log->debug("Rewriting rules container$id in <head>");
	return;
}

# remove all parameter elements and write new ones. A container
# may have more parameters than it has param elements;
# a container can be referenced via xlink:href, in which
# case it inherits params from the referencing container.
sub _rewrite_params {
	my ($el, $params) = @_;

	# rather than searching for which params already have elements,
	# just remove and rewrite all of them
	my @old_params = $el->get_xpath('its:param',
		namespaces => {its => its_ns()});
	$_->remove for @old_params;

	while (my ($name, $value) = each %$params){
		my $param_el = new_element(
			'its:param', {name => $name}, $value);
		$param_el->paste($el, 'first_child');
		$param_el->append_text("\n" . $indent x 4, 'before');
	}
	#keep it neat for following rules
	if(keys %$params){
		$el->append_text("\n" . $indent x 4, 'before');
	}
	return;
}

sub _log_link_removal {
	my ($link) = @_;
	my $href = $link->att('href');
	$href = " to $href" if $href;
	$log->debug("removing link$href");
	return;
}

1;

__END__

=pod

=head1 NAME

ITS::WICS::Reduce - Reduce and consolidate ITS-decorated HTML documents

=head1 VERSION

version 0.04

=head1 SYNOPSIS

	use ITS::WICS::Reduce qw(reduce);
	my $ITS = ITS->new('html', doc => '/path/to/html');
	reduce($ITS);
	print $ITS->get_doc->string;

=head1 DESCRIPTION

This module is for making single-file ITS documents. Currently
it only works with HTML. C<reduce>, its only method, simply follows links
to external rules files and places each of them, in order, into the main
document.

=head1 EXPORTS

The following method may be exported:

=head2 C<reduce>

Given an XML::ITS object (currently HTML only), this reduces the document
to one file by checking for external rules and pasting them in the
C<head> element. The rules are pasted in application order, and have ITS
correct parameters in the corresponding container. In the future, this
method may also remove ITS markup found incompatible with HTML5, but
there currently is none.

This method removes all original rule-containing elements, which are
accessible via L<ITS/get_containers>, from their owning documents.

=head1 TODO

Someday this script may support the reduction of ITS-decorated XML
and its external rules into one file.

=head1 SEE ALSO

This module relies on the L<ITS> module for processing ITS markup and rules.

The ITS 2.0 specification for XML and HTML5: L<http://www.w3.org/TR/its20/>.

The spec for representing ITS in XLIFF:
L<http://www.w3.org/International/its/wiki/XLIFF_1.2_Mapping>.

ITS interest group mail archives:
L<http://lists.w3.org/Archives/Public/public-i18n-its-ig/>

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
