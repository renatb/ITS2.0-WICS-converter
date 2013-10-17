#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS);
use Log::Any qw($log);

use ITS qw(its_ns);
use ITS::DOM;
use ITS::DOM::Element qw(new_element);
use ITS::WICS::FutureNodeManager qw(new_manager);
use ITS::WICS::LogUtils qw(node_log_id log_match log_new_rule);

use feature 'state';
our $HTML_NS = 'http://www.w3.org/1999/xhtml';

# ABSTRACT: Convert ITS-decorated XML into HTML with equivalent markup
our $VERSION = '0.03'; # VERSION

#default: convert and print input
print ${ __PACKAGE__->new()->convert($ARGV[0]) } unless caller;

sub new {
	my ($class, %args) = @_;
	%args = (
		title => 'WICS',
		%args,
	);
	return bless \%args, $class;
}


sub convert {
	my ($self, $ITS) = @_;

	if($ITS->get_doc_type ne 'xml'){
		croak 'Cannot process document of type ' . $ITS->get_doc_type;
	}
	my $dom = $ITS->get_doc;

	if(_is_rules_dom($dom)){
		croak 'Cannot process a file containing only rules. ' .
			'Convert the file which references this file ' .
			'(via xlink:href) instead.';
	}

	#create a futureNodeManager associated with the input document
	$self->{futureNodeManager} =
		new_manager($dom);
	#reset other state
	$self->{matches_index} = [];

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
	my $html_doc = $self->_htmlize($dom);

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
sub _index_match {
	my ($self, $rule, $matches) = @_;
	log_match($rule, $matches, $log);

	# create FutureNodes to represent each matched node;
	# $futureNodes is $match, but with FutureNodes instead of Nodes
	my $futureNodes = {};
	# $name is 'selector', 'locNotePointer', etc.
	for my $name (keys %$matches) {
		my $match = $matches->{$name};
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

# Pass in document to be htmlized
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
	if($el->namespace_URI &&
		$el->namespace_URI eq its_ns() &&
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

	#set the element in the HTML namespace
    $el->set_namespace($HTML_NS);

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
	my @atts = $el->get_xpath('@*');

	#true if this element has been renamed (to 'bdo')
	my $bdo_rename;
	for my $att (@atts){
		my $renamed =
			$self->_process_att($el, $att);
		$bdo_rename ||= $renamed;
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
	# but don't log "renaming span to span" for its:spans!
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

	# xml:* attributes with vaild HTML ITS semantics
	if($att->name eq 'xml:id'){
		_att_rename($el, $att, 'id');
	}elsif($att->name eq 'xml:lang'){
		_att_rename($el, $att, 'lang');
	# (xml:space means nothing in HTML)
	}elsif($att->name eq 'xml:space'){
		_att_delete($el, $att);
	}elsif(
		#its:* attributes with HTML semantics
		$att->namespace_URI eq its_ns() ||
		# this should only be applying to its:span; non-namespace attributes
		# are interpreted as ITS attributes.
		$el->namespace_URI eq its_ns() && !$att->namespace_URI
	){
		if($att->local_name eq 'translate'){
			_att_rename($el, $att, 'translate');
		}elsif($att->local_name eq 'dir'){
			if($att->value =~ /^(?:lro|rlo)$/){
				_process_dir_override($el, $att);
				return 'bdo';
			}else{
				#ltr and rtl are just 'dir' attributes
				_att_rename($el, $att, 'dir');
			}
		#HTML ITS has no version, because HTML5 has no versioning
		}elsif($att->local_name eq 'version'){
			_att_delete($el, $att);
		}else{
			# default transformation for all other its:* atts
			_htmlize_its_att($el, $att);
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

sub _att_delete {
	my ($el, $att) = @_;
	if($log->is_debug){
		$log->debug('removing ' . node_log_id($att) .
			' from ' . node_log_id($el));
	}
	$att->remove;
	return;
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
	my $root = $html_doc->get_root;
	my ($head, $body) = @{ $root->child_els };

	# grab the HTML head and paste in the
	# encoding, title, and standoff markup
	my $meta = new_element('meta', { charset => 'utf-8' });
	$meta->set_namespace($HTML_NS);
	$meta->paste($head);
	my $title = new_element('title', {}, $self->{title});
	$title->set_namespace($HTML_NS);
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
	$script->set_namespace($HTML_NS);
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
# the same information as in the original document. The argument
# is the head element, which the rules element will be pasted in.
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
			'xmlns:h' => $HTML_NS,
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

	$self->_false_elt_inheritance_rules($rules_el, $indent);
	$self->_span_withinText_rule($rules_el, $indent);
	$self->_false_att_inheritance_rules($rules_el, $indent);

	return;
}

sub _span_withinText_rule {
	my ($self, $rules_el, $indent) = @_;

	# in HTML, <span> elements have withinText="yes", the opposite
	# of the default in XML. This doesn't inherit, so it's safe to
	# set it globally here
	my $txt_node = $rules_el->append_text("\n" . $indent x 3, 'first_child');
	my $span_rule = new_element('its:withinTextRule',
		{withinText => 'no', selector => '//h:span'});
	$span_rule->paste($txt_node, 'after');
	if($log->is_debug){
		$log->debug('Creating new rule ' . node_log_id($span_rule) .
			' to set correct withinText default on <span> elements');
	}
	return;
}

# Nodes turned into elements (attributes, namespaces, PIs)
# will incorrectly inherit ITS information.
# Create rules to undo incorrect inheritance for these types
# of nodes, where possible. This is only possible for three
# categories: translate, direction, and localeFilter. The other
# inheriting categories will just be incorrect :(. These
# are langInfo, domain and provenance.
# The resetting can be done via explicit global selection; this is safe
# because none of the selected nodes have child nodes to receive ITS
# inheritance.
sub _false_elt_inheritance_rules {
	my ($self, $rules_el, $indent) = @_;

	# separate elements representing attributes
	# from those representing non-attributes
	my @elementals = $self->{futureNodeManager}->elementals();
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
# The fixable and unfixable categories are the same as in the previous method.
sub _false_att_inheritance_rules {
	my ($self, $rules_el, $indent) = @_;

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

__END__

=pod

=head1 NAME

ITS::WICS::XML2HTML - Convert ITS-decorated XML into HTML with equivalent markup

=head1 VERSION

version 0.03

=head1 SYNOPSIS

    use ITS;
    use ITS::WICS::XML2HTML;
    my $converter = ITS::WICS::XML2HTML->new('Page Title');
    my $ITS = ITS->new('xml', doc => \'<xml>some text</xml>');
    my $result = $converter->convert($ITS);
    print $$result;

=head1 DESCRIPTION

This module creates an HTML5 file out of an XML file. The new file contains
all of the original text, and the text of attributes, with all ITS information
preserved. Attributes, and also namespace declarations and processing
instructions where required by relative selectors, are made into elements
and pasted in the document. They are given the class values of C<_ITS_ATT>,
C<_ITS_NS>, and C<_ITS_PI>, respectively. No styling is added to the document.

The structure of the original document is preserved as faithfully as possible.
Elements are renamed as either C<div> or C<span> and attributes are saved as
children. Global rules and local markup are converted and preserved separately.
The conversion of other types of nodes into elements, and some differences
between information in XML and HTML ITS, necessitates the creation of a few
extra rules.

Sometimes it is impossible to completely faithfully transfer the ITS
information. See the L</CAVEATS> section for more information.

=head1 SEE ALSO

This module relies on the L<ITS> module for processing ITS markup and rules.

The ITS 2.0 specification for XML and HTML5: L<http://www.w3.org/TR/its20/>.

ITS interest group mail archives:
L<http://lists.w3.org/Archives/Public/public-i18n-its-ig/>

=head1 METHODS

=head2 C<new>

Creates a new converter instance. Optional arguments are:

=over 2

=item title

Title to give output HTML document (default is "WICS").

=back

=head2 C<convert>

Converts the document contained in the input L<ITS> object into an HTML
document with equivalent ITS information.

=head1 CAVEATS

The xml:id attribute is preserved as the C<id> attribute in HTML. As no DTDs
or other validating documents are utilized, no other attributes are treated
as an element's unique ID or converted into HTML's <id> attribute.

In the course of conversion, non-element nodes (like attributes) are
pasted as elements so as to be both visible and legal HTML, and new
attributes are also added (`title` and `id`). This unfortunately causes
them to inherit ITS information that does not belong to them. Global rules
are created to reset ITS information to defaults where possible
(`translate`, `direction`, and `localeFilter`). Where there are no defaults
(`langInfo`, `domain` and `provenance`), the newly pasted elements may be
assigned incorrect ITS information.

=head1 TODO

It would be nice if the ITS rules placed in script elements were printed XML style
instead of HTML (using self-ending tags).

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
