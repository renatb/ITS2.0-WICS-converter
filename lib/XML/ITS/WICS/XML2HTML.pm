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
our $HTML_NS = 'http://www.w3.org/1999/xhtml';

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

	# [rule, {selector => futureNode, *pointer => futureNode...}]
	my @matches;
	# pointers to all existing future nodes; keys are represented nodes
	my %future_cache;
	# find all rule matches and save them in @matches,
	# and FutureNode pointers in %future_cache
	$ITS->iterate_matches(_create_indexer(\@matches, \%future_cache, $ITS->get_doc));

	# convert $ITS into an HTML document; rename elements, process atts,
	# and paste the root in an HTML body. %future_cache is necessary
	# when an element originally matched by a rule is to be replaced.
	my $html_doc = $self->_htmlize($ITS->get_doc, \%future_cache);

	#grab the head to put rules in it
	my $head = ( $html_doc->get_root->children )[0];
	# paste FutureNodes and create new rules to match them
	$self->_update_rules(\@matches, $head);

	# return string pointer
	return \($html_doc->string);
}

# create an indexing sub for ITS::iterate_matches, and use a
# closure to create some indices during processing, as well
# as provide access to the containing document.
# This sub pushes matches and FutureNodes onto $index_array,
# and saves pointers to all FutureNodes in $future_cache.
sub _create_indexer {
	my ($index_array, $future_cache, $doc) = @_;

	#iterate_matches passes in a rule and it's matched nodes
	return sub {
		my ($rule, $matches) = @_;
		_log_match($rule, $matches);

		# create FutureNodes to represent each matched node;
		# $futureNodes is $match, but with FutureNodes instead of Nodes
		my $futureNodes = {};
		# $name is 'selector', 'locNotePointer', etc.
		for my $name (keys %$matches) {
			my $match = $matches->{$name};
			# nothing special for literal values
			if((ref $match) =~ /Value$/){
				$futureNodes->{$name} = \$match;
			}
			# Cache FutureNodes so that we don't create one for the
			# same node multiple times.
			# Store pointers so that the futureNodes hash
			# contents can be edited via $future_cache later.
			else{
				$futureNodes->{$name} =
					$future_cache->{ $match->unique_key } ||=
					 \( create_future($match, $doc) );
			}
		}
		push @{ $index_array }, [$rule, $futureNodes];
		return;
	};
}

sub _log_match {
	my ($rule, $match) = @_;
	if ($log->is_debug()){
		my $message = 'match: rule=' . _el_log_id($rule->element);
		$message .= "; $_=" . _el_log_id($match->{$_})
			for keys $match;
		$log->debug($message);
	}
	return;
}

# Pass in document to be htmlized and a hash containing node->futureNode ref pairs
# (these are nodes which have been matched by rules; this is needed in case the
# element is replaced because of namespace removal)
sub _htmlize {
	my ($self, $doc, $future_cache) = @_;

	$log->debug('converting document elements into HTML')
		if $log->is_debug;
	# traverse every document element, converting into HTML
	# save standoff or rules elements in @its_els
	my @its_els;
	my $processor = _traversal_sub(\@its_els, $future_cache);
	# 0 means there is no inline ancestor
	$processor->($doc->get_root, 0);

	# return an HTML doc with the current doc as its body contents
	return $self->_html_structure($doc, \@its_els);
}

