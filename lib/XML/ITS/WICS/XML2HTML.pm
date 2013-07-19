package XML::ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(XML::ITS::WICS::XML2HTML XML::ITS::WICS);
use Log::Any qw($log);
use XML::ITS::WICS::XML2HTML::FutureNode qw(create_future);
use XML::ITS;
use XML::ITS::DOM;
use XML::ITS::DOM::Node qw(new_element);

my $ITS_NS = 'http://www.w3.org/2005/11/its';

# ABSTRACT: Convert ITS-decorated XML into HTML with equivalent markup
# VERSION

__PACKAGE__->new()->convert($ARGV[0]) unless caller;

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
	return bless \%args, $class;
}

=head2 C<convert>

Converts the input XML document into an HTML document equivalent, and
displayable, HTML.

Argument is either a string containing an XML file name, or a string pointer
containing actual XML data.

Return value is a string pointer containing the output HTML string.

=cut

sub convert {
	my ($self, $doc) = @_;
	my $ITS = XML::ITS->new('xml', doc => $doc);

	#[rule, {selector => futureNode, *pointer => futureNode...}]
	my @matches;
	$ITS->iterate_matches(_create_indexer(\@matches));
	# make $ITS doc into HTML
	my $html_doc = $self->_htmlize($ITS->get_doc);
	# paste futureNodes and new matching rules
	# return string pointer
	return \($html_doc->string);
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

sub _htmlize {
	my ($self, $doc) = @_;

	#save the original document root for querying
	my $root = $doc->get_root;
	#make the document into an HTML structure
	my $head;
	($doc, $head) = $self->_html_structure($doc);
	for my $element ($root->get_xpath('descendant-or-self::*')){
		# its: elements other than 'rules' are standoff markup
		# TODO: should paste as last child, not first (rules will be out of order!)
		# if($element->namespaceURI eq $ITS_NS){
		# 	_get_script($element)->paste($head);
		# 	continue;
		# }
		my $title = $element->name;
		my @atts = $element->get_xpath('@*');
		if(@atts){
			my @save_atts;
			for my $att (@atts){
				push @save_atts, $att->name . q{='} . $att->value . q{'};
				if($att->name eq 'xml:id'){
					$element->set_att('id', $att->value);
					$att->remove;
				}elsif($att->name eq 'xml:lang'){
					$att->set_name('lang');
				}elsif($att->namespaceURI eq $ITS_NS){
					if($att->local_name eq 'translate'){
						$att->set_name('translate');
					}elsif($att->local_name eq 'dir'){
						$att->set_name('dir');
						# TODO: may need finagling of values
					}else{
						my $name = $att->local_name;
						$name =~ s/([A-Z])/-$1/g;
						$element->set_att($name, $att->value);
						$att->remove;
					}
				}else{
					$att->remove;
				}
			}
			$title .= '[' . (join ',', @save_atts) . ']';
		}
		$element->set_att('title', $title);
		$element->set_name($element->is_inline ? 'span' : 'div');
	}
	return $doc;
}

# create an ITS script element and paste the input element into it and return it
sub _get_script {
	my ($element) = @_;
	my $script = XML::ITS::DOM->new('script', {type => 'application/its+xml'});
	$element->paste($script);
	return $script;
}

# put contents into body, and add html, head, and meta elements
# return a new XML::ITS::DOM, and also the head element separately
#
sub _html_structure {
	my ($self, $doc) = @_;

	#TODO: this should be html, not xml
	my $dom = XML::ITS::DOM->new('xml', \'<html/>');

	my $html = $dom->get_root();
	my $head = new_element('head');
	my $meta = new_element('meta', { charset => 'utf-8' });
	my $title = new_element('title', {}, $self->{title});
	$title->paste($head);
	$meta->paste($head);
	$head->paste($html);
	my $body = new_element('body');
	$body->paste($html);
	$doc->get_root->paste($body);
	return ($dom, $head);
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