package ITS::XLIFF2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS);
use Log::Any qw($log);

use ITS qw(its_ns);
use ITS::Rule;
use ITS::DOM;
use ITS::DOM::Element qw(new_element);
use ITS::XLIFF2HTML::FutureNodeManager qw(new_manager);
use ITS::XLIFF2HTML::LogUtils qw(node_log_id log_match log_new_rule);

use feature 'state';
our $HTML_NS = 'http://www.w3.org/1999/xhtml';
my $ITSXLF_NS = 'http://www.w3.org/ns/its-xliff/';
my $XLF_NS = 'urn:oasis:names:tc:xliff:document:1.2';
my @inline_els = qw(g x bx ex bpt ept sub it ph mrk);

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
	);

	my $self = bless \%args, $class;

	#this is used when creating new rules out of local XLIFF ITS markup
	$self->{dummy_container} = ITS::RuleContainer->new(
		new_element( 'rules', {}, undef, its_ns() )
	);
	return $self;
}

=head2 C<convert>

Converts the input XML document into an HTML document equivalent, and
displayable, HTML.

The first argument is either a string containing an XML file name, a string
pointer containing actual XML data, or a filehandle for a file containing
the data.

The second argument is a boolean, true if informative warning labels should
be added to the output. These are small snippets of text to point out the
presence of 1) empty C<target> elements or 2) C<target> elements which are
exact copies of their C<source> element and also have the same ITS markup
(the first step to translating an XLIFF document is often to copy the C<source>
into the C<target>, and this label might help the user remember to translate
it).

Th return value is a string pointer containing the output HTML string.

=cut

sub convert {
	my ($self, $doc_data, $add_labels) = @_;

	#create the document from the input data
	my $ITS = ITS->new('xml', doc => $doc_data);
	my $dom = $ITS->get_doc;

	if(_is_rules_dom($dom)){
		croak 'Cannot process a file containing only rules. ' .
			'Convert the file which references this file ' .
			'(via xlink:href) instead.';
	}

	#create a futureNodeManager associated with the input document
	$self->{futureNodeManager} =
		new_manager($dom);

	#iterate all document rules and their matches, indexing each one
	for my $rule (@{ $ITS->get_rules }){
		# process if compatible with HTML
		if($rule->type ne 'preserveSpace'){
			my $matches = $ITS->get_matches($rule);
			$self->_index_match($rule, $_) for @$matches;
		# otherwise, log the removal
		}else{
			$log->debug('removed ' . node_log_id($rule->element));
		}
	}

	# convert $ITS into an HTML document; rename elements, process atts,
	# and paste the root in an HTML body.
	my $html_doc = $self->_htmlize($dom, $add_labels);

	if($add_labels){
		$self->_add_labels($html_doc);
	}

	#grab the head to put rules in it
	my $head = ( $html_doc->get_root->children )[0];
	# paste FutureNodes and create new rules to match them
	$self->_update_rules($head);

	# return string pointer
	return \($html_doc->string);
}

# returns true if the root of the given document is an its:rules element
sub _is_rules_dom {
	my ($dom) = @_;
	my $root = $dom->get_root;
	if($root->namespace_URI eq its_ns() &&
		$root->local_name eq 'rules'){
		return 1;
	}
	return;
}

# index a single set of rule matches
# This sub pushes matches and FutureNodes onto $self->{matches_index} like so:
# [rule, {selector => futureNode, *pointer => futureNode...}]
sub _index_match{
	my ($self, $rule, $matches) = @_;
	log_match($rule, $matches, $log);

	# create FutureNodes to represent each matched node;
	# $futureNodes is $match, but with FutureNodes instead of Nodes
	my $futureNodes = {};
	# $name is 'selector', 'locNotePointer', etc.
	while (my ($name, $match) = each %$matches) {
		# nothing special for literal values
		if((ref $match) =~ /Value$/){
			$futureNodes->{$name} = $match;
		}
		# store futureNode in place of match in new structure
		else{
			$futureNodes->{$name} =
				 $self->{futureNodeManager}->create_future($match);
		}
	}
	push @{ $self->{matches_index} }, [$rule, $futureNodes];
	return;
}

