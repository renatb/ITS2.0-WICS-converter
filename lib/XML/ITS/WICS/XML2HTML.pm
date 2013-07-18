package XML::ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(XML::ITS::WICS::XML2HTML XML::ITS::WICS);
use Log::Any qw($log);
use XML::ITS::WICS::XML2HTML::FutureNode qw(create_future);
use XML::ITS;

# ABSTRACT: Convert ITS-decorated XML into HTML with equivalent markup
# VERSION

__PACKAGE__->new()->convert(doc => $ARGV[0]) unless caller;

=head1 METHODS

=head2 C<new>

Creates a new converter instance. Optional arguments are:

=over 2

=item title

Title to give output HTML document (default is "WICS").

=back

=cut
sub new {
	my ($class, %args) = @_;
	%args = (
		title => 'WICS',
		%args
	);
	return bless {}, $class;
}

=head2 C<convert>

Converts the input XML document into an HTML document equivalent, and
displayable, HTML.

Argument is either a string containing an XML file name, or a string pointer
containing actual XML data.

Return value is a string pointer containing the output HTML string.

=cut

sub convert {
	my ($self, @args) = @_;
	my $ITS = XML::ITS->new('xml', @args);

	#[rule, {selector => futureNode, *pointer => futureNode...}]
	my @matches;
	$ITS->iterate_matches(_create_indexer(\@matches));
	# make $ITS doc into HTML
	# paste futureNodes and new matching rules
	# stringify and return
}

# create an indexing sub which pushes matches onto input array pointer
sub _create_indexer {
	my ($index_array) = @_;
	return sub {
		my ($rule, $match) = @_;
		_log_match($rule, $match);
		my $futureNodes = {};
		for (keys %$match) {
			$futureNodes->{$_} =
				create_future($match->{$_});
		}
		push @{ $index_array }, [$rule, $futureNodes];
	};
}

sub _log_match {
	my ($rule, $match) = @_;
	if ($log->is_debug()){
		my $message = $rule->type . ' rule ';
		if(my $id = $rule->node->att('xml:id')){
			$message .= "($id) ";
		}
		$message .= 'matched ' .
			$match->{selector}->name;
		if(my $id = $match->{selector}->att('xml:id')){
			$message .= " ($id)"
		}
		$log->debug($message);
	}
	return;
}

#add doctype
#put contents into body, and add html, head, and meta elements
sub _make_html {
	my ($self, $doc) = @_;

	# my $root = $twig->root;
	# my $html = $root->wrap_in('body', 'html');
	# $html->set_att('xmlns', 'http://www.w3.org/1999/xhtml');
	# # https://github.com/mirod/xmltwig/issues/5
	# $twig->set_root($html);

	# my $head = XML::Twig::Elt->new('head');
	# XML::Twig::Elt->new( meta => { charset => 'utf-8' } )->paste('first_child' => $head);
	# XML::Twig::Elt->new('title', $self->{title})->paste('first_child' => $head);
	# $head->paste(first_child => $html);
}

#add title attribute containing tag name
#save list of tags needing to be 'span' in $twig->{span_list}
sub _choose_name {
	my ($twig, $el) = @_;
	# $el->set_att('title', $el->tag);
	#save a list to rename later
	push @{$twig->{els_to_rename}}, $el;
	#we already know that this will be a span
	return if $twig->{span_list}->{$el->tag};

	#find out if this should be a span or is a viable div
	#only elements with no #PCDATA before/after can be divs
	my $prev = $el->prev_sibling;
	my $next = $el->next_sibling;
	if( ($prev && $prev->tag() eq '#PCDATA') ||
		($next && $next->tag() eq '#PCDATA') ){
		$twig->{span_list}->{$el->tag}++;
	}
}

1;