#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::LogUtils;
use strict;
use warnings;
use ITS::DOM::Node;
use Exporter::Easy (
    OK => [qw(
        node_log_id
        get_or_set_id
        log_match
        log_new_rule
        )]
);
use Carp;

# ABSTRACT: Log utility functions for WICS
our $VERSION = '0.04'; # VERSION

sub node_log_id {
    my ($node) = @_;

    if((ref $node) =~ /Value/){
        return $node->value;
    }
    my $type = $node->type;
    if($type eq 'ELT'){
        # take XML ID if possible; otherwise, HTML id
        my $id;
        if($id = $node->att('xml:id')){
            $id = qq{ xml:id="$id"};
        }elsif($id = $node->att('id')){
            $id = qq{ id="$id"};
        }else{
            $id = '';
        }
        return '<' . $node->name . $id . '>';
    }elsif($type eq 'ATT'){
        return '@' . $node->name . '[' . $node->value . ']';
    }elsif($type eq 'COM'){
        #use at most 10 characters from the comment for display purposes
        my $length = length $node->value;
        $length > 10 && ($length = 10);
        return '<!--' . substr($node->value, 0, $length)  . '-->';
    }elsif($type eq 'PI'){
        return '<?' . $node->name  . '?>';
    }elsif($type eq 'TXT'){
        #use at most 10 characters from the text for display purposes
        my $length = length $node->value;
        $length > 10 && ($length = 10);
        return '[text: ' . substr($node->value, 0, $length)  . ']';
    }elsif($type eq 'NS'){
        return '[namespace: ' . $node->name  . ']';
    }elsif($type eq 'DOC'){
        return '[DOCUMENT]';
    }else{
        croak 'Need logic for logging ' . $type;
    }
}

sub log_match {
    my ($rule, $match, $log) = @_;
    if ($log->is_debug()){
        my $message = 'match: rule=' . node_log_id($rule->element);
        $message .= "; $_=" . node_log_id($match->{$_})
            for keys $match;
        $log->debug($message);
    }
    return;
}

sub log_new_rule {
    my ($new_rule, $futureNodes, $log) = @_;
    my $string = 'Creating new rule ' . node_log_id($new_rule) .
        ' to match [';
    my @match_strings;
    for my $key(keys %$futureNodes){
        my $futureNode = $futureNodes->{$key};
        if((ref $futureNode) =~ /FutureNode/){
            push @match_strings, "$key=" .
                 node_log_id($futureNode->new_node);
        }else{
            push @match_strings, "$key=" . $futureNode->as_xpath;
        }
    }
    $string .= join '; ', @match_strings;
    $string .= ']';
    $log->debug($string);
    return;
}

sub get_or_set_id {
    my ($el, $dom, $log) = @_;
    my $id = $el->att('id');
    if(!$id){
        $id = 'ITS_' . $dom->next_id();
        if($log->is_debug){
            $log->debug('Setting id of ' . node_log_id($el) . " to $id");
        }
        $el->set_att('id', $id);
    }
    return $id;
}

1;

__END__

=pod

=head1 NAME

ITS::WICS::LogUtils - Log utility functions for WICS

=head1 VERSION

version 0.04

=head1 METHODS

=head2 C<node_log_id>

Return a string to represent a node or value in a log message. Each type of
node/value is marked differently, and where possible the name of the node
is used. Elements also have id/xml:id attributes included when present.

=head2 C<log_match>

Logs a global rule match.

Arguments are an C<ITS::Rule> and a match hash pointer
(the arguments used in an C<ITS::iterate_matches> handler),
and a C<Log::Any> object to use to log the given rule match.

=head2 C<log_new_rule>

Log the creation of a new rule.

Arguments are the created rule, its matched FutureNodes
in an array ref, and the C<Log::Any> object to use for logging.

=head2 C<get_or_set_id>

Either returns an element's id value, or sets one, logs the change,
and returns it.

Arguments are: element to get or set ID from/on, C<ITS::DOM> object
containing the element, and the C<Log::Any> object to log ID setting with.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
