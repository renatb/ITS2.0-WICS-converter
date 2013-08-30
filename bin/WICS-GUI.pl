#!/usr/bin/env perl
use strict;
use warnings;
# PODNAME: WICS-GUI.pl
# VERSION
# ABSTRACT: GUI frontent for converting ITS-decorated data

=head1 DESCRIPTION

This is a graphical interface for converting ITS-decorated
data into other formats. Currently it only supports XML->HTML
conversion.

Choose the file or files you would like to convert by clicking
"Choose file...". Execute the conversion process by clicking
"Convert". A frame with the log messages will pop up. Errors
are shown in red.

Converted files are written to the directory that the source
files exist in. They keep the name of their source file, but
with a different extension. If the "overwrite existing files"
box is not checked and a file with the given name and extension
already exists, then a number will be appended to the end of
the file name to make it unique.

=head1 STANDALONE EXECUTABLE

To create a standalone executable of this script, you will need
to install the following modules:

=over

=item PAR::Packer

This provides the C<pp> command, which creates standalone executables out of
Perl scripts, packaging the Perl interpreter and most required scripts
and DLLs automatically.

=item Wx::Perl::Packager

This provides C<wxpar>, a wrapper around the pp command which adds all of the
required DLLs for running a Wx program.

=back

Next, you'll need to locate the following libraries (DLLs on Windows)
required by XML::LibXML:

=over

=item libxml2-2

=item libiconv-2

=item libz

=back

It's possible that if you're running a different version of XML::LibXML
that the names of these libraries could be different. On my Windows 7 machine,
they are all DLL files, and they all have a __ suffix. Since I'm using
Strawberry Perl, they are all located in C<C:/strawberry/c/bin>. Notice that
I have replaced all backslashes with forward slashes in the path. This is
essential, as C<pp> will fail if paths have backslashes in them.

Finally, you'll need to make the XML::ITS and XML::ITS::WICS distributions
available to these tools, either by installing them on your computer,
or by adding the C<lib> folders of these distributions to the include path
via the C<-I> option.

Here's a sample command to make the standalone executable. We use C<-l>
to make C<pp> include the DLL files in the executable file. The working
directory contains the XML::ITS and XML::ITS::WICS distributions, and we
use -I to include their C<lib> folders. We use C<-o> to specify the
name of the created executable. We pass the path to this script as the
final argument. Run in a Windows CMD, this should all be one line; I have
broken it into four lines for display purposes.

  wxpar -o WICS-GUI.exe -l C:/strawberry/c/bin/libxml2-2__.dll
  -l C:/strawberry/c/bin/libiconv-2__.dll -l C:/strawberry/c/bin/libz__.dll
  -I XML-ITS-0.02/lib -I XML-ITS-WICS-0.02/lib
  XML-ITS-WICS-0.02/bin/WICS-GUI.pl


=head1 TODO

A checkbox for indicating whether files should be overwritten or not
would be nice.

Sometimes fonts change in the display box. Figure out the whole RTF thing
and maybe do some escaping so that everything stays consistent.

=cut

package MyApp;
use Wx::Perl::Packager;
use Wx qw(
    :clipboard
    :misc
    :frame
    :textctrl
    :sizer
    :panel
    :window
    :id
    :filedialog
    :colour
);
use Wx::DND;
use Wx::Event qw(EVT_BUTTON);
use base 'Wx::App';
use Path::Tiny;
use Try::Tiny;
use Log::Any::Test;
use Log::Any qw($log);
use XML::ITS::WICS qw(xml2html);

