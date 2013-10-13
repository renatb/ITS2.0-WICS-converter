package ITS::XML2XLIFF::ITSSegmenter;
use strict;
use warnings;
use Log::Any qw($log);
use ITS qw(its_ns);
use ITS::XML2XLIFF::ITSProcessor qw(
    its_requires_inline
    convert_atts
    localize_rules
    transfer_inline_its
);
use ITS::DOM::Element qw(new_element);
use Exporter::Easy (OK => ['extract_convert_its']);
use ITS::XML2XLIFF::LogUtils qw(node_log_id);

#TODO: put all of these in one place
our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';

# VERSION
# ABSTRACT: Extract translation-units using ITS segmentation (internal use only)


# Extract translation units from the given element, placing them in
# the given new parent element. If newParent is undef, a new translation
# unit is created. This extraction method uses ITS to determine segmentation.
sub extract_convert_its {
    my ($self, $el, $new_parent) = @_;

    #check if element should be source or mrk inside of source
    my $place_inline;
    #no need to place inline if it already is inline
    if($new_parent && $new_parent->name eq 'mrk'){
        $place_inline = 0;
    }else{
        $place_inline = its_requires_inline(
            $el, $self->{match_index}->{$el->unique_key});
    }

    for my $child ($el->children){
        # extract non-empty text nodes
        if($child->type eq 'TXT' && $child->text =~ /\S/){
            # create a new source element if needed
            $new_parent ||= $self->_get_new_source($el);
            $child->paste($new_parent);
        }elsif($child->type eq 'ELT'){
            #ITS standoff and rules need special processing
            if($child->namespace_URI &&
                ($child->namespace_URI eq its_ns() ) &&
                $child->local_name !~ 'span'){
                #ignore its:rules and save standoff for later pasting
                if($child->local_name ne 'rules'){
                    # save standoff markup for pasting in the head
                    push @{ $self->{its_els} }, $child;
                    if($log->is_debug){
                        $log->debug('placing ' . node_log_id($child) .
                            ' (standoff markup) as-is in XLIFF document');
                    }
                }
                next;
            }

            #TODO: check if it's translatable
            #TODO: check withinText global rules
            my $within_text = $child->att('withinText', its_ns()) || '';
            #remove the no-longer-needed attribute before copying the element
            if($within_text){
                $child->remove_att('withinText', its_ns());
            }
            if( $within_text eq 'yes'){
                # create a new source element if needed
                $new_parent ||= $self->_get_new_source($el);
                extract_convert_its($self, $child,
                    $self->_get_new_mrk($child, $new_parent));
            }elsif($within_text eq 'nested'){
                # create a new source element if needed
                $new_parent ||= $self->_get_new_source($el);
                #one space to separate text on either side of nested element
                $new_parent->append_text(' ');
                # recursively extract
                extract_convert_its($self, $child);
            }else{
                # break the text flow
                $new_parent = undef;
                # recursively extract
                extract_convert_its($self, $child);
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
