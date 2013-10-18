use strict;
use warnings;
use Pod::Simple::HTMLBatch;
use FindBin qw($Bin);
use Path::Tiny;
use File::Copy;

my $cwd = path($Bin);
my $proj = $cwd->parent;
#lib and bin contain code with embedded POD
my $lib = path($proj, 'lib');
my $bin = path($proj, 'bin');
my $docs = path($proj, 'docs');

#output in docs/modules
my $out = path($docs, 'modules');
# make sure output directory is clean
if($out->is_dir){
    $out->remove_tree;
}
$out->mkpath;

my $batchconv = Pod::Simple::HTMLBatch->new;
$batchconv->add_css( 'cpanStyle.css', 1, 'cpanStyle');
$batchconv->batch_convert( ["$lib", "$bin", $docs], $out );

#copy the cpanStyle css and the WICS-GUI image into the output directory
my @files = qw(
    cpanStyle.css
    WICS-GUI.png
    WICS-GUI-choose-file.png
    WICS-GUI-logs.png
);

for my $file (@files){
    copy(path($docs, $file), path($out, $file));
}