# Pass in document to be htmlized and a boolean indicating
# if labels should be applied
sub _htmlize {
	my ($self, $doc) = @_;

	$log->debug('converting document elements into HTML')
		if $log->is_debug;
	# traverse every document element, converting into HTML
	# save standoff or rules elements in its_els
	$self->{its_els} = [];
	$self->_traverse_convert($doc->get_root);

	# return an HTML doc with the current doc as its body contents
	return $self->_html_structure($doc);
}


# transforms elements into HTML and returns
# Argument is the element to transform
sub _traverse_convert{
	my ($self, $el) = @_;

	#its:* elements are either rules or standoff
	if($el->namespace_URI &&
		$el->namespace_URI eq its_ns()){
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

	# check all of the atts for ITS data and delete the others
	$self->_convert_atts($el);
	# convert child <note> elements into ITS localizaton notes
	$self->_convert_note($el);
	# set its-within-text value
	$self->_set_within_text($el);

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

	# recursively process children
	for my $child(@$children){
		$self->_traverse_convert($child);
	}

	#set the element in the HTML namespace
    $el->set_namespace('http://www.w3.org/1999/xhtml');

	_rename_el($el);
	return;
}

#handle all attribute converting for the given element. Return true
#if the element was renamed 'bdo', false if not renamed at all.
sub _convert_atts {
	my ($self, $el) = @_;

	my $title = $el->name;
	my @atts = $el->get_xpath('@*');

	for my $att (@atts){
		$self->_process_att($el, $att);
	}
	if($log->is_debug){
		$log->debug('setting @title of ' . node_log_id($el) . " to '$title'");
	}
	$el->set_att('title', $title);
	return;
}

#<note> elements are converted into its-loc-note
sub _convert_note {
	my ($self, $el) = @_;
	my $notes = $el->child_els('note');
	for my $note (@$notes){
		my $annotates = $note->att('annotates') || 'general';
		my $priority = $note->att('priority') || '1';
		#the element to be given a note
		my $noted_el;
		if($annotates eq '' or $annotates eq 'general'){
			$noted_el = $el;
		}
		if($annotates eq 'target'){
			if(my ($target) = @{$el->child_els('target')}){
				$noted_el = $target;
			}else{
				$log->warn('Element ' . node_log_id($note) .
					q< annotates target, but target doesn't exist.>);
				next;
			}
		}
		if($annotates eq 'source'){
			# for a valid document this should never be false; just being
			# safe here
			if(my ($source) = @{$el->child_els('source')}){
				$noted_el = $source;
			}else{
				$log->warn('Element ' . node_log_id($note) .
					q< annotates source, but source doesn't exist.>);
				next;
			}
		}
		$noted_el->set_att('its-loc-note', $note->text);
		$noted_el->set_att('its-loc-note-type',
			$priority > 1 ? 'description' : 'alert');
	}
	return;
}

# set its-within-text value to 'nested' for <sub> elements
sub _set_within_text {
	my ($self, $el) = @_;

	if($el->namespace_URI eq $XLF_NS and
			$el->local_name eq 'sub'){
		$el->set_att('its-within-text', 'nested');
	}
	return;
}

# rename the input element to something in HTML
sub _rename_el {
	my ($el, $div_child) = @_;

	# note: we're not checking namespace here. Hopefully noone puts a
	# source or target element from a different namespace into their XLIFF doc!
	my $old_name = $el->name;
	my $new_name;
	if($old_name =~ m/^(?:source|target)$/){
		$new_name = 'p';
	}elsif(grep {$old_name eq $_} @inline_els){
		$new_name = 'span';
	}else{
		$new_name = 'div';
	}

	# log element rename
	if($log->is_debug){
		$log->debug('renaming ' . node_log_id($el) . " to <$new_name>");
	}

	$el->set_name($new_name);
	return;
}

# process given attribute on given element;
# return the name of the element used to wrap the children, if any.
sub _process_att {
	my ($self, $el, $att) = @_;

	my $name = $att->name;
	#an its-* HTML attribute that was already created
	if(index($name, 'its-') == 0){
		return;
	}elsif($name eq 'translate'){
		_att_rename($el, $att, 'translate');
	# mtype give translate and term values
	}elsif($name eq 'mtype'){
		my $value = $att->value;
		if($value eq 'protected'){
			$el->set_att('translate', 'no');
		}elsif($value eq 'x-its-translate-yes'){
			$el->set_att('translate', 'yes');
		}elsif($value eq 'term'){
			$att->remove;
			$el->set_att('its-term', 'yes');
		}elsif($value eq 'x-its-term-no'){
			$att->remove;
			$el->set_att('its-term', 'no');
		}
		$att->remove;
	}elsif($name eq 'comment'){
		_att_rename($el, $att, 'its-loc-note');
	#itsxlf:* atts are all ITS
	}elsif($att->namespace_URI eq $ITSXLF_NS){
		my $name = $att->local_name;
		#TODO: this might get to be simplified
		if($name eq 'domains'){
			$self->_add_new_rule_match('domain',
				{selector => $el, domainPointer => $att});
			$att->remove;
		}elsif($name eq 'externalResourceRef'){
			$self->_add_new_rule_match('externalResourceRef',
				{selector => $el, externalResourceRefPointer => $att});
			$att->remove;
		#all other known itsxlf atts translate directly into HTML ITS atts
		}else{
			_htmlize_its_att($el, $att);
		}
	#its:* atts
	}elsif( $att->namespace_URI eq its_ns() ){
		_htmlize_its_att($el, $att);
	}elsif($name eq 'resname'){
		$self->_add_new_rule_match('idValue',
			{
				selector => $el,
				#create an ITS::DOM::Value consisting of the att value
				idValue => $att->get_xpath(q<'> . $att->value . q<'>)
			});
		$att->remove;
	# xml:* attributes with vaild HTML ITS semantics
	}elsif($name eq 'xml:id'){
		_att_rename($el, $att, 'id');
	}elsif($name eq 'xml:lang'){
		_att_rename($el, $att, 'lang');
	}else{
		# delete other attributes (they are illegal in HTML and we
		# don't care about the contents)
		$att->remove;
	}
	return;
}

# Creates a new global rule with the given match.
# This is for when a local attribute in XLIFF maps only to a global rule
# in HTML. $type is the type of rule to be created. $match should be in
# the same structure returned by ITS::get_matches.
sub _add_new_rule_match {
	my ($self, $type, $match) = @_;
	my $rule_el = new_element(
		"${type}Rule",
		{selector => 'dummy'},
		undef,
	);
	$rule_el->set_namespace( its_ns(), 'its' );
	my $rule = ITS::Rule->new($rule_el, $self->{dummy_container});
	$self->_index_match($rule, $match);
	return;
}

#rename given att on given el to new_name.
sub _att_rename {
	my ($el, $att, $new_name) = @_;
	#return immediately if the att will not really be renamed
	return if($new_name eq $att->name);
	if($log->is_debug){
		$log->debug('renaming ' . node_log_id($att) . ' of ' . node_log_id($el) .
			" to \@$new_name");
	}
	#must save value and remove att for set_att to work properly with xml:id
	my $value = $att->value;
	$att->remove;
	#put att into empty namespace
	$el->set_att($new_name, $value, '');
	return;
}

# convert a given its or itsxlf att into an HTML one by replacing
# caps with dashes and appending its- on the front.
sub _htmlize_its_att {
	my ($el, $att) = @_;

	my $name = $att->local_name;
	$name =~ s/([A-Z])/-\L$1/g;
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
	my ($self, $xml_doc) = @_;

	$log->debug('wrapping document in HTML structure')
		if $log->is_debug;

	my $html_doc = ITS::DOM->new(
		'html', \'<!DOCTYPE html><html>');
	# we remove the XHTML namespace because it is unused in HTML5, and
	# we want it clear that all of our XPathing is in the default
	# namespace.
	my $root = $html_doc->get_root;
	my ($head, $body) = @{ $root->child_els };

	# grab the HTML head and paste in the
	# encoding, title, and standoff markup
	my $meta = new_element('meta', { charset => 'utf-8' });
	$meta->set_namespace('http://www.w3.org/1999/xhtml');
	$meta->paste($head);
	my $title = new_element('title', {}, $self->{title});
	$title->set_namespace('http://www.w3.org/1999/xhtml');
	$title->paste($head);

	#paste all standoff markup
	for my $its(@{ $self->{its_els} }){
		_get_script($its)->paste($head);
	}

	#paste the doc root into the HTML body
	$xml_doc->get_root->paste($body);

	return $html_doc;
}

# create and return an ITS script element with the input element
# as its contents. The input element id (if there is one)is used
# as the script id.
sub _get_script {
	my ($element) = @_;
	my $script = new_element('script', {type => 'application/its+xml'});
	$script->set_namespace('http://www.w3.org/1999/xhtml');
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

# add warning labels where applicable (empty or duplicate targets)
# return an array pointer containing the new elements created
sub _add_labels {
	my ($self, $doc) = @_;
	my $new_els = [];
	my $root = $doc->get_root;
	for my $trans_unit ($root->get_xpath('//*[@title="trans-unit"]')){
		my ($target) = $trans_unit->get_xpath('*[@title="target"]');
		if($target && $target->text eq ''){
			push @$new_els, $self->_new_label($trans_unit,
				'Target is empty', 'ITS_EMPTY_TARGET');
		}
	}
	return $self->{label_futures} = $new_els;
}

# create a new label element given the trans-unit element to label, the
# label text, and a class to assign (besides ITS_LABEL, which is applied
# to all labels)
# Return a FutureNode for the label element
sub _new_label {
	my ($self, $trans_unit, $label, $class) = @_;
	my $el = new_element('p', {class => "ITS_LABEL $class"}, $label);
	$el->set_namespace($HTML_NS);
	$el->paste($trans_unit, 'first_child');

	my $future = $self->{futureNodeManager}->create_future($el);

	return $future;
}

# make sure all rule matches are elements, and create new rules that give them
# the same information as in the original document
sub _update_rules {
	my ($self, $head) = @_;
	my $matches = $self->{matches_index};

	#cause all DOM changes to occur
	$self->{futureNodeManager}->realize_all;

	if($log->is_debug){
		$log->debug('Creating new its:rules element to contain all rules');
	}
	my $rules_el = new_element('its:rules',
		{
			'xmlns:its'	=> its_ns(),
			'xmlns:h' => 'http://www.w3.org/1999/xhtml',
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

		# Remove the pointer atts for now; the ones that actually matched
		# will be set again later. This prevents ones that didn't match
		# from being left with their original, now meaningless, values.
		$rule->element->remove_att($_)
			for @{ $rule->pointers };

		# create a new rule, and set its selectors/pointers to either a
		# FutureNode's element or an XPath literal. value
		my $new_rule = $rule->element->copy(1);
		for my $key(keys %$futureNodes){
			my $futureNode = $futureNodes->{$key};
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
			log_new_rule($new_rule, $futureNodes, $log);
		}

		$new_rule->paste($rules_el);
		#use more indentation before another rule than at the end
		if($i != $#$matches){
			$rules_el->append_text("\n" . $indent x 3);
		}else{
			$rules_el->append_text("\n" . $indent x 2);
		}
	}

	#add new rules as the transformation required
	$self->_source_target_rule($rules_el, $indent);
	$self->_false_elt_inheritance_rules($rules_el, $indent);
	$self->_false_att_inheritance_rules($rules_el, $indent);

	return;
}

# create a single global rule to match sources and
# targets to each other via a targetPointerRule
sub _source_target_rule {
	my ($self, $rules_el, $indent) = @_;
	my $txt_node = $rules_el->append_text("\n" . $indent x 3, 'first_child');
	my $target_rule = new_element(
		'its:targetPointerRule',
		{
			selector => q<//*[@title='source']>,
			targetPointer => q<../*[@title='target']>
		}
	);
	$target_rule->paste($txt_node, 'after');
	if($log->is_debug){
		$log->debug('Creating new rule ' . node_log_id($target_rule) .
			' to match convert <source> and <target> elements');
	}
	return;
}

# New elements in the document will incorrectly inherit
# ITS not meant for them. The elements are those created
# from other types of nodes (atts, namespace, PIs, etc.),
# and also those added as information labels.
# Create rules to undo incorrect inheritance for these elements,
# where possible. This is only possible for three ITS
# categories: translate, direction, and localeFilter. The other
# inheriting categories will just be incorrect :(. These
# are langInfo, domain and provenance, and they cannot be fixed because
# they have no default value to reset to.
# The resetting can be done via explicit global selection; this is safe
# because none of the selected nodes have child nodes to be influenced
# via inheritance.
sub _false_elt_inheritance_rules {
	my ($self, $rules_el, $indent) = @_;

	# separate elements representing attributes
	# from those representing non-attributes
	my @elementals = $self->{futureNodeManager}->elementals();

	# add the label futures to the list of new elements
	push @elementals, @{$self->{label_futures}};
	my (@att_paths, @non_att_paths);
	for my $future (@elementals){
		$future->type eq 'ATT' ?
			push @att_paths, $future->new_path :
			push @non_att_paths, $future->new_path;
	}
	# Then create a rule to make each of these elements untranslatable
	if(@elementals){
		my $txt_node = $rules_el->append_text("\n" . $indent x 3, 'first_child');
		my $selector = join '|', @att_paths, @non_att_paths;
		my $new_rule = new_element('its:translateRule', {translate => 'no', selector => $selector});
		$new_rule->paste($txt_node, 'after');
		if($log->is_debug){
			$log->debug('Creating new rule ' . node_log_id($new_rule) .
				' to prevent false inheritance');
		}
	}
	# Finally, if any do not represent attributes, create rules to set default
	# values for direction and localeFilter
	if(@non_att_paths){
		my $selector = join '|', @non_att_paths;

		my $txt_node = $rules_el->append_text("\n" .
			$indent x 3, 'first_child');
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
	return;
}

# same as the method above, but for attributes added to the document
# (id, title). The resetting can be done via explicit global selection;
# this is safe because none of the selected nodes have child nodes to
# receive ITS inheritance, and any ITS information is applied via a later
# global rule, which would overwrite these.
sub _false_att_inheritance_rules {
	my ($self, $rules_el, $indent) = @_;

	#first set defaults for attributes
	my $selector = '//@*';
	my $rules = [
		#inherits in HTML, but not in XML
		['its:translateRule' => {translate => 'no', selector => $selector}],
		['its:dirRule' => {dir => 'ltr', selector => $selector}],
		['its:localeFilterRule' =>
			{
				localeFilterList => '*',
				localeFilterType => 'include',
				selector => $selector
			}
		]
	];
	for my $rule (@$rules){
		my $txt_node = $rules_el->append_text("\n" . $indent x 3, 'first_child');
		my $new_rule = new_element($rule->[0], $rule->[1]);
		$new_rule->paste($txt_node, 'after');
		if($log->is_debug){
			$log->debug('Creating new rule ' . node_log_id($new_rule) .
				" to reset $rule->[0] on new attributes");
		}
	}
	return;
}

1;

=head1 CAVEATS

The xml:id attribute is preserved as the C<id> attribute in HTML. As no DTDs
or other validating documents are utilized, no other attributes are treated
as an element's unique ID or converted into HTML's <id> attribute.

=head1 C<TODO>

It would be nice if the ITS rules placed in script elements were printed XML style
instead of HTML (using self-ending tags).
