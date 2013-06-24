package ITS::WICS::XML2HTML;
use strict;
use warnings;
use Carp;
our @CARP_NOT = qw(ITS::WICS::XML2HTML);
use XML::Twig;
use XML::Twig::XPath;
use Path::Tiny;
use Try::Tiny;
use feature 'say';

# ABSTRACT: Convert ITS-decorated XML into HTML with equivalent markup
# VERSION

convert(file => $ARGV[0]) unless caller;

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

	my $rules = _get_rules($twig, path($args{file}) || '.');
	say scalar @$rules;
	say $_->att('xml:id') for @$rules;
	exit;

	####HERE

	# my $pointer_index = _apply_rules($twig, $its_rules, {});

	# # _apply_rules($twig, $args{file} || getcwd);

	# _rename_els($twig);
	# _make_html($twig);
	# # move its:rules to head/script here

	# return $twig;
}

#Returns an XML::Twig object with proper settings and handlers for converting ITS-decorated XML
#into HTML with equivalent ITS markup.

sub _create_twig {
	my $twig = new XML::Twig(
		empty_tags				=> 'html',
		pretty_print			=> 'indented',
		output_encoding			=> 'UTF-8',
		keep_spaces				=> 0,
		map_xmlns				=> {
			'http://www.w3.org/2005/11/its' => 'its',
			'http://www.w3.org/1999/xlink' => 'xlink'
		},
		no_prolog				=> 1,
		#can be important when things get complicated
		do_not_chain_handlers	=> 1,
	);
	return $twig;
}

# return all its:*Rule's elements to be applied to the
# given twig, in order of application
# $file should be the path of the file that is being read
# (a Path::Tiny object)
#
sub _get_rules {
	my ($twig, $file) = @_;

	# first, grab internal its:rules elements
	my @rule_containers;
	my @internal_rules_containers = $twig->get_xpath('//its:rules');
	if(@internal_rules_containers == 0){
		carp "file $file contains no its:rules elements!";
		return [];
	}

	# then store their rules, placing external file rules before internal ones
	my @rules;
	for my $container(@internal_rules_containers){
		if($container->att('xlink:href')){
			#path to file is relative to current file
			my $path = path($container->att('xlink:href'))->
				absolute($file->parent);
			push @rules, @{ _get_external_rules($path) };
		}
		push @rules, $container->children;
	}

	if(@rules == 0){
		carp "no rules found in $file";
	}
	return \@rules;
}

# return list of its:*Rule's, in application order, given the name of a file
# containing an its:rules element
sub _get_external_rules {
	my ($path) = @_;
	my $twig = _create_twig();
	$twig->parsefile($path);
	return _get_rules($twig, $path);
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

1;