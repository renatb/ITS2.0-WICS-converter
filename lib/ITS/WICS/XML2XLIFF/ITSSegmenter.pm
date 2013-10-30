#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::XML2XLIFF::ITSSegmenter;
use strict;
use warnings;
use Log::Any qw($log);
use ITS qw(its_ns);
use ITS::WICS::XML2XLIFF::ITSProcessor qw(
    its_requires_inline
    convert_atts
    localize_rules
    transfer_inline_its
);
use ITS::DOM::Element qw(new_element);
use Exporter::Easy (OK => ['extract_convert_its']);
use ITS::WICS::LogUtils qw(node_log_id);

#TODO: put all of these in one place
our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';

our $VERSION = '0.04'; # VERSION
# ABSTRACT: Extract translation-units using ITS segmentation (internal use only)

#TODO: place trans-units in a group?
sub extract_convert_its {
    my ($root, $match_index) = @_;
    my $state = {
        match_index => $match_index,
        #holds all trans-units created so far
        tu => [],
        #holds all discovered standoff markup
        its_els => [],
    };
    _extract_convert_its($state, $root);
    _copy_source_to_target($state->{tu});

    return ($state->{tu}, $state->{its_els});
}

#copy the source element in each TU and rename it target; add
#state="new" to each one.
sub _copy_source_to_target {
    my ($tus) = @_;
    for my $tu(@{ $tus }){
        my ($source) = @{ $tu->child_els('source') };
        my $target = $source->copy(1);
        $target->set_name('target');
        $target->set_att('state', 'new');
        $target->paste($tu);
    }
    $log->debug('Copying sources to targets');
    return;
}

# Extract translation units from the given element, placing them in
# the given new parent element. If newParent is undef, a new translation
# unit is created. This extraction method uses ITS to determine segmentation.
sub _extract_convert_its {
    my ($state, $el, $new_parent) = @_;

    #check if element should be source or mrk inside of source
    my $place_inline;
    #no need to place inline if it already is inline
    if($new_parent && $new_parent->name eq 'mrk'){
        $place_inline = 0;
    }else{
        $place_inline = its_requires_inline(
            $el, $state->{match_index}->{$el->unique_key});
    }

    for my $child ($el->children){
        # extract non-empty text nodes
        if($child->type eq 'TXT' && $child->text =~ /\S/){
            # create a new source element if needed
            $new_parent ||= _get_new_source($state, $el);
            $child->paste($new_parent);
        }elsif($child->type eq 'ELT'){
            #ITS standoff and rules need special processing
            next if _check_standoff($state, $child);

            #TODO: check if it's translatable
            #TODO: check withinText global rules
            my $within_text = $child->att('withinText', its_ns()) || '';
            #remove the no-longer-needed attribute before copying the element
            if($within_text){
                $child->remove_att('withinText', its_ns());
            }
            if( $within_text eq 'yes'){
                # create a new source element if needed
                $new_parent ||= _get_new_source($state, $el);
                _extract_convert_its($state, $child,
                    _get_new_mrk($state, $child, $new_parent));
            }elsif($within_text eq 'nested'){
                # create a new source element if needed
                $new_parent ||= _get_new_source($state, $el);
                #one space to separate text on either side of nested element
                $new_parent->append_text(' ');
                # recursively extract
                _extract_convert_its($state, $child);
            }else{
                # break the text flow
                $new_parent = undef;
                # recursively extract
                _extract_convert_its($state, $child);
            }
        }
    }

    #ITS may require wrapping children in mrk and moving some markup
    if($place_inline){
        my $mrk = new_element('mrk');
        $mrk->set_namespace($XLIFF_NS);
        for my $child ($new_parent->children){
            $child->paste($mrk);
        }
        $mrk->paste($new_parent);
        transfer_inline_its($new_parent, $mrk);
    }

    return;
}

# pass in the element which contains the text to be placed in a
# new source element. Create the source element and paste in
# inside a new trans-unit element.
sub _get_new_source {
    my ($state, $el) = @_;

    if($log->is_debug){
        $log->debug('Creating new trans-unit with ' . node_log_id($el) .
            ' as source');
    }
    #create new trans-unit to hold element contents
    my $tu = new_element('trans-unit', {});
    $tu->set_namespace($XLIFF_NS);
    push @{$state->{tu}}, $tu;

    #copy element and atts, but not children
    my $new_el = $el->copy(0);
    $new_el->set_name('source');
    $new_el->set_namespace($XLIFF_NS);
    $new_el->paste($tu);

    # attributes get added while localizing rules; so save the ones
    # that need to be processed by convert_atts first
    my @atts = $new_el->get_xpath('@*');
    if(exists $state->{match_index}->{$el->unique_key}){
        localize_rules(
            $new_el,
            $tu,
            $state->{match_index}->{$el->unique_key},
            \@atts
        );
    }
    if(@atts){
        convert_atts($new_el, \@atts, $tu);
    }

    return $new_el;
}

#create a new XLIFF mrk element to represent given element and paste
#is last in given parent
sub _get_new_mrk {
    my ($state, $el, $parent) = @_;

    if($log->is_debug){
        $log->debug('Creating inline <mrk> from ' . node_log_id($el));
    }
    #copy element and atts, but not children
    my $mrk = $el->copy(0);
    $mrk->set_name('mrk');
    $mrk->set_namespace($XLIFF_NS);
    $mrk->paste($parent);

    # attributes get added while localizing rules; so save the ones
    # that need to be processed by convert_atts first
    my @atts = $mrk->get_xpath('@*');
    if(exists $state->{match_index}->{$el->unique_key}){
        localize_rules(
            $mrk,
            $parent,
            $state->{match_index}->{$el->unique_key},
            \@atts
        );
    }
    if(@atts){
        convert_atts($mrk, \@atts);
    }

    #default value for required 'mtype' attribute is 'x-its',
    #indicating some kind of ITS usage
    if(!$mrk->att('mtype')){
        $mrk->set_att('mtype', 'x-its');
    }
    return $mrk;
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

1;

__END__

=pod

=head1 NAME

ITS::WICS::XML2XLIFF::ITSSegmenter - Extract translation-units using ITS segmentation (internal use only)

=head1 VERSION

version 0.04

=head1 EXPORTS

The following function may be exported:

=head2 C<extract_convert_its>

Arguments are the document root and the match index. Returns (as a list)
an array ref of trans-unit elements and an array ref of standoff elements.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
