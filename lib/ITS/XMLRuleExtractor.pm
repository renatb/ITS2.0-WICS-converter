#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::XMLRuleExtractor;
use strict;
use warnings;
our $VERSION = '0.01'; # VERSION
# ABSTRACT: Extract ITS rules from an XML document
use Carp;
our @CARP_NOT = qw(ITS);
use Path::Tiny;
use Try::Tiny;
use ITS::RuleContainer;
use ITS::Rule;
use parent -norequire, qw(ITS);
use Data::Dumper;

# Find and save all its:rules elements containing rules to be applied in
# the given document, in order of application, including external ones.
# %params are all of the parameters already defined for this document.
sub _resolve_doc_containers {
    # note that we don't pass around hash pointers for the params so that
    # all parameters are correctly scoped for each document or its:rules element.
    my ($doc, %params) = @_;

    # first, grab internal its:rules elements
    my @internal_rules_containers = _get_its_rules_els($doc);
    if(@internal_rules_containers == 0){
        return [];
    }

    # then store individual rules in application order (external first)
    my @containers;
    for my $container (@internal_rules_containers){

        my $containers =
            _resolve_containers(
                $doc,
                $container,
                %params
            );
        push @containers, @{$containers};
    }

    if(@containers == 0){
        carp 'no rules found in ' . $doc->get_source;
    }
    return \@containers;
}

sub _get_its_rules_els {
    my ($doc) = @_;
    return $doc->get_root->get_xpath(
        q<//*[namespace-uri()='> . ITS::its_ns() . q<'> .
            q{and local-name()='rules']},
    );
}

# given a single rule container, return it and all other
# rule containers included via external files
sub _resolve_containers {
    my ($doc, $container, %params) = @_;

    my $children = $container->child_els();

    #TODO: children may be its-foreign-elements
    while(  @$children and
            $children->[0]->local_name eq 'param' and
            $children->[0]->namespace_URI eq ITS::its_ns()
    ){
        my $param = shift @$children;
        $params{$param->att('name')} = $param->text;
    }
    my @containers;
    if($container->att( 'href', ITS::xlink_ns() )){
        #path to file is relative to current file
        my $path = path( $container->att( 'href', ITS::xlink_ns() ) )->
            absolute($doc->get_base_uri);
        push @containers, @{ _get_external_containers($path, \%params) };
    }
    push @containers, ITS::RuleContainer->new(
        $container,
        version => $container->att('version'),
        query_language =>
            $container->att('queryLanguage') || 'xpath',
        params => \%params,
        rules => $children,
    );
    return \@containers;
}

# return an arrayref containing all of the rule containers
# taken from a given file (each file has one container, but
# may reference other rules files).
sub _get_external_containers {
    my ($path, $params) = @_;
    my $doc;

    try {
        $doc = ITS::DOM->new('xml' => $path );
    } catch {
        carp "Skipping rules in file '$path': $_";
        return [];
    };
    return _resolve_doc_containers($doc, %$params);
}

1;

__END__

=pod

=head1 NAME

ITS::XMLRuleExtractor - Extract ITS rules from an XML document

=head1 VERSION

version 0.01

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