sub OnInit {
    my( $self ) = @_;
    # create a new frame (a frame is a top level window)
    my $frame = Wx::Frame->new(
        undef,           # parent window
        -1,              # ID -1 means any
        'Convert ITS-Decorated Files',   # title
        [-1, -1],        # default position
        [350, 250],      # size
    );
    $self->{main_frame} = $frame;

    my $topsizer = Wx::BoxSizer->new(wxVERTICAL);
    # create Wx::Panel to use as a parent
    my $panel = Wx::Panel->new(
        $frame, -1, [-1,-1], [-1,-1],
        wxTAB_TRAVERSAL|wxBORDER_NONE
    );
    # create a text control with minimal size 100x60
    my $text = Wx::TextCtrl->new(
        $panel, -1, '',
        [-1,-1],[400,240],
        wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL
    );
    $topsizer->Add(
        $text,
        1,           # make vertically stretchable
        wxEXPAND |   # make horizontally stretchable
        wxALL,       # and make border all around
        10           # set border width to 10
    );
    my $convert_btn     = Wx::Button->new($panel, wxID_OK, 'Convert');
    EVT_BUTTON( $self, $convert_btn, sub {
            my ($self, $event) = @_;
            $self->_convert_files;
        }
    );
    my $choose_file_btn     = Wx::Button->new($panel, wxID_ANY, 'Choose File...');
    EVT_BUTTON( $self, $choose_file_btn, sub {
            my ($self, $event) = @_;
            $self->{file_paths} = _open_files($frame);
            $text->SetValue(join "\n",@{ $self->{file_paths} } );
        }
    );
    my $close_btn = Wx::Button->new($panel, wxID_CANCEL, 'Close');
    EVT_BUTTON( $self, $close_btn, sub {
            my ($self, $event) = @_;
            $frame->Destroy;
        }
    );
    my $buttonsizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $buttonsizer->Add(
        $convert_btn,
        0,           # make horizontally unstretchable
        wxALL,       # make border all around (implicit top alignment)
        10           # set border width to 10
    );
    $buttonsizer->Add(
        $choose_file_btn,
        0,           # make horizontally unstretchable
        wxALL,       # make border all around (implicit top alignment)
        10           # set border width to 10
    );
    $buttonsizer->Add(
        $close_btn,
        0,           # make horizontally unstretchable
        wxALL,       # make border all around (implicit top alignment)
        10           # set border width to 10
    );
    $topsizer->Add(
        $buttonsizer,
        0,             # make vertically unstretchable
        wxALIGN_CENTER # no border and centre horizontally
    );
    # my $overwrite_checkbox = Wx::CheckBox->new(
    #     $frame, wxID_ANY, "overwrite existing files",
    #     wxDefaultPosition, wxDefaultSize, 0);
    # $topsizer->Add(
    #     $overwrite_checkbox,
    #     0,             # make vertically unstretchable
    #     wxALIGN_CENTER, # no border and centre horizontally
    #     10
    # );
    $panel->SetSizer( $topsizer );
    my $mainsizer = Wx::BoxSizer->new(wxVERTICAL);
    $mainsizer->Add($panel, 1, wxEXPAND|wxALL, 0);
    # use the sizer for layout and size frame
    # preventing it from being resized to a
    # smaller size;
    $frame->SetSizerAndFit($mainsizer);
    $frame->Show( 1 );
    return 1;
}

#returns an array pointer of paths to user-specified files to open
sub _open_files {
    my ($frame) = @_;

    my $fileDialog = Wx::FileDialog->new(
        $frame, 'Choose ITS-decorated XML file', '',
             '.', '*.*',
             wxFD_OPEN|wxFD_MULTIPLE|wxFD_FILE_MUST_EXIST);

    my $fileDialogStatus = $fileDialog->ShowModal();

    my @paths = $fileDialog->GetPaths();
    if ( $fileDialogStatus == wxID_OK ) {
        return \@paths;
    };
    return [];
}

