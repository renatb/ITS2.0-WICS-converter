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

	_make_html($twig);
	# move its:rules to head/script here

	return $twig;
}

#add doctype
#put contents into body, and add html, head, and meta elements
#TODO: add title
sub _make_html {
	my ($twig) = @_;

	$twig->set_doctype('html');

	my $root = $twig->root;
	my $html = $root->wrap_in('body', 'html');
	# https://github.com/mirod/xmltwig/issues/5
	$twig->set_root($html);

	my $head = XML::Twig::Elt->new('head');
	XML::Twig::Elt->new( meta => { charset => 'utf-8' } )->paste('first_child' => $head);
	$head->paste(first_child => $html);
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
			'its:rules'		=> \&rules,
			'its:rule'		=> \&rule,
			_default_		=> \&htmlize,
			#TODO: fix XPaths
		},
		no_prolog				=> 1,
	);

	return $twig;
}

#convert into a span or a div
#decided by whether first encounter has a sibling with something besides whitespace in it.
#store old tag name in title attribute
sub htmlize {
	my ($twig, $el) = @_;
	$el->set_att('title', $el->tag);
	my $new_name = $twig->{span_div_table}->{$el->tag};
	if(!$new_name){
		#decide span or div...
		my $prev = $el->prev_sibling;
		my $next = $el->next_sibling;
		if( ($prev && $prev->tag() eq '#PCDATA') ||
			($next && $next->tag() eq '#PCDATA') ){
			$twig->{span_div_table}->{$el->tag} = 'span';
			$new_name = 'span';
		}else{
			$twig->{span_div_table}->{$el->tag} = 'div';
			$new_name = 'div';
		}
		$el->set_tag($new_name);
		1;
	}
}

# slurp external rules;
sub rules {
	my ($twig, $el) = @_;
}

sub rule {
	my ($twig, $el) = @_;

}

1;