# return a sub which recursively processes an element and all of its children.
# All its:* elements are stored in $its_els (for pasting in the HTML head later),
# and contents of $future_cache are edited when elements are replaced due to
# namespace removal.
sub _traversal_sub {
	my ($its_els, $future_cache) = @_;

	# a recursive sub which transforms elements into HTML and returns
	# true for a child renamed as a div, false otherwise.
	# Arguments are the element to transform and a boolean indicating
	# the existence of an inline ancestor (so this element should not
	# be made a <div>)
	my $traverse_sub;
	$traverse_sub = sub {
		my ($el, $inline_ancestor) = @_;

		#its:* elements are either rules or standoff
		if($el->namespaceURI &&
			$el->namespaceURI eq its_ns()){
			#its:rules; just remove these and paste new ones later
			if($el->local_name eq 'rules'){
				$el->remove;
				if($log->is_debug){
					$log->debug('removing ' . _el_log_id($el));
				}
				return 0;
			}
			# save standoff markup for pasting in the head
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

		# true if the children are wrapped in an inline element
		# (as with its:dir=rlo)
		my $inlined_children;

		# process attributes
		my $title = $el->name;
		my @atts = $el->get_xpath('@*');
		if(@atts){
			my @save_atts;
			for my $att (@atts){
				my ($save, $wrapped) = _process_att($el, $att);
				push @save_atts, $save
					if $save;
				$inlined_children ||= $wrapped;
			}
			#save previous attributes in new title attribute
			if(@save_atts){
				$title .= '[' . (join ',', @save_atts) . ']';
			}
		}
		if($log->is_debug){
			$log->debug('setting @title of ' . _el_log_id($el) . " to '$title'");
		}
		$el->set_att('title', $title);

		# strip namespacing; requires special care because it replaces
		# an element, requiring reworking of FutureNode indices
		my $new_el = $el->strip_ns;
		if(!$el->is_same_node($new_el)){
			if($log->is_debug){
				$log->debug('stripping namespaces from ' . _el_log_id($el));
			}
			# if this element has an associated future (match), change the future
			# to one for the new node
			if(exists $future_cache->{$el->unique_key}){
				${ $future_cache->{$el->unique_key} } = create_future($new_el);
			}
			$el = $new_el;
		}

		# grab children for recursive processing
		my $children;
		if(!$inlined_children){
			$children = $el->child_els;
		}else{
			# if children were wrapped in a new HTML element,
			# grab them from that element
			$children = ${$el->child_els}[0]->child_els;
		}

		# recursively process children
		# true if any child is a div
		my $div_child;
		for my $child(@$children){
			my $div_result = $traverse_sub->(
				$child, $inlined_children);
			$div_child ||= $div_result;
		}

		return _rename_el($el, $div_child, $inline_ancestor);
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
	}elsif($inline_ancestor){
		$new_name = 'span';
	# inline elements become spans
	}elsif($el->is_inline){
		$new_name = 'span';
	# other elements become divs
	}else{
		$new_name = 'div';
	}
	if($log->is_debug){
		$log->debug('renaming ' . _el_log_id($el) . " to <$new_name>");
	}

	$el->set_name($new_name);
	return $new_name eq 'div' ? 1 : 0;
}

# get a string to indicate the given element or Value in a log
# for elements: <el> or <el xml:id="val"> or <el id="val">
# for values: the value itself.
sub _el_log_id {
	my ($el) = @_;


	if((ref $el) =~ /Value/){
		return $el->value;
	}
	my $type = $el->type;
	if($type eq 'ELT'){
		# take XML ID if possible; otherwise, HTML id
		my $id;
		if($id = $el->att('xml:id')){
			$id = qq{ xml:id="$id"};
		}elsif($id = $el->att('id')){
			$id = qq{ id="$id"};
		}else{
			$id = '';
		}
		return '<' . $el->name . $id . '>';
	}elsif($type eq 'ATT'){
		return '@' . $el->name . '[' . $el->value . ']';
	}elsif($type eq 'COM'){
		#use at most 10 characters from the comment for display purposes
		my $length = length $el->value;
		$length > 10 && ($length = 10);
		return '<!--' . substr($el->value, 0, $length)  . '-->';
	}elsif($type eq 'PI'){
		return '<?' . $el->name  . '?>';
	}elsif($type eq 'TXT'){
		#use at most 10 characters from the text for display purposes
		my $length = length $el->value;
		$length > 10 && ($length = 10);
		return '[text: ' . substr($el->value, 0, $length)  . ']';
	}elsif($type eq 'NS'){
		return '[namespace: ' . $el->name  . ']';
	}else{
		croak 'Need logic for logging ' . $type;
	}
}

# process given attribute on given element;
# return 2 things: a string to save, representing the attribute, if
# the attribute is deleted (empty for NS declarations), and the name
# of the element used to wrap the children, if any.
sub _process_att {
	my ($el, $att) = @_;

	my $wrapped;
	# xml:* attributes with ITS semantics
	if($att->name eq 'xml:id'){
		_att_rename($el, $att, 'id');
	}elsif($att->name eq 'xml:lang'){
		_att_rename($el, $att, 'lang');
	#its:* attributes with HTML semantics
	}elsif($att->namespaceURI && $att->namespaceURI eq its_ns()){
		if($att->local_name eq 'translate'){
			_att_rename($el, $att, 'translate');
			return;
		}elsif($att->local_name eq 'dir'){
			if($att->value =~ /^(?:lro|rlo)$/){
				_process_dir_override($el, $att);
				return '', 'bdo';
			}else{
				#ltr and rtl are just 'dir' attributes
				_att_rename($el, $att, 'dir');
				return '';
			}
		}else{
			# default transformation for all other its:* atts
			_htmlize_its_att($el, $att);
			return;
		}
	}else{
		# just delete other atts
		$att->remove;
	}

	#don't bother saving NS declarations in new element title
	return '' if $att->name =~ /xmlns(?::|$)/;
	# a short string to represent the att name and value
	return $att->name . q{='} . $att->value . q{'};
}

#rename given att on given el to new_name.
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

# process an element with an att which is its:dir=lro or rlo;
# this requires the wrapping of children with the <bdo> element
# in HTML.
sub _process_dir_override {
	my ($el, $att) = @_;

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
	for my $child($el->children){
		$child->paste($bdo);
	}
	$bdo->paste($el);
	$att->remove;
	return;
}

# convert a given its att into an HTML one by replacing
# caps with dashes and appending its- on the front.
sub _htmlize_its_att {
	my ($el, $att) = @_;

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

# Create and return an HTML document with the input doc's root element
# inside of the body. Create script elements for each el in $its_els
# and paste them in the head
sub _html_structure {
	my ($self, $doc, $its_els) = @_;

	$log->debug('wrapping document in HTML structure')
		if $log->is_debug;

	# the new HTML document
	my $dom = XML::ITS::DOM->new('html', \'<!DOCTYPE html><html>');

	# grab the HTML head and paste in the
	# encoding, title, and standoff markup
	my ($head) = $dom->get_root->get_xpath(
		'//html:head',
		namespaces => {html => $HTML_NS}
	);
	my $meta = new_element('meta', { charset => 'utf-8' });
	$meta->paste($head);
	my $title = new_element('title', {}, $self->{title});
	$title->paste($head);

	#paste all standoff markup
	for my $its(@$its_els){
		_get_script($its)->paste($head);
	}

	#paste the doc root into the HTML body
	my ($body) = $dom->get_root->get_xpath(
		'//html:body',
		namespaces => {html => $HTML_NS}
	);
	my $html = $dom->get_root();
	$doc->get_root->paste($body);

	return $dom;
}

# create and return an ITS script element with the input element
# as its contents. The input element id (if there is one)is used
# as the script id.
sub _get_script {
	my ($element) = @_;
	my $script = new_element('script', {type => 'application/its+xml'});
	if(my $id = $element->att('xml:id')){
		$script->set_att('id', $id);
	}

	# we hand-indent the contents of script elements because they are not
	# formatted like the rest of the document
	$script->append_text("\n    ");
	$element->paste($script);
	$script->append_text("\n");
	return $script;
}

# make sure all rule matches are elements, and create new rules that give them
# the same information as in the original document
sub _update_rules {
	my ($self, $matches, $head) = @_;

	# don't do anything if there were no rule matches
	return unless @$matches;

	if($log->is_debug){
		$log->debug('Creating new its:rules element to contain all rules');
	}
	my $rules_el = new_element('its:rules',
		{
			'xmlns:its'	=> its_ns(),
			version 	=> '2.0',
		 }
	);
	# we hand-indent the contents of script elements because they are not
	# formatted like the rest of the document
	my $indent = '  ';#two spaces
	$rules_el->append_text("\n" . $indent x 4);
	my $script = _get_script($rules_el);
	$script->paste($head);

	#create a new rule for each match
	for my $i (0 .. $#$matches){
		my $match = $matches->[$i];
		my ($rule, $futureNodes) = @$match;

		# create a new rule, and set its selectors/pointers to either a
		# FutureNode's element or an XPath literal. value
		my $new_rule = $rule->element->copy(1);
		for my $key(keys %$futureNodes){
			my $futureNode = ${ $futureNodes->{$key} };
			# FutureNode- make it visible in the dom and
			# match the rule selector with its ID
			if((ref $futureNode) =~ /FutureNode/){
				my $el = $futureNode->elemental;
				$new_rule->set_att( $key, q{id('} .
					$self->_get_or_set_id($el). q{')} );
			}else{
				#DOM values- match the rule with the value
				$new_rule->set_att($key, $futureNode->as_xpath);
			}
		}

		if($log->is_debug){
			_log_new_rule($new_rule, $futureNodes);
		}

		$new_rule->paste($rules_el);
		#use more indentation before another rule than at the end
		if($i != $#$matches){
			$rules_el->append_text("\n" . $indent x 3);
		}else{
			$rules_el->append_text("\n" . $indent x 2);
		}
	}
	return;
}

#log the creation of a new rule (given the rule and its associated FutureNodes)
sub _log_new_rule {
	my ($new_rule, $futureNodes) = @_;
	my $string = 'Creating new rule ' . _el_log_id($new_rule) .
		' to match [';
	my @match_strings;
	for my $key(keys %$futureNodes){
		my $futureNode = ${ $futureNodes->{$key} };
		if((ref $futureNode) =~ /FutureNode/){
			push @match_strings, "$key=" .
				 _el_log_id($futureNode->elemental);
		}else{
			push @match_strings, "$key=" . $futureNode->as_xpath;
		}
	}
	$string .= join '; ', @match_strings;
	$string .= ']';
	$log->debug($string);
	return;
}

#returns the id attribute of the given element; creates one if none exists.
sub _get_or_set_id {
	my ($self, $el) = @_;
	my $id = $el->att('id');
	if(!$id){
		$id = $self->_next_id();
		if($log->is_debug){
			$log->debug('Setting id of ' . _el_log_id($el) . " to $id");
		}
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