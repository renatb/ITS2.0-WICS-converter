package XML::ITS::HTML;
use strict;
use warnings;
# VERSION
# ABSTRACT: Extract ITS rules from an HTML document
use Carp;
our @CARP_NOT = qw(XML::ITS);
use Path::Tiny;
use Try::Tiny;
use XML::ITS::RuleContainer;
use XML::ITS::Rule;
use XML::ITS::XML;
use parent -norequire, qw(XML::ITS);

# Find and save all its:rules elements containing rules to be applied in
# the given document, in order of application, including external ones.
# %params are all of the parameters already defined for this document.
sub _resolve_doc_containers {
    # note that we don't pass around hash pointers for the params so that
    # all parameters are correctly scoped for each document or its:rules element.
    my ($self, $doc, %params) = @_;

    # first, grab internal rules links to more rules
    my @scripts_links = _get_its_scripts_links($doc);
    if(@scripts_links == 0){
        warn "returning nothing!";
        return [];
    }

    # then store individual rules in application order (external first)
    my @containers;
    for my $script_link (@scripts_links){
        if($script_link->name eq 'script'){
            push @containers, $self->_parse_container(
                    $script_link,
                    %params
                );
        }else{
            my $path = path( $script_link->att(
                'href', XML::ITS::xlink_ns() ) )->
                absolute($doc->get_base_uri);
            my $containers = $self->
                XML::ITS::XML::_get_external_containers($path, {});
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
        q<//h:script[@type="application/xml+its"] | > .
        q<//h:link[@rel="its-rules"]>,
        namespaces => {
            h => 'http://www.w3.org/1999/xhtml'
        }
    );
}

sub _parse_container {
    my ($self, $script, %params) = @_;

    # the script contains an its:rules element as text
    my $container = XML::ITS::DOM->new('xml' => \($script->text))->
        get_root;

    my $children = $container->child_els();
    if(@$children){
        while( $children->[0]->local_name eq 'param' and
            $children->[0]->namespace_URI eq XML::ITS::its_ns() ){
            my $param = shift @$children;
            $params{$param->att('name')} = $param->text;
        }
    }
    #external containers are not allowed here, so just parse this one
    return XML::ITS::RuleContainer->new(
            version => $script->att('version'),
            query_language =>
                $script->att('queryLanguage') || 'xpath',
            params => \%params,
            rules => $children,
        );
}

# sub _get_external_containers {
#     my ($self, $path, $params) = @_;
#     my $doc;

#     try {
#         $doc = XML::ITS::DOM->new('xml' => $path );
#     } catch {
#         carp "Skipping rules in file '$path': $_";
#         return [];
#     };
#     return $self->_resolve_doc_containers($doc, %$params);
# }

1;