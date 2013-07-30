package XML::ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(XML::ITS::WICS::XML2HTML XML::ITS::WICS);
use Log::Any qw($log);

use XML::ITS qw(its_ns);
use XML::ITS::DOM;
use XML::ITS::DOM::Element qw(new_element);
use XML::ITS::WICS::XML2HTML::FutureNode qw(create_future);

use feature 'state';
#Memoize is used to speed up, and make consistent, log messages
#relate to a particular element
use Memoize qw(memoize unmemoize);

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

	# this way we always get back the same string, even if xml:id has
	# been removed from an element
	memoize('_el_log_id');

	# [rule, {selector => futureNode, *pointer => futureNode...}]
	my @matches;
	# pointers to all existing future nodes; keys are represented nodes
	my %future_cache;
	$ITS->iterate_matches(_create_indexer(\@matches, \%future_cache));
	# make $ITS doc into HTML
	my $html_doc = $self->_htmlize($ITS->get_doc, \%future_cache);
	# paste futureNodes and new matching rules
	$self->_update_rules(\@matches);

	unmemoize('_el_log_id');
	# return string pointer
	return \($html_doc->string);
}

# create an indexing sub which pushes matches onto input array pointer
sub _create_indexer {
	my ($index_array, $future_cache) = @_;
	return sub {
		my ($rule, $match) = @_;
		_log_match($rule, $match);
		my $futureNodes = {};
		for (keys %$match) {
			# TODO: this cache won't actually work
			# don't create futureNodes for the same node twice!
			# store pointer to future node so that the futureNodes hash
			# contents can be edited via future_cache
			$futureNodes->{$_} =
				$future_cache->{ $match->{$_}->unique_key } ||=
				 \( create_future($match->{$_}) );
		}
		push @{ $index_array }, [$rule, $futureNodes];
	};
}

sub _log_match {
	my ($rule, $match) = @_;
	if ($log->is_debug()){
		my $message = 'match: rule=' . _el_log_id($rule->node);
		$message .= "; $_=" . _el_log_id($match->{$_})
			for keys $match;
		$log->debug($message);
	}
	return;
}

# pass in document to be htmlized and a hash containing node->futureNode ref pairs
# (these are nodes which have been selected; this is needed in case the node is
# replaced because of namespace removal)
sub _htmlize {
	my ($self, $doc, $future_cache) = @_;

	# traverse every document element, converting into HTML
	# save standoff or rules elements in @its_els
	$log->debug('converting document elements into HTML')
		if $log->is_debug;
	my @its_els;
	my $processor = _traversal_sub(\@its_els);
	$processor->($doc->get_root, 0, $future_cache);

	#make the document into an HTML structure
	$log->debug('wrapping document in HTML structure')
		if $log->is_debug;
	return $self->_html_structure($doc, \@its_els);
}

#return a sub which processes every element in the entire document
#the input scalar is used as an array ref to store all its:* elements
##(which have to be put in the HTML header)
sub _traversal_sub {
	my ($its_els) = @_;

	# a recursive sub which transforms elements into HTML and returns
	# true for a child renamed as a div, false otherwise. Arguments
	# are element to transform; boolean indicating inline ancestor
	# (like <span> or <bdo>; so this element should not be made a <div>);
	# and the node->futureNode ref hash ref (in case of node replacement
	# for namespace removal)
	my $traverse_sub;
	$traverse_sub = sub {
		my ($el, $inline_ancestor, $future_cache) = @_;
		# its: elements other than 'rules' are standoff markup;
		# don't rename these, and save them for pasting in the head
		if($el->namespaceURI &&
			$el->namespaceURI eq its_ns()){
			push @$its_els, $el;
			if($log->is_debug){
				$log->debug('placing ' . _el_log_id($el) . ' in script element');
			}
			return 0;
		}
		if($log->is_debug){
			# print "processing " . $el->name . $el->att('xml:id');
			$log->debug('processing ' . _el_log_id($el));
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
		if($log->is_debug){
			$log->debug('setting @title of ' . _el_log_id($el) . " to '$title'");
		}

		# strip namespacing; this moves the namespace declaration to the children,
		# if used by them
		my $new_el = $el->strip_ns;
		my $old_el = $el; # for logging purposes
		if(!$el->is_same_node($new_el)){
			if($log->is_debug){
				$log->debug('stripping namespaces from ' . _el_log_id($el));
			}
			# if this element has an associated future (match), change the future
			# to one for the new node
			exists $future_cache->{$old_el->unique_key} and
				${ $future_cache->{$old_el->unique_key} } = create_future($new_el);
			$el = $new_el;
		}

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
			my $div_result = $traverse_sub->(
				$child, $inlined_children, $future_cache);
			$div_child ||= $div_result;
		}

		my $is_div = _rename_el($el, $div_child, $inline_ancestor);
		if($log->is_debug){
			my $new_name = $is_div ? 'div' : 'span';
			$log->debug('renaming ' . _el_log_id($old_el) . " to <$new_name>");
		}
		return $is_div;
	};
	return $traverse_sub;
}

