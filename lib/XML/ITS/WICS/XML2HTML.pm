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
	my @its_els;
	my $processor = _traversal_sub(\@its_els);
	my $root = $doc->get_root;
	$processor->($root);

	#make the document into an HTML structure
	return $self->_html_structure($doc, \@its_els);
}

#return a sub which processes every element in the entire document
#the input scalar is used as an array ref to store all its:* elements
##(which have to be put in the HTML header)
sub _traversal_sub {
	my ($its_els) = @_;

	# a recursive sub which transforms elements into HTML and returns
	# true for a child renamed as a div, false otherwise. Arguments
	# are element to transform and boolean indicating inline ancestor
	# (like <span> or <bdo>; so this element should not be made a <div>)
	my $traverse_sub;
	$traverse_sub = sub {
		my ($el, $inline_ancestor) = @_;
		# print 'processing ' . $el->name . "\n";
		# its: elements other than 'rules' are standoff markup;
		# don't rename these, and save them for pasting in the head
		if($el->namespaceURI &&
			$el->namespaceURI eq $ITS_NS){
			push @$its_els, $el;
			return 0;
		}

		# process attributes; some will become different
		# attributes, others will be deleted but indicated
		# in the new title attribute
		my $title = $el->name;
		my @atts = $el->get_xpath('@*');
		# true if the children were wrapped in an inline element (like bdo)
		my $inlined_children;
		if(@atts){
			my @save_atts;
			for my $att (@atts){
				#TODO: deal with its:dir stuff here
				my ($save, $wrapped) = _process_att($el, $att);
				push @save_atts, $save
					if $save;
				$inlined_children ||= $wrapped;
			}
			if(@save_atts){
				$title .= '[' . (join ',', @save_atts) . ']';
			}
		}
		$el->set_att('title', $title);

		# strip namespacing; this moves the namespace declaration to the children,
		# if used by them
		$el = $el->strip_ns;

		my $children;
		#if children were wrapped in an element, grab them from that element
		if($inlined_children){
			$children = ${$el->child_els}[0]->child_els;
		}else{
			$children = $el->child_els;
		}
		# true if any child is a div;
		my $div_child;
		for my $child(@$children){
			my $div_result = $traverse_sub->($child, $inlined_children);
			$div_child ||= $div_result;
		}

		# take care not to create a span/bdo containing a div!
		if($div_child){
			$el->set_name('div');
			return 1;
		}elsif($inline_ancestor){
			$el->set_name('span');
			return 0;
		}elsif($el->is_inline){
			$el->set_name('span');
			return 0;
		}else{
			$el->set_name('div');
			return 2;
		}
	};
	# return $traverse_sub;
}

#process given attribute on given element;
#return 2 things: a string to save, representing the attribute, if
#the attribute is deleted (and isn't an NS att), and the name
#of an element used to wrapp the children, if any.
sub _process_att {
	my ($el, $att) = @_;

	my $wrapped;
	#xml: attributes with ITS semantics
	if($att->name eq 'xml:id'){
		$el->set_att('id', $att->value);
		$att->remove;
	}elsif($att->name eq 'xml:lang'){
		$att->set_name('lang');
	#its:* attributes
	}elsif($att->namespaceURI eq $ITS_NS){
		if($att->local_name eq 'translate'){
			$el->set_att('translate', $att->value);
			$att->remove;
			return;
		}elsif($att->local_name eq 'dir'){
			if($att->value =~ /^(?:lro|rlo)$/){
				my $dir = $att->value eq 'lro' ?
					'ltr':
					'rtl';
				#html requires an inline bdo element
				my $bdo = new_element('bdo',{dir => $dir});
				for my $child(@{ $el->children }){
					$child->paste($bdo);
				}
				$bdo->paste($el);
				$att->remove;
				return '', 'bdo';
			}else{
				#ltr and rtl are just 'dir' attributes
				$att->set_name('dir');
				return '';
			}
		}else{
			my $name = $att->local_name;
			$name =~ s/([A-Z])/-$1/g;
			$el->set_att("its-$name", $att->value);
			$att->remove;
			return;
		}
	}else{
		$att->remove;
	}

	#don't bother saving these
	return '' if $att->name =~ /xmlns(?::|$)/;
	# a short string to represent the att name/value
	return $att->name . q{='} . $att->value . q{'};
}


#create an HTML document with input doc root element as a child of body
# create script elements for each el in $its_els, and paste in head
# return the new XML::ITS::DOM object
sub _html_structure {
	my ($self, $doc, $its_els) = @_;

	#TODO: this should be html, not xml
	my $dom = XML::ITS::DOM->new('html', \'<!DOCTYPE html><html>');
	my ($head) = $dom->get_root->get_xpath(
		'//html:head',
		namespaces => {html => 'http://www.w3.org/1999/xhtml'}
	);
	my $meta = new_element('meta', { charset => 'utf-8' });
	$meta->paste($head);
	my $title = new_element('title', {}, $self->{title});
	$title->paste($head);

	for my $its(@$its_els){
		_get_script($its)->paste($head);
	}

	my ($body) = $dom->get_root->get_xpath(
		'//html:body',
		namespaces => {html => 'http://www.w3.org/1999/xhtml'}
	);new_element('body');

	my $html = $dom->get_root();
	$head->paste($html);
	$body->paste($html);
	$doc->get_root->paste($body);

	return $dom;
}

# create an ITS script element and paste the input element into it and return it
sub _get_script {
	my ($element) = @_;
	my $script = new_element('script', {type => 'application/its+xml'});
	if(my $id = $element->att('xml:id')){
		$script->set_att('id', $id);
	}
	$element->paste($script);
	return $script;
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