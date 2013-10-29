#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::XML2XLIFF::ITSProcessor;
use strict;
use warnings;

our $VERSION = '0.04'; # VERSION
# ABSTRACT: Process and convert XML and XLIFF ITS (internal use only).

use ITS qw(its_ns);
use ITS::DOM::Element qw(new_element);
use Exporter::Easy (
    OK => [qw(
        its_requires_inline
        convert_atts
        localize_rules
        transfer_inline_its
        has_localizable_inline
    )]);

#TODO: put all of these in one place
our $XLIFF_NS = 'urn:oasis:names:tc:xliff:document:1.2';
our $ITSXLF_NS = 'http://www.w3.org/ns/its-xliff/';

# TODO: how about returning null if none is required, and returning a <mrk> element
# when it is? That way we could copy the term info and remove it from the original
# element here. It would save logic elsewhere.
sub its_requires_inline {
    my ($el, $global) = @_;

    # any terminology information requires inlining
    if($el->att('term', its_ns())){
        return 1;
    }
    return 0 unless $global;
    if(exists $global->{term}){
        return 1;
    }
    return 0;
}


sub transfer_inline_its {
    my ($from, $to) = @_;

    #all of the terminology information has to be moved
    my $mtype = $from->att('mtype');
    if($mtype =~ /term/){
        $to->set_att('mtype', $from->att('mtype'));
        $from->remove_att('mtype');
        my @term_atts = qw(
            termInfo
            termInfoRef
            termConfidence
        );

        for my $att (@term_atts){
            if (my $value = $from->att($att, $ITSXLF_NS)){
                $from->remove_att($att, $ITSXLF_NS);
                $to->set_att("itsxlf:$att", $value, $ITSXLF_NS);
            }
        }
    }
    return;
}

sub has_localizable_inline {
    my ($atts, $index) = @_;
    if($index){
        for my $key (keys %$index){
            #everything except idValue generates local atts on <mrk>
            return 1 if ($key ne 'idValue');
        }
    }
    for my $att(@$atts){
        return 1 if($att->name ne 'xml:id');
    }
    return 0;
}

sub convert_atts {
    my ($el, $atts, $tu) = @_;

    my %atts;
    for (@$atts){
        $atts{'{' . $_->namespace_URI . '}' . $_->local_name} = $_
    }

    #TODO: there might be elements other than source and mrk someday
    my $inline = $el->local_name eq 'mrk' ? 1 : 0;

    for my $att (@$atts){
        # ignore if already removed while processing other atts
        next if !$att->parent;

        my $att_ns = $att->namespace_URI || '';
        my $att_name = $att->local_name;
        if($att_ns eq its_ns()){
            if($att_name eq 'version'){
                $att->remove;
            }
            # If there's a locNoteType but no locNote, then it
            # doesn't get processed (no reason to).
            if($att_name eq 'locNote'){
                my $type = 'description';
                if(my $typeNode = $atts{'{'.its_ns().'}'.'locNoteType'}){
                    $type = $typeNode->value;
                    $typeNode->remove;
                }
                _process_locNote($el, $att->value, $type, $tu, $inline);
                $att->remove;
            }elsif($att_name eq 'translate'){
                _process_translate($el, $att->value, $tu, $inline);
                $att->remove;
            # If there's a term* but no term, then it
            # doesn't get processed (no reason to).
            }elsif($att_name eq 'term'){
                my ($infoRef, $conf) = (undef, undef);
                # default is undef
                if(my $infoRefNode = $atts{'{'.its_ns().'}'.'termInfoRef'}){
                    $infoRef = $infoRefNode->value;
                    $infoRefNode->remove;
                }
                if(my $confNode = $atts{'{'.its_ns().'}'.'termConfidence'}){
                    $conf = $confNode->value;
                    $confNode->remove;
                }
                _process_term(
                    $el,
                    term => $att->value,
                    termInfoRef => $infoRef,
                    termConfidence => $conf,
                );
                $att->remove;
            }
        #default for ITS atts: leave them there
        }elsif($att->name eq 'xml:id'){
            _process_idValue($att->value, $tu, $inline);
            $att->remove;
        # just remove any other attributes for now
        }else{
            $att->remove;
        }
    }
    return;
}

