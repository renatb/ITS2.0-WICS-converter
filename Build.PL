
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Work with ITS-decorated documents",
  "dist_author" => [
    "Nathan Glenn <garfieldnate\@gmail.com>"
  ],
  "dist_name" => "ITS-WICS",
  "dist_version" => "0.02",
  "license" => "perl",
  "module_name" => "ITS::WICS",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Data::Dumper" => 0,
    "Encode" => 0,
    "Exporter::Easy" => 0,
    "Getopt::Lucid" => 0,
    "HTML::HTML5::Parser" => 0,
    "HTML::HTML5::Writer" => 0,
    "List::MoreUtils" => 0,
    "Log::Any" => 0,
    "Log::Any::Adapter" => 0,
    "Log::Any::Adapter::Base" => 0,
    "Log::Any::Adapter::Util" => 0,
    "Path::Tiny" => 0,
    "Try::Tiny" => 0,
    "URI" => 0,
    "Wx" => 0,
    "Wx::Perl::Packager" => 0,
    "XML::LibXML" => 0,
    "autodie" => 0,
    "base" => 0,
    "feature" => 0,
    "parent" => 0,
    "perl" => "5.014",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [
    "bin/WICS-GUI.pl",
    "bin/WICS.pl"
  ],
  "test_requires" => {
    "Data::Section::Simple" => 0,
    "File::Find" => 0,
    "File::Path" => 0,
    "File::Slurp" => 0,
    "File::Temp" => 0,
    "FindBin" => 0,
    "HTTP::Message" => 0,
    "IO::Compress::Gzip" => 0,
    "LWP::UserAgent" => 0,
    "Log::Any::Test" => 0,
    "Test::Base" => 0,
    "Test::Base::Filter" => 0,
    "Test::Exception" => 0,
    "Test::HTML::Differences" => 0,
    "Test::More" => "0.88",
    "Test::NoWarnings" => 0,
    "Test::Warn" => 0,
    "Test::XML" => 0,
    "utf8" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
