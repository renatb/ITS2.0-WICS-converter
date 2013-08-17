package XML::ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(XML::ITS::WICS::XML2HTML XML::ITS::WICS);
use Log::Any qw($log);

use XML::ITS qw(its_ns);
use XML::ITS::DOM;
use XML::ITS::DOM::Element qw(new_element);
use XML::ITS::WICS::XML2HTML::FutureNodeManager;
use XML::ITS::WICS::LogUtils qw(node_log_id get_or_set_id reset_id);

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
		%args,
		futureNodeManager =>
			XML::ITS::WICS::XML2HTML::FutureNodeManager->new()
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
	#new document, so we can create element IDs starting from ITS_1 again
	reset_id();
	# find all rule matches and save them in @matches
	$ITS->iterate_matches($self->_create_indexer(\@matches, $ITS->get_doc));

	# convert $ITS into an HTML document; rename elements, process atts,
	# and paste the root in an HTML body.
	my $html_doc = $self->_htmlize($ITS->get_doc);

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
# This sub pushes matches and FutureNodes onto $index_array
sub _create_indexer {
	my ($self, $index_array, $doc) = @_;

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
			# store futureNode in place of match in new structure
			else{
				$futureNodes->{$name} =
					 $self->{futureNodeManager}->create_future($match, $doc);
			}
		}
		push @{ $index_array }, [$rule, $futureNodes];
		return;
	};
}

sub _log_match {
	my ($rule, $match) = @_;
	if ($log->is_debug()){
		my $message = 'match: rule=' . node_log_id($rule->element);
		$message .= "; $_=" . node_log_id($match->{$_})
			for keys $match;
		$log->debug($message);
	}
	return;
}

# Pass in document to be htmlized and a hash containing node->futureNode ref pairs
# (these are nodes which have been matched by rules; this is needed in case the
# element is replaced because of namespace removal)
sub _htmlize {
	my ($self, $doc) = @_;

	$log->debug('converting document elements into HTML')
		if $log->is_debug;
	# traverse every document element, converting into HTML
	# save standoff or rules elements in its_els
	$self->{its_els} = [];
	# 0 means there is no inline ancestor
	$self->_traverse_convert($doc->get_root, 0);

	# return an HTML doc with the current doc as its body contents
	return $self->_html_structure($doc);
}


# transforms elements into HTML and returns
# true for a child renamed as a div, false otherwise (span or bdo).
# Arguments are the element to transform and a boolean indicating
# the existence of an inline ancestor (so this element should not
# be made a <div>)
sub _traverse_convert{
	my ($self, $el, $inline_ancestor) = @_;

	#its:* elements are either rules, span, or standoff
	#let its:span be renamed to span later
	if($el->namespaceURI &&
		$el->namespaceURI eq its_ns() &&
		$el->local_name ne 'span'){
		#its:rules; just remove these and paste new ones later
		if($el->local_name eq 'rules'){
			$el->remove;
			if($log->is_debug){
				$log->debug('removing ' . node_log_id($el));
			}
			return 0;
		}
		# save standoff markup for pasting in the head
		push @{ $self->{its_els} }, $el;
		if($log->is_debug){
			$log->debug('placing ' . node_log_id($el) . ' in script element');
		}
		return 0;
	}
	if($log->is_debug){
		$log->debug('processing ' . node_log_id($el));
	}

	# true if the element has been renamed to bdo, an
	# inline element (happens with its:dir=rlo)
	my $bdo_rename = $self->_convert_atts($el);

	# strip namespacing; requires special care because it replaces
	# an element, requiring reworking of FutureNode indices
	my $new_el = $el->strip_ns;
	if(!$el->is_same_node($new_el)){
		if($log->is_debug){
			$log->debug('stripping namespaces from ' . node_log_id($el));
		}
		# if this element has an associated future (match), change the future
		# to one for the new node
		$self->{futureNodeManager}->replace_el_future($el, $new_el);
		$el = $new_el;
	}

	# grab children for recursive processing
	my $children = $el->child_els;

	# true if any child is a div
	my $div_child;
	# recursively process children
	for my $child(@$children){
		my $div_result = $self->_traverse_convert(
			$child, $bdo_rename);
		$div_child ||= $div_result;
	}

	#if already renamed to bdo, return indication of inline element
	if($bdo_rename){
		return 0;
	}

	#otherwise rename it and return indication of div or span
	return _rename_el($el, $div_child, $inline_ancestor);
}

#handle all attribute converting for the given element. Return true
#if the element was renamed 'bdo', false if not renamed at all.
sub _convert_atts {
	my ($self, $el) = @_;

	my $title = $el->name;
	my @atts = $el->get_xpath('@*'); #TODO: inline this

	#true if this element has been renamed (to 'bdo')
	my $bdo_rename;
	if(@atts){
		for my $att (@atts){
			my $renamed =
				$self->_process_att($el, $att);
			$bdo_rename ||= $renamed;
		}
	}
	if($log->is_debug){
		$log->debug('setting @title of ' . node_log_id($el) . " to '$title'");
	}
	$el->set_att('title', $title);
	return $bdo_rename;
}

