# reduce HTML input data in the ITS 2.0 test suite
# and check the validity of the output with
# the validator service.
# This test is skipped if the ITS_20_TESTSUITE_PATH
# environment variable is not set to the root directory
# of a copy of the ITS 2.0 test suite.
# The HTML5 validator is http://validator.w3.org/nu/ by
# default, but can be changed via the HTML5_VALIDATOR_URL
# environment variable.

use strict;
use warnings;
use Test::More 0.88;
use File::Find;
use Path::Tiny;
use FindBin qw($Bin);
use File::Path qw(remove_tree);
use HTTP::Message;
use LWP::UserAgent;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use HTML::HTML5::Parser;
use Log::Any::Test;
use Log::Any qw($log);
use ITS;
use ITS::WICS::Reduce qw(reduce);

if ( not $ENV{ITS_20_TESTSUITE_PATH}) {
    plan skip_all => 'Requires ITS 2.0 test suite. ' .
    'Set $ENV{ITS_20_TESTSUITE_PATH} to run.';
}

my $input_dir = path($ENV{ITS_20_TESTSUITE_PATH},
    'its2.0', 'inputdata');

my $validator_url = $ENV{HTML5_VALIDATOR_URL} ||
    'http://validator.w3.org/nu/';

# create a clean place to put converted HTML files
my $output_dir = path($Bin, 'testsuite_html');
if(-d $output_dir){
    remove_tree $output_dir;
}
mkdir $output_dir;

# convert all XML files into HTML;
# count them so a plan can be formed
my $file_count = 0;
note "Generating HTML files from inpudata folder\n";
find(\&convert, $input_dir);

plan tests => $file_count;

# create objects necessary for using the validator service
# and parsing the returned content
my $ua = LWP::UserAgent->new;
# allow redirects for our application
push @{ $ua->requests_redirectable }, 'POST';
my $can_accept = HTTP::Message::decodable;
my $parser = HTML::HTML5::Parser->new;
# check all of the files with the validator service
note "Validating all produced HTML with $validator_url";
find(\&validate, $output_dir);

# convert the XML file and store it in $output_dir, along with the
# conversion log
sub convert {
    return unless $File::Find::name =~ m!/html/[^/.]+html\.html$!;
    $file_count++;
    $log->clear();

    # create destination sub-directory
    $File::Find::dir =~ m!/([^/]+)/html!;
    my $sub_dir = $1;
    mkdir path($output_dir, $sub_dir)
        unless -d path($output_dir, $sub_dir);

    # output files will have the same names as HTML originals,
    # but logs will have 'log' extension
    my $output_file = $_;
    my $log_file = $_;
    $log_file =~ s/\.html$/.log/;

    # convert the XML and print it into the new directory
    my $output_fh = path($output_dir, $sub_dir, $output_file)->openw_utf8;

    my $ITS = ITS->new('html', doc => $File::Find::name);
    reduce($ITS);
    print $output_fh $ITS->get_doc->string;

    my $log_fh = path($output_dir, $sub_dir, $log_file)->openw_utf8;
    print $log_fh "$_->{message}\n"
        for @{ $log->msgs() };
}

#validate each file using the validator service
sub validate {
    return unless $File::Find::name =~ m!\.html$!;
    # save some bandwidth by gzipping contents, and allowing
    # validator service to return gzipped contents.
    my $content;
    gzip $File::Find::name => \$content
        or die "gzip failed: $GzipError\n";
    my $response = $ua->post('http://validator.w3.org/nu/',
        'Accept-Encoding' => $can_accept,
        'Content-Type' => 'text/html',
        'Content-Encoding' => 'gzip',
        'Content-Length' => length($content),
        'Content' => $content,
    );
    if ($response->is_success) {
        my $string = $response->decoded_content;
        # simple regex to find a success message box
        if ($string =~ m/<p\s+class\s*=\s*"success"/i){
            pass($_);
        }else{
            # parse the error messages out of the returned HTML
            fail($_);
            my $doc = $parser->parse_string($string);
            my $xpc = XML::LibXML::XPathContext->new($doc);
            $xpc->registerNs('h', 'http://www.w3.org/1999/xhtml');
            for my $el($xpc->findnodes('//h:li[@class="error"]/h:p[1]')){
                diag $el->toString(1,'utf-8');
            }
        }
    }
    else {
        fail($_);
        diag $response->status_line;
    }
}
