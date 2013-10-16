#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::HTMLRuleExtractor;
use strict;
use warnings;
our $VERSION = '0.01'; # VERSION
# ABSTRACT: Extract ITS rules from an HTML document
use Carp;
our @CARP_NOT = qw(ITS);
use Path::Tiny;
use Try::Tiny;
use ITS::RuleContainer;
use ITS::Rule;
use ITS::XMLRuleExtractor;
use parent -norequire, qw(ITS);
my $ITS_NS = 'http://www.w3.org/2005/11/its';
# Find and save all its:rules elements containing rules to be applied in
# the given document, in order of application, including both those contained
# in script elements and external ones.
# %params are all of the parameters already defined for this document.
sub _resolve_doc_containers {
    # note that we don't pass around hash pointers for the params so that
    # all parameters are correctly scoped for each document or its:rules element.
    my ($doc, %params) = @_;

    # first, grab internal rules links to more rules
    my @scripts_links = _get_its_scripts_links($doc);
    if(@scripts_links == 0){
        return [];
    }

    # then store individual rules in application order (external first)
    my @containers;
    for my $script_link (@scripts_links){
        if($script_link->name eq 'script'){
            my $container = _parse_container(
                    $script_link,
                    %params
                );
            #script_link might have been a standoff markup, in which
            #case container will be null
            push @containers, $container
                if($container);
        }else{
            my $path = path($script_link->att('href'))->
                absolute($doc->get_base_uri);
            my $containers =
                ITS::XMLRuleExtractor::_get_external_containers(
                    $path, {});
            push @containers, @{$containers};
        }
    }

    if(@containers == 0){
        carp 'no rules found in ' . $doc->get_source;
    }
    return \@containers;
}

sub _get_its_scripts_links {
    my ($doc) = @_;
    return $doc->get_root->get_xpath(
        q<//h:script[@type="application/its+xml"] | > .
        q</h:html/h:head/h:link[@rel="its-rules"]>,
        namespaces => {
            h => 'http://www.w3.org/1999/xhtml'
        }
    );
}

# parse a single <script> element marked as ITS
# if the script contains an <its:rules> element, create a
# RuleContainer object. Otherwise, return undef.
sub _parse_container {
    my ($script, %params) = @_;

    # the script contains an its:rules element as text
    my $container = ITS::DOM->new('xml' => \($script->text))->
        get_root;

    # return undef if the contained text is not an <its:rules>
    # element (perhaps it is standoff markup)
    if($container->namespace_URI ne $ITS_NS ||
        $container->local_name ne 'rules'){
        return;
    }

    #TODO: children may be its-foreign-elements
    my $children = $container->child_els();
    while(  @$children and
            $children->[0]->local_name eq 'param' and
            $children->[0]->namespace_URI eq ITS::its_ns()
    ){
        my $param = shift @$children;
        $params{$param->att('name')} = $param->text;
    }
    #external containers are not allowed here, so just parse this one
    return ITS::RuleContainer->new(
        $container,
        version => $script->att('version'),
        query_language =>
            $script->att('queryLanguage') || 'xpath',
        params => \%params,
        rules => $children,
        script => $script,
    );
}

1;

__END__

=pod

=head1 NAME

ITS::HTMLRuleExtractor - Extract ITS rules from an HTML document

=head1 VERSION

version 0.01

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