sub localize_rules {
    my ($el, $tu, $its_info, $atts) = @_;

    my %atts;
    for (@$atts){
        $atts{'{' . $_->namespace_URI . '}' . $_->local_name} = $_
    }

    #TODO: there might be elements other than source and mrk someday
    my $inline = $el->local_name eq 'mrk' ? 1 : 0;

    #each of these is a check that 1) the category is selected in a global
    #rule and 2) there is no local selection. TODO: clean this up?
    while (my ($name, $value) = each %$its_info){
        if($name eq 'locNote' &&
                # its:locNote
                !exists $atts{'{'.its_ns().'}'.'locNote'}){
            my $type = $its_info->{locNoteType} || 'description';
            _process_locNote($el, $value, $type, $tu, $inline)
        }elsif($name eq 'translate' &&
                # its:translate
                !exists $atts{'{'.its_ns().'}'.'translate'}){
            _process_translate($el, $value, $tu, $inline);
        }elsif($name eq 'idValue' &&
                # xml:id
                !exists $atts{'{http://www.w3.org/XML/1998/namespace}id'}){
            _process_idValue($value, $tu, $inline);
        }elsif($name eq 'term' &&
                # its:term
                !exists $atts{'{'.its_ns().'}'.'term'}){
            my %termHash;
            my @term_atts = qw(
                term
                termInfo
                termInfoRef
                termConfidence
            );
            @termHash{@term_atts} = @$its_info{@term_atts};
            _process_term($el, %termHash);
        }
    }
    return;
}

# pass in an element to be annotated, locNote and locNoteType values,
# and whether the element is inline or not
# TODO: too many params; use named ones.
sub _process_locNote {
    my ($el, $note, $type, $tu, $inline) = @_;
    my $priority = $type eq 'alert' ? '1' : '2';
    if($inline){
        $el->set_att('comment', $note);
        $el->set_att('itsxlf:locNoteType', $type, $ITSXLF_NS);
    }else{
        my $note = new_element('note', {}, $note, $XLIFF_NS);
        $note->set_att('priority', $priority);
        $note->paste($tu);
    }
    return;
}

# input element and it's ITS translate value, containing TU, and whether
# it's inline
# TODO: too many params; use named ones.
sub _process_translate {
    my ($el, $translate, $tu, $inline) = @_;
    if($inline){
        $el->set_att('mtype',
            $translate eq 'yes' ?
            'x-its-translate-yes' :
            'protected');
    }else{
        $tu->set_att('translate', $translate);
    }
    return;
}

sub _process_term {
    my ($el, %termInfo) = @_;
    $termInfo{term} eq 'yes' ?
        $el->set_att('mtype', 'term') :
        $el->set_att('mtype', 'x-its-term-no');

    for my $name(qw(termInfoRef termConfidence termInfo)){
        if (my $val = $termInfo{$name}){
            $el->set_att("itsxlf:$name", $val, $ITSXLF_NS);
        }
    }
    return;
}

sub _process_idValue {
    my ($id, $tu, $inline) = @_;
    #this att is ignored on inline elements
    if(!$inline){
        $tu->set_att('resname', $id);
    }
    return;
}

1;

__END__

=pod

=head1 NAME

ITS::WICS::XML2XLIFF::ITSProcessor - Process and convert XML and XLIFF ITS (internal use only).

=head1 VERSION

version 0.04

=head1 EXPORTS

The following function may be exported:

=head2 C<its_requires_inline>

Return true if converting the ITS info on the given element
requires that it be rendered inline (as mrk) instead of structural
(as its own source). Currently the only information tested for is terminology
information.

The arguments are the element being tested and the hash reference containing the global
information pertaining to it.

=head2 C<transfer_inline_its>

Transfer ITS that is required to be on a mrk (not on a source) from one
element (first argument) to the another (second argument).

Arguments are the element to move the markup from and the element to move
the markup to.

=head2 C<has_localizable_inline>

Arguments: an array ref containing attribute nodes, and the match index
containing the global ITS info for an element.

Returns true if there is any ITS information which must be placed as an
attribute on the element which it applies to, if the element is inline.

=head2 C<convert_atts>

Convert all XML ITS attributes into XLIFF ITS for the given element.
The arguments are: first the local element where any new attributes should
be placed; second an array
ref containing the attribute nodes to be converted; and third
the C<trans-unit> element currently being created. This is not necessary
if the element in question is inline.

=head2 C<localize_rules>

Arguments are: first an element to have ITS metadata applied locally; second
the translation unit containing the element; third the match index
containing the global ITS info for the element; and fourth an array ref
containing the local attribute nodes assumed to exist on the element being
processed.

This function converts ITS info contained in global rules matching the
element into equivalent local markup on either the element itself or the
trans-unit.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