sub _convert_files {
    my ($self) = @_;
    my $frame = Wx::Frame->new(
        $self->{main_frame},# parent window
        -1,                 # ID -1 means any
        'Conversion Logs',   # title
        [-1, -1],           # default position
        [100, 100],         # size (overridden by textCtrl size)
    );
    my $topsizer = Wx::BoxSizer->new(wxVERTICAL);
    # create Wx::Panel to use as a parent
    my $panel = Wx::Panel->new(
        $frame, -1, [-1,-1], [-1,-1],
        wxTAB_TRAVERSAL|wxBORDER_NONE
    );
    # create a text control with minimal size 100x60
    my $text = Wx::TextCtrl->new(
        $panel, -1, '',
        [-1,-1],[400,500],
        #multiline, read-only, scrollable, allow styles
        wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL|wxTE_RICH2
    );
    my $copy_btn = Wx::Button->new($panel, wxID_ANY, 'Copy');
    EVT_BUTTON( $self, $copy_btn,
        sub {
            my ($self, $event) = @_;
            if (wxTheClipboard->Open){
                wxTheClipboard->SetData(
                    Wx::TextDataObject->new($text->GetValue) );
                wxTheClipboard->Close();
            }
        }
    );
    my $buttonsizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $buttonsizer->Add(
        $copy_btn,
        0,           # make horizontally unstretchable
        wxALL,       # make border all around (implicit top alignment)
        10           # set border width to 10
    );
    $topsizer->Add(
        $buttonsizer,
        0,             # make vertically unstretchable
        wxALIGN_CENTER # no border and centre horizontally
    );
    $topsizer->Add(
        $text,
        1,           # make vertically stretchable
        wxEXPAND |   # make horizontally stretchable
        wxALL,       # and make border all around
        10           # set border width to 10
    );

    $panel->SetSizer( $topsizer );
    my $mainsizer = Wx::BoxSizer->new(wxVERTICAL);
    $mainsizer->Add($panel, 1, wxEXPAND|wxALL, 0);
    # use the sizer for layout and size frame
    # preventing it from being resized to a
    # smaller size;
    $frame->SetSizerAndFit($mainsizer);
    $frame->Show( 1 );

    my $warning_style = Wx::TextAttr->new();
    $warning_style->SetTextColour(wxRED);
    my $done_style = Wx::TextAttr->new();
    $done_style->SetTextColour(wxBLUE);
    my $normal_style = Wx::TextAttr->new();
    $normal_style->SetTextColour(wxBLACK);

    #catch warnings, as well
    local $SIG{__WARN__} = sub {
        $text->SetDefaultStyle($warning_style);
        $text->AppendText($_[0]);
        $text->SetDefaultStyle($normal_style);
    };
    for my $path (@{ $self->{file_paths} }){
        $path = path($path);
        $log->clear;
        try{
            $text->SetDefaultStyle($normal_style);
            $text->AppendText(
                "\n----------\n$path\n----------\n");
            my $html = xml2html($path);
            my $new_path = _get_new_path($path);
            my $fh = $new_path->filehandle('>:encoding(UTF-8)');
            print $fh ${ $html };
            $text->AppendText(
                join "\n", map {
                    $_->{message}
                } @{$log->msgs});
            $text->SetDefaultStyle($done_style);
            $text->AppendText("\nwrote $new_path\n");
        }catch{
            $text->SetDefaultStyle($warning_style);
            $text->AppendText($_);
        };
    }
    return;
}

#input: Path::Tiny object for input file path
sub _get_new_path {
    my ($old_path) = @_;
    my $name = $old_path->basename;
    my $dir = $old_path->dirname;

    #new file will have html extension instead of whatever there was before
    $name =~ s/(\.[^.]+)?$/.html/;
    # if other file with same name exists, just iterate numbers to get a new,
    # unused file name
    my $new_path = path($dir, $name);
    if($new_path->exists){
        $name =~ s/\.html$//;
        $new_path = path($dir, $name . '-1.html');
        my $counter = 1;
        while($new_path->exists){
            $counter++;
            $new_path = path($dir, $name . "-$counter.html");
        }
    }
    return $new_path;
}

package main; ## no critic(ProhibitMultiplePackages)
my $app = MyApp->new;
$app->MainLoop;