# rename the given element to either div or span; return true for div,
# false for span.
# args: element, boolean for existing block child (div, etc.),
# boolean for existing inline ancestor (span, bdo, etc.)
sub _rename_el {
	my ($el, $div_child, $inline_ancestor) = @_;

	my $new_name;
	# if a child is a div, this has to be a div
	if($div_child){
		$new_name = 'div';
	# if an ancestor was a span/bdo, this has to be a span
	}elsif($inline_ancestor || $el->is_inline){
		$new_name = 'span';
	}else{
		$new_name = 'div';
	}

	$el->set_name($new_name);
	return $new_name eq 'div' ? 1 : 0;
}

#get a string to indicate the given element in a log
#<el> or <el xml:id="val">
sub _el_log_id {
	my ($el) = @_;
	# values
	if((ref $el) =~ /Value/){
		return $el->value;
	}
	# elements
	my $id = $el->att('xml:id');
	my $string = '<' . $el->name;
	$string .= qq{ xml:id="$id"}
		if $id;
	$string .= '>';
	return $string;
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
		_att_rename($el, $att, 'id');
	}elsif($att->name eq 'xml:lang'){
		_att_rename($el, $att, 'lang');
	#its:* attributes
	}elsif($att->namespaceURI && $att->namespaceURI eq its_ns()){
		if($att->local_name eq 'translate'){
			_att_rename($el, $att, 'translate');
			return;
		}elsif($att->local_name eq 'dir'){
			if($att->value =~ /^(?:lro|rlo)$/){
				my $dir = $att->value eq 'lro' ?
					'ltr':
					'rtl';
				if($log->is_debug){
					$log->debug('replacing @' . $att->name . ' of ' .
						_el_log_id($el) .
						" with bdo[dir=$dir] wrapped around children");
				}
				#inline bdo element
				my $bdo = new_element('bdo',{dir => $dir});
				for my $child(@{ $el->children }){
					$child->paste($bdo);
				}
				$bdo->paste($el);
				$att->remove;
				return '', 'bdo';
			}else{
				#ltr and rtl are just 'dir' attributes
				_att_rename($el, $att, 'dir');
				return '';
			}
		}else{
			my $name = $att->local_name;
			$name =~ s/([A-Z])/-$1/g;
			$name = "its-$name";
			$el->set_att($name, $att->value);
			if($log->is_debug){
				$log->debug('Replacing @' . $att->name . ' of ' .
				_el_log_id($el) . " with $name");
			}
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

#rename given att on given el to new_name and log it.
sub _att_rename {
	my ($el, $att, $new_name) = @_;
	if($log->is_debug){
		$log->debug('renaming @' . $att->name . ' of ' . _el_log_id($el) .
			" to \@$new_name");
	}
	#have to replace with new att because renaming doesn't work with namespaces
	$el->set_att($new_name, $att->value);
	$att->remove;
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

#make sure all rule matches are elemental, and paste rules that match them
sub _update_rules {
	my ($self, $matches) = @_;

	#create a new rule for each match
	for my $match (@$matches){
		my ($rule, $futureNodes) = @$match;
		my $new_rule = $rule->node->copy(0);
		for my $key(keys %$futureNodes){
			my $futureNode = ${ $futureNodes->{$key} };
			#FutureNodes- make it visible in the dom and match the rule with its ID
			if((ref $futureNode) =~ /FutureNode/){
				my $el = $futureNode->elemental;
				$new_rule->set_att($key, q{id('} . $self->_get_or_set_id($el) . q{')})
			}else{
				#DOM values- match the rule with the value
				$new_rule->set_att($key, $futureNode->as_xpath);
			}
		}
		# _get_or_set_id($new_rule);
		if($log->is_debug){
			my $selected = ${ $futureNodes->{'selector'} };
			$log->debug('Creating new rule ' . _el_log_id($new_rule) .
				' to match ' . _el_log_id($selected->elemental));
		}
		$new_rule->paste_before($rule->node);
	}
	#now remove all original matching rules
	for my $match (@$matches){
		$match->[0]->node->remove;
	}
	return;
}

#returns the id attribute of the given element; creates one if none exists.
sub _get_or_set_id {
	my ($self, $el) = @_;
	my $id = $el->att('id');
	if(!$id){
		$id = $self->_next_id();
		$el->set_att('id', $id);
	}
	return $id;
}

#returns a unique string "ITS_#", '#' being some number.
sub _next_id {
	my ($self) = @_;
	$self->{num}++;
	return "ITS_$self->{num}";
}

1;