# rename the given element to either div or span; return true for div,
# false for span.
# args: element, boolean for existing block child (div, etc.),
# boolean for existing inline ancestor (span, bdo, etc.)
sub _rename_el {
	my ($el, $div_child, $inline_ancestor) = @_;

	my $new_name;
	#true if element was its:span
	my $its_span = $el->att('title') =~ m/^its:span(?:\[|$)/;

	# if a child is a div, $el has to be a div
	if($div_child){
		$new_name = 'div';
		if($its_span && $log->is_warn){
			$log->warn('its:span converted to div due to div child');
		}
	# its:spans must be inline (conformance clause 1-4)
	}elsif($its_span){
		$new_name = 'span';
	# if an ancestor was a span/bdo, $el has to be a span
	}elsif($inline_ancestor){
		$new_name = 'span';
	# inline elements become spans
	}elsif($el->is_inline){
		$new_name = 'span';
	# other elements become divs
	}else{
		$new_name = 'div';
	}
	# log element rename,
	# but log "renaming span to span" for its:spans!
	if($log->is_debug && !($new_name eq 'span' && $its_span)){
		$log->debug('renaming ' . node_log_id($el) . " to <$new_name>");
	}

	$el->set_name($new_name);
	return $new_name eq 'div' ? 1 : 0;
}

# process given attribute on given element;
# return the name of the element used to wrap the children, if any.
sub _process_att {
	my ($self, $el, $att) = @_;

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
				return 'bdo';
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
		# save other atts as FutureNodes, then delete
		# (they are illegal in HTML)
		$self->{futureNodeManager}->create_future($att);
		$att->remove;
	}

	return;
}

#rename given att on given el to new_name.
sub _att_rename {
	my ($el, $att, $new_name) = @_;
	if($log->is_debug){
		$log->debug('renaming @' . $att->name . ' of ' . node_log_id($el) .
			" to \@$new_name");
	}
	#have to replace with new att because renaming doesn't work with namespaces
	$el->set_att($new_name, $att->value);
	$att->remove;
}

# process an element with an att which is its:dir=lro or rlo;
# this requires renaming the element to 'bdo' in HTML.
sub _process_dir_override {
	my ($el, $att) = @_;

	my $dir = $att->value eq 'lro' ?
		'ltr':
		'rtl';
	if($log->is_debug){
		$log->debug('found ' . $att->name . '=' .
		 	$att->value . '; renaming ' . node_log_id($el) .
			" to bdo and adding \@dir=$dir");
	}
	#inline bdo element
	$el->set_name('bdo');
	$el->set_att(dir => $dir);
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
		node_log_id($el) . " with $name");
	}
	$att->remove;
	return;
}

# Create and return an HTML document with the input doc's root element
# inside of the body. Create script elements for each el in $its_els
# and paste them in the head
sub _html_structure {
	my ($self, $doc) = @_;

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
	for my $its(@{ $self->{its_els} }){
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

	#cause all DOM changes to occur
	$self->{futureNodeManager}->realize_all;

	# nothing else to do if there were no FutureNodes
	return unless $self->{futureNodeManager}->total_futures;

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
	$rules_el->append_text("\n" . $indent x 3);
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
				$new_rule->set_att($key, $futureNode->new_path);
			}else{
				# DOM values (not a FutureNode object)
				# match the rule with the literal value
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

	$self->_false_inheritance_rules($rules_el, $indent);

	return;
}

# Nodes turned into elements (attributes, namespaces, PIs)
# will incorrectly inherit much ITS info.
# Create rules to undo incorrect inheritance for these types
# of nodes, where possible. This is only possible for three
# categories: translate, direction, and localeFilter
sub _false_inheritance_rules {
	my ($self, $rules_el, $indent) = @_;

	my @att_ids =
		map {${$_}->new_path} $self->{futureNodeManager}->att_futures();
	my @non_att_ids =
		map {${$_}->new_path} $self->{futureNodeManager}->non_att_futures();
	if(@att_ids or @non_att_ids){
		my $txt_node = $rules_el->append_text("\n" . $indent x 3, 'first_child');
		my $selector = join '|', @att_ids, @non_att_ids;
		# don't translate anything (including attributes by default)
		my $new_rule = new_element('its:translateRule', {translate => 'no', selector => $selector});
		$new_rule->paste($txt_node, 'after');
		if($log->is_debug){
			$log->debug('Creating new rule ' . node_log_id($new_rule) .
				' to prevent false inheritance');
		}
	}
	if(@non_att_ids){
		#for non-attributes, reset direction and localeFilter
		my $selector = join '|', @non_att_ids;

		my $txt_node = $rules_el->append_text("\n" . $indent x 3, 'first_child');
		my $new_rule = new_element(
			'its:dirRule', {dir => 'ltr', selector => $selector});
		$new_rule->paste($txt_node, 'after');
		if($log->is_debug){
			$log->debug('Creating new rule ' . node_log_id($new_rule) .
				' to prevent false inheritance');
		}

		$txt_node = $new_rule->append_text("\n" . $indent x 3, 'after');
		$new_rule = new_element(
			'its:localeFilterRule', {
				localeFilterList => '*',
				localeFilterType => 'include',
				selector => $selector
			}
		);
		$new_rule->paste($txt_node, 'after');
		if($log->is_debug){
			$log->debug('Creating new rule ' . node_log_id($new_rule) .
				' to prevent false inheritance');
		}
	}
}

#log the creation of a new rule (given the rule and its associated FutureNodes)
sub _log_new_rule {
	my ($new_rule, $futureNodes) = @_;
	my $string = 'Creating new rule ' . node_log_id($new_rule) .
		' to match [';
	my @match_strings;
	for my $key(keys %$futureNodes){
		my $futureNode = ${ $futureNodes->{$key} };
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

1;