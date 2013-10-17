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

#output in docs/modules
my $out = path($proj, 'docs', 'modules');
# make sure output directory is clean
if($out->is_dir){
    $out->remove_tree;
}
$out->mkpath;

#copy the cpanStyle css into the output directory
copy(path($Bin, 'cpanStyle.css'), path($out, 'cpanStyle.css'));

my $batchconv = Pod::Simple::HTMLBatch->new;
$batchconv->add_css( 'cpanStyle.css', 1, 'cpanStyle');
$batchconv->batch_convert( ["$lib", "$bin"], $out );
