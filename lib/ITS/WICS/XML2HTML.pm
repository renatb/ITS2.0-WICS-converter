package ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
use XML::Twig;
use Try::Tiny;
# ABSTRACT: Convert ITS-decorated XML into HTML with equivalent markup
# VERSION
# use feature "state";
# use Carp qw(cluck);

#text for html <title> element
our $title = 'WICS';

=head1 METHODS

=head2 C<convert>

Takes a named argument; if C<file>, the value should be the name of an XML file with ITS markup.
If C<string>), the value should be a pointer to a string containing XML with ITS markup.

Returns an XML::Twig::Elt object containing the root of the converted HTML.

=cut

sub convert{
	my %args = @_;
	my $twig;
	#either parse a file or a string using the XML2HTML twig
	if(exists $args{file}){

		unless(-e $args{file}){
			croak "file does not exist: $args{file}";
		}
		$twig = _create_twig();
		try{
			$twig->parsefile( $args{file} );
		} catch {
			warn "error parsing file '$args{file}': $_";
			return undef;
		};

	}elsif(exists $args{string}){
		$twig = _create_twig();
		$twig->parse( ${$args{string}} );
	}else{
		croak 'Need to specify either a file or a string pointer with XML contents';
	}

	_rename_els($twig);
	_make_html($twig);

	_process_rules($twig);

	# move its:rules to head/script here

	return $twig;
}

#Returns an XML::Twig object with proper settings and handlers for converting ITS-decorated XML
#into HTML with equivalent ITS markup.

sub _create_twig {
	my $twig = new XML::Twig(
		empty_tags				=> 'html',
		pretty_print			=> 'indented',
		# keep_original_prefix	=> 1, #maybe; this may be bad because the JS code doesn't process namespaces yet
		output_encoding			=> 'UTF-8',
		do_not_chain_handlers	=> 1, #can be important when things get complicated
		keep_spaces				=> 0,
		map_xmlns				=> {'http://www.w3.org/2005/11/its' => "its"},
		TwigHandlers			=> {
			#leave ITS elements for later
			# 'its:rules'		=> sub {},
			# 'its:rule'		=> sub {},
			qr/its:/		=> sub {},

			_default_		=> \&_choose_name,
			#TODO: fix XPaths
		},
		no_prolog				=> 1,
	);
	return $twig;
}

#rename elements to either span or div, depending on info stored by _choose_name
#save old name in title attribute
#TODO:delete all attributes except ID, xmlns
sub _rename_els {
	my ($twig) = @_;
	for my $el(@{ $twig->{els_to_rename} }){
		my $tag = $el->tag;
		$el->set_att('title', $tag);
		if($twig->{span_list}->{$tag}){
			$el->set_tag('span');
		}else{
			$el->set_tag('div');
		}
	}
}

#add doctype
#put contents into body, and add html, head, and meta elements
sub _make_html {
	my ($twig) = @_;

	$twig->set_doctype('html');

	my $root = $twig->root;
	my $html = $root->wrap_in('body', 'html');
	$html->set_att('xmlns', 'http://www.w3.org/1999/xhtml');
	# https://github.com/mirod/xmltwig/issues/5
	$twig->set_root($html);

	my $head = XML::Twig::Elt->new('head');
	XML::Twig::Elt->new( meta => { charset => 'utf-8' } )->paste('first_child' => $head);
	XML::Twig::Elt->new('title', $title)->paste('first_child' => $head);
	$head->paste(first_child => $html);
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

# move the its:rules element(s) to a script in the head;
# add xmnls:h for XPath matching
# TODO: slurp external rules
sub _process_rules {
	my ($twig) = @_;
	my $head = $twig->root->first_child('head');
	my @rules = $twig->find_nodes('//its:rules');
	@rules = _slurp_external_rules(@rules);
	@rules or carp q{couldn't find any its:rules element};
	for my $rules(@rules){
		$rules->set_att('xmlns:h', 'http://www.w3.org/1999/xhtml');
		my $script = XML::Twig::Elt->new('script', {type=> 'application/its+xml'});
		$rules->cut;
		$rules->paste($script);
		$script->paste(last_child => $head);
	}
}

# find any reference to rules in external files
# slurp those rules and add them to the list
# return the full list of its:rules elements
sub _slurp_external_rules {
	my @rules = @_;

	return @rules;
}

# # slurp external rules;
# sub rules {
# 	my ($twig, $el) = @_;
# }

# sub rule {
# 	my ($twig, $el) = @_;

# }

1;