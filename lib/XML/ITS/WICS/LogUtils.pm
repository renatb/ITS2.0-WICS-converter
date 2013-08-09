package XML::ITS::WICS::LogUtils;
use strict;
use warnings;
use XML::ITS::DOM::Node;
use Exporter::Easy (OK => [qw(node_log_id)]);
use Carp;

# ABSTRACT: Log utility functions for WICS
# VERSION

=head1 METHODS

=head2 C<node_log_id>

Return a string to represent a node or value in a log message. Each type of
node/value is marked differently, and where possible the name of the node
is used. Elements also have id/xml:id attributes included when present.

=cut
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

1;