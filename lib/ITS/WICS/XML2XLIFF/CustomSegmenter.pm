#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::XML2XLIFF::CustomSegmenter;
use strict;
use warnings;
use Log::Any qw($log);
use ITS qw(its_ns);
use ITS::WICS::XML2XLIFF::ITSProcessor qw(
    its_requires_inline
    convert_atts
    localize_rules
    transfer_inline_its
    has_localizable_inline
);
use ITS::DOM::Element qw(new_element);
use Exporter::Easy (OK => ['extract_convert_custom']);
use ITS::WICS::LogUtils qw(node_log_id);

#TODO: put all of these in one place
our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';

our $VERSION = '0.03'; # VERSION
# ABSTRACT: Extract trans-units using custom segmentation (internal use only)


sub extract_convert_custom {
    my ($root, $group_els, $tu_els, $match_index) = @_;

    my $state = {
        match_index => $match_index,
        group_els => $group_els,
        tu_els => $tu_els,
        #holds all groups created so far
        groups => [],
        #holds all discovered standoff markup
        its_els => [],
        #holds the group currently being created, i.e. where new
        #trans-units should be pasted
        current_group => undef,
    };

    if(@{$group_els}){
        _extract_convert_groups($state, $root);
    }else{
        $state->{current_group} = new_element('group');
        $state->{current_group}->set_namespace($XLIFF_NS);
        _extract_convert_units($state, $root);
        #if the current group has trans-units, assign an id and save it
        if(@{$state->{current_group}->child_els}){
            $state->{current_group}->set_att('id', ++$state->{group_num});
            push $state->{groups}, $state->{current_group};
        }
    }

    return ($state->{groups}, $state->{its_els});
}

#extract groups and translation units according to elements specified as
#group or trans-unit containers
sub _extract_convert_groups {
    my ($state, $el) = @_;
    return if _check_standoff($state, $el);

    my $name = $el->local_name;
    # if this element is a group separator,
    # then make a group out of the TUs it contains
    if(grep {$_ eq $name} @{ $state->{group_els} }){
        $state->{current_group} = new_element('group');
        $state->{current_group}->set_namespace($XLIFF_NS);
        _extract_convert_units($state, $el);
        #if the current group has trans-units, assign an id and save it
        if(@{$state->{current_group}->child_els}){
            $state->{current_group}->set_att('id', ++$state->{group_num});
            push @{$state->{groups}}, $state->{current_group};
        }
    #otherwise, search for groups in its children
    }else{
        for my $child (@{$el->child_els}){
            _extract_convert_groups($state, $child);
        }
    }
    return;
}

#return true if markup should be ignored (ITS standoff or rules)
sub _check_standoff {
    my ($state, $el) = @_;

    my $name = $el->local_name;
    #ignore ITS rules and save standoff;
    #let its:span through (could possibly be used for holding segments)
    if($el->namespace_URI eq its_ns()){
        if($name eq 'rules'){
            return 1;
        }elsif($name ne 'span'){
            if($log->is_debug){
                $log->debug('placing ' . node_log_id($el) .
                    ' (standoff markup) as-is in XLIFF document');
            }
            push @{$state->{its_els}}, $el;
            return 1;
        }
    }
    return 0;
}

# find and return TUs in current element
sub _extract_convert_units {
    my ($state, $el) = @_;
    return if _check_standoff($state, $el);

    my $name = $el->local_name;
    # if this element is contains a translation unit,
    # then make a trans-unit element out of it and its children
    if(grep {$_ eq $name} @{ $state->{tu_els} }){
        #don't extract empty elements
        if($el->text =~ /\S/){
            _extract_convert_tu($state, $el);
        }
    #otherwise, search for TUs in its children
    }else{
        for my $child (@{$el->child_els}){
            _extract_convert_units($state, $child);
        }
    }
    return;
}

#create and a single TU from $original, pasting it in the current group
sub _extract_convert_tu {
    my ($state, $original) = @_;

    if($log->is_debug){
        $log->debug('Creating new trans-unit with '
            . node_log_id($original) . ' as source');
    }

    #check if element should be source or mrk inside of source
    my $place_inline = its_requires_inline(
            $original, $state->{match_index}->{$original->unique_key});;

    #create new trans-unit to hold element contents
    my $tu = new_element('trans-unit', {});
    $tu->set_namespace($XLIFF_NS);

    #copy element as a new source
    my $source = $original->copy(0);
    $source->set_name('source');
    $source->set_namespace($XLIFF_NS);
    $source->paste($tu);

    #segmentation scheme determines withinText, so these should be removed
    $source->remove_att('withinText', its_ns());

    # attributes get added while localizing rules; so save the ones
    # that need to be processed by convert_atts first
    my @atts = $source->get_xpath('@*');
    if(exists $state->{match_index}->{$original->unique_key}){
        localize_rules(
            $source,
            $tu,
            $state->{match_index}->{$original->unique_key},
            \@atts
        );
    }

    if(@atts){
        convert_atts($source, \@atts, $tu);
    }

    # process children as inline elements
    # reset ID counter for <ph> elements
    $state->{phid} = 0;
    for my $child($original->children){
        if($child->type eq 'ELT'){
            _process_inline($state, $child, $tu)->paste($source);
        }else{
            $child->paste($source);
        }
    }

    #ITS may require wrapping children in mrk and moving markup
    if($place_inline){
        my $mrk = new_element('mrk');
        $mrk->set_namespace($XLIFF_NS);
        for my $child ($source->children){
            $child->paste($mrk);
        }
        $mrk->paste($source);
        transfer_inline_its($source, $mrk);
    }

    my $target = $source->copy(1);
    $target->set_name('target');
    $target->set_att('state', 'new');
    $target->paste($source, 'after');

    $tu->set_att('id', , ++$state->{tu_num});
    $tu->paste($state->{current_group});
    return;
}

#convert a child into an inline XLIFF element;
#return the element to be pasted in the XLIFF document
sub _process_inline {
    my ($state, $el, $tu) = @_;

    #segmentation scheme determines withinText, so these should be removed
    $el->remove_att('withinText', its_ns());

    # attributes get added while localizing rules; so save the ones
    # that need to be processed by convert_atts first
    my @atts = $el->get_xpath('@*');
    my $match_index = $state->{match_index}->{$el->unique_key};

    # TODO: If translatable, the element should be <bpt> and <ept>
    # and the children should be recursively processed. Otherwise,
    # <ph> and children rendered as text (as is always done now).
    my $ph = new_element('ph');
    $ph->set_namespace($XLIFF_NS);
    $ph->set_att('id', ++$state->{phid});

    # the element to be pasted in the XLIFF document will be either
    # <ph> or <mrk>
    my $return_el = $ph;
    #if there's any ITS, we need a mrk element
    if(has_localizable_inline(
        \@atts, $match_index)){

        #put atts on a wrapping <mrk> element
        my $mrk = new_element('mrk');
        $mrk->set_namespace($XLIFF_NS);

        if($match_index){
            localize_rules(
                $mrk,
                $tu,
                $match_index,
                \@atts
            );
        }
        if(@atts){
            convert_atts($mrk, \@atts);
        }

        # default value for required 'mtype' attribute is 'x-its',
        # indicating any kind of ITS usage
        if(!$mrk->att('mtype')){
            $mrk->set_att('mtype', 'x-its');
        }
        $ph->paste($mrk);
        $return_el = $mrk;
    }

    # TODO: if $el is translatable, then element and children should be
    # recursively processed instead of just being serialized and pasted
    $ph->append_text($el->to_string);
    $el->remove;

    return $return_el;
}

1;

__END__

=pod

=head1 NAME

ITS::WICS::XML2XLIFF::CustomSegmenter - Extract trans-units using custom segmentation (internal use only)

=head1 VERSION

version 0.03

=head2 C<extract_convert_custom>

This extracts groups of C<trans-unit> elements from the input document root
using a list of elements to be used for groups and another of those to be
used as trans-units. Any elements inside of an element extracted as a
C<trans-unit> will be an inline C<mrk> element.

Arguments are the document root, an array ref of the group elements,
an array ref of the trans-unit elements, and the match index. Returns
(as a list) an array ref of group elements and an array ref of
standoff elements.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
