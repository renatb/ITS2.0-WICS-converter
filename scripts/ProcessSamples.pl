use strict;
use warnings;
use Test::More 0.88;
use File::Find;
use Path::Tiny;
use File::Spec;
use FindBin qw($Bin);
use File::Path qw(remove_tree);
use Log::Any::Test;
use Log::Any qw($log);
use ITS::WICS qw(
    xml2html
    xliff2html
    reduceHtml
    xml2xliff
);

my $samples_dir = shift
    or die "Usage: perl ProcessSamples.pl C:/path/to/sample/dir";
my $input_dir = path($samples_dir, 'input');
if(!path($input_dir)->is_dir){
    die "directory $input_dir does not exist";
}

my $output_dir = path($samples_dir, 'gen_output');
# make sure the directories are clean every time
if($output_dir->is_dir){
    remove_tree $output_dir;
}

# the current input tree is like so:
# samples
#   input
#     ITS2.0_Test_Suite
#       HTML
#       XLIFF
#       XML
#     WICS_samples
#       HTML-to-HTML
#       XLIFF-to-HTML
#       XML-to-HTML
#       XML-non-elt-matches
#       XML-to-XLIFF
#   output
#     ...

print "reducing HTML5...\n";
find(\&gen_reduceHtml, $input_dir);
print "converting XML to HTML...\n";
find(\&gen_xml2html, $input_dir);
print "converting XML to XLIFF...\n";
find(\&gen_xml2xliff, $input_dir);
print "converting XLIFF to HTML...\n";
find(\&gen_xliff2html, $input_dir);

sub gen_reduceHtml {
    return if $File::Find::name !~ /\.html?$/;
    return if $File::Find::name =~ /standoff/i;
    # there are html files in the XLIFF tests, too
    return if $File::Find::name =~ /XLIFF/i;

    # create destination sub-directory from two deepest
    # directory names
    my @dirs = File::Spec->splitdir(
        $File::Find::dir);
    my $new_dir = path(
        $output_dir, 'html2html', @dirs[-2,-1]);
    $new_dir->mkpath;

    # output files will have the same names as XML originals,
    # (with log extension for logs)
    my $html_file = $_;
    my $log_file = $_;
    $log_file =~ s/\.html?$/.log/;

    # reduce the html and print it into the new directory
    $log->clear();
    my $html_fh = path($new_dir, $html_file)->openw_utf8;
    my $html = reduceHtml($File::Find::name);
    print $html_fh $$html;

    my $log_fh = path($new_dir, $log_file)->openw_utf8;
    print $log_fh "$_->{message}\n"
        for @{ $log->msgs() };
    return;
}

sub gen_xml2html {
    return if $File::Find::name !~ /\.xml$/;
    return if $File::Find::name =~ /rules/i;
    return if $File::Find::name =~ /standoff/i;
    #there are xml files in the XML-to-XLIFF folder, too
    return if $File::Find::name =~ /XLIFF/i;

    # create destination sub-directory from two deepest
    # directory names
    my @dirs = File::Spec->splitdir(
        $File::Find::dir);
    my $new_dir = path(
        $output_dir, 'xml2html', @dirs[-2,-1]);
    $new_dir->mkpath;

    # output files will have the same names as XML originals,
    # but with html or log extensions
    my $html_file = $_;
    $html_file =~ s/\.xml$/.html/;
    my $log_file = $_;
    $log_file =~ s/\.xml$/.log/;

    # convert the XML and print it into the new directory
    $log->clear();
    my $html_fh = path($new_dir, $html_file)->openw_utf8;
    my $html = xml2html($File::Find::name);
    print $html_fh $$html;

    my $log_fh = path($new_dir, $log_file)->openw_utf8;
    print $log_fh "$_->{message}\n"
        for @{ $log->msgs() };
    return;
}

sub gen_xml2xliff {
    return if $File::Find::name =~ /rules/i;
    return if $File::Find::name =~ /standoff/i;
    return if $File::Find::name !~ /\.xml$/;

    # create destination sub-directory from two deepest
    # directory names
    my @dirs = File::Spec->splitdir(
        $File::Find::dir);
    my $new_dir = path(
        $output_dir, 'xml2xliff', @dirs[-2,-1]);
    $new_dir->mkpath;

    # output files will have the same names as XML originals,
    # but with xlf or log extensions
    my $xlf_file = $_;
    $xlf_file =~ s/\.xml$/.xlf/;
    my $log_file = $_;
    $log_file =~ s/\.xml$/.log/;

    # convert the XLIFFand print it into the new directory
    $log->clear();
    my $xlf_fh = path($new_dir, $xlf_file)->openw_utf8;
    my $xlf = xml2xliff($File::Find::name);
    print $xlf_fh $$xlf;

    my $log_fh = path($new_dir, $log_file)->openw_utf8;
    print $log_fh "$_->{message}\n"
        for @{ $log->msgs() };
    return;
}

sub gen_xliff2html {
    return if $File::Find::name =~ /rules/i;
    return if $File::Find::name !~ /\.xlf$/;

    # create destination sub-directory from two deepest
    # directory names
    my @dirs = File::Spec->splitdir(
        $File::Find::dir);
    my $new_dir = path(
        $output_dir, 'xliff2html', @dirs[-2,-1]);
    $new_dir->mkpath;

    # output files will have the same names as XLIFF originals,
    # but with html or log extensions
    my $html_file = $_;
    $html_file =~ s/\.xlf$/.html/;
    my $log_file = $_;
    $log_file =~ s/\.xlf$/.log/;

    # convert the XLIFF (adding labels) and print it
    # into the new directory
    $log->clear();
    my $html_fh = path($new_dir, $html_file)->openw_utf8;
    my $html = xliff2html($File::Find::name);
    print $html_fh $$html;

    my $log_fh = path($new_dir, $log_file)->openw_utf8;
    print $log_fh "$_->{message}\n"
        for @{ $log->msgs() };
    return;
}
