
use strict;
use warnings;

use 5.014;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Work with ITS-decorated documents",
  "AUTHOR" => "Nathan Glenn <garfieldnate\@gmail.com>",
  "BUILD_REQUIRES" => {
    "Module::Build" => "0.3601"
  },
  "CONFIGURE_REQUIRES" => {
    "Module::Build" => "0.3601"
  },
  "DISTNAME" => "ITS-WICS",
  "EXE_FILES" => [
    "bin/WICS-GUI.pl",
    "bin/WICS.pl"
  ],
  "LICENSE" => "perl",
  "NAME" => "ITS::WICS",
  "PREREQ_PM" => {
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
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
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
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t t/ITS-Reduce/*.t t/ITS-XLIFF2HTML/*.t t/ITS-XML2HTML/*.t t/ITS-XML2XLIFF/*.t t/ITS/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



