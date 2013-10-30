#!/usr/bin/env perl
#
# This file is part of ITS-WICS
#
# This software is copyright (c) 2013 by DFKI.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict;
use warnings;
# PODNAME: WICS-GUI.pl
our $VERSION = '0.04'; # VERSION
# ABSTRACT: GUI frontent for converting ITS-decorated data


package WicsGui;
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
    :listbox
);
use Wx::DND;
use Wx::Event qw(EVT_BUTTON EVT_LISTBOX EVT_LISTBOX_DCLICK);
use base 'Wx::App';
use Path::Tiny;
use Try::Tiny;
use Log::Any::Adapter;
#need the use statement so that pp will include it in the exe
use ITS::WICS::GuiLogger;
Log::Any::Adapter->set('+ITS::WICS::GuiLogger');
use ITS::WICS;

sub OnInit {
    my( $self ) = @_;
    # create a new top-level window
    my $frame = Wx::Frame->new(
        undef,           # parent window
        -1,              # ID -1 means any
        'Convert ITS-Decorated Files',   # title
        [-1, -1],        # default position
        [500, 250],      # size
    );

    my $sizer = Wx::BoxSizer->new( wxHORIZONTAL );
    # create Wx::Panel to use as a parent
    my $panel = Wx::Panel->new( $frame );
    # the control (for Mac, the box must be created before the control)
    my $box = Wx::StaticBox->new( $panel, -1, 'Tasks' );
    my $ctrlsz = Wx::StaticBoxSizer->new( $box, wxVERTICAL );
    my $listbox = Wx::wxVListBox::Tasks->new( $panel, -1, [-1, -1]);
    EVT_LISTBOX_DCLICK( $panel, $listbox, \&OnListBoxDoubleClick );
    $ctrlsz->Add( $listbox, 1, wxALL|wxEXPAND, 5 );
    $sizer->Add( $ctrlsz, 1, wxGROW|wxALL, 5 );

    $panel->SetSizerAndFit( $sizer );
    $frame->Show(1);
    return 1;
}

sub OnListBoxDoubleClick {
    my( $parent, $event ) = @_;
    my $vlist = $event->GetEventObject;

    my $lbdata = $vlist->{lbdata}->[$vlist->GetSelection];
    my $title = $lbdata->{name};
    my $transformer = $lbdata->{transformer};
    my $output_ext = $lbdata->{output_ext};

    my $frame = Wx::Frame->new(
        $parent,            # parent window
        -1,                 # ID -1 means any
        $title,             # title
        [-1, -1],           # default position
        [350, 250],         # size
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

    my $files = [];
    my $convert_btn     = Wx::Button->new($panel, wxID_OK, 'Convert');
    EVT_BUTTON( $panel, $convert_btn, sub {
            my ($panel, $event) = @_;
            _convert_files($panel, $transformer, $files, $output_ext);
        }
    );
    my $choose_file_btn     = Wx::Button->new($panel, wxID_ANY, 'Choose File...');
    EVT_BUTTON( $panel, $choose_file_btn, sub {
            my ($panel, $event) = @_;
            $files = _open_files($frame);
            $text->SetValue(join "\n", @$files );
        }
    );
    my $close_btn = Wx::Button->new($panel, wxID_CANCEL, 'Close');
    EVT_BUTTON( $panel, $close_btn, sub {
            my ($panel, $event) = @_;
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
    return;
}

#returns an array pointer of paths to user-specified files to open
sub _open_files {
    my ($parent) = @_;

    my $fileDialog = Wx::FileDialog->new(
        $parent, 'Choose ITS-decorated XML file', '',
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
    my ($parent, $transformer, $files_array, $output_ext) = @_;
    my $frame = Wx::Frame->new(
        $parent,# parent window
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
    EVT_BUTTON( $parent, $copy_btn,
        sub {
            my ($parent, $event) = @_;
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
    #send log messages to $text
    Wx::Log::SetActiveTarget(Wx::LogTextCtrl->new($text));
    for my $path (@$files_array){
        $path = path($path);
        try{
            $text->SetDefaultStyle($normal_style);
            $text->AppendText(
                "\n----------\n$path\n----------\n");
            my $html = $transformer->($path);
            my $new_path = _get_new_path($path, $output_ext);
            my $fh = $new_path->openw_utf8;
            print $fh ${ $html };
            $text->SetDefaultStyle($done_style);
            $text->AppendText("\nwrote $new_path\n");
        }catch{
            $text->SetDefaultStyle($warning_style);
            $text->AppendText($_);
        };
    }
    # restore default logger
    Wx::Log::SetActiveTarget(Wx::LogGui->new());
    return;
}

#input: Path::Tiny object for input file path
sub _get_new_path {
    my ($old_path, $output_ext) = @_;
    my $name = $old_path->basename;
    my $dir = $old_path->dirname;

    #new file will have html extension instead of whatever there was before
    $name =~ s/(\.[^.]+)?$/.$output_ext/;
    # if other file with same name exists, just iterate numbers to get a new,
    # unused file name
    my $new_path = path($dir, $name);
    if($new_path->exists){
        $name =~ s/\.$output_ext$//;
        $new_path = path($dir, $name . "-1.$output_ext");
        my $counter = 1;
        while($new_path->exists){
            $counter++;
            $new_path = path($dir, $name . "-$counter.$output_ext");
        }
    }
    return $new_path;
}

package Wx::wxVListBox::Tasks; ## no critic(ProhibitMultiplePackages)

use strict;
use base qw(Wx::PlVListBox);

use Wx qw( :brush :font :pen :colour );

sub new {
    my( $class, @args ) = @_;
    my $self = $class->SUPER::new( @args );

    $self->{lbdata} = [

        { name => 'XML2HTML',
          description => 'Convert XML into HTML, preserving ITS information.',
          colour => [ 255, 0, 0 ],
          transformer => \&ITS::WICS::xml2html,
          output_ext => 'html',
        },
        { name => 'HTML5 Reduce',
          description => 'Reduce HTML5 and external ITS resources to a single file.',
          colour => [ 0, 255, 0 ],
          transformer => \&ITS::WICS::reduceHtml,
          output_ext => 'html',
        },
        { name => 'XLIFF2HTML',
          description => 'Write HTML to display ITS data in XLIFF source and target elements.',
          colour => [ 0, 0, 255 ],
          transformer => \&ITS::WICS::xliff2html,
          output_ext => 'html',
        },
        { name => 'XML2XLIFF',
          description => 'Create an XLIFF file with translation units extracted from XML.',
          colour => [ 255, 255, 0 ],
          transformer => \&ITS::WICS::xml2xliff,
          output_ext => 'xlf',
        },
    ];

    # metrics
    $self->{margin} = 5;
    $self->{graphicsize} = 32;
    # For Wx < 0.99, you must call static Wx::Font->New like a method.
    # For Wx >= 0.99, expected function type calls work also
    $self->{largefontsize} = Wx::Size->new(7,16);
    $self->{largefont} = Wx::Font::New($self->{largefontsize}, wxFONTFAMILY_SWISS, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD, 0 );
    $self->{smallfont} = Wx::Font::New(Wx::Size->new(6,14), wxFONTFAMILY_SWISS, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_NORMAL, 0 );
    $self->{itemheight} = ($self->{margin} * 2) + $self->{graphicsize};


    $self->SetItemCount( scalar @{$self->{lbdata}} );

    return $self;
}

sub OnMeasureItem {
    my( $self, $item ) = @_;
    return $self->{itemheight}; # all our items are same height
}


sub OnDrawItem {
    my( $self, $dc, $r, $item ) = @_;

    my $itemdata = $self->{lbdata}->[$item];

    # draw the graphic
    $dc->SetPen( Wx::Pen->new(wxLIGHT_GREY, 1, wxSOLID) );
    $dc->SetBrush( Wx::Brush->new( Wx::Colour->new(@{ $itemdata->{colour} }), wxSOLID ) );

    $dc->DrawRectangle( $r->x + $self->{margin},
                        $r->y + $self->{margin},
                        $self->{graphicsize},
                        $self->{graphicsize} );

    # Draw name
    $dc->SetFont($self->{largefont});
    my $woffset = ( 2* $self->{margin} ) + $self->{graphicsize};
    $dc->DrawText($itemdata->{name}, $r->x + $woffset, $r->y + $self->{margin});

    # draw description
    $dc->SetFont($self->{smallfont});
    $dc->DrawText(
        $itemdata->{description},
        $r->x + $woffset,
        $r->y + $self->{largefontsize}->y + $self->{margin});
    return;
}

sub OnDrawSeparator {
    my( $self, $dc, $rect, $item ) = @_;
    $dc->SetPen(wxLIGHT_GREY_PEN);
    my $bl = $rect->GetBottomLeft;
    my $br = $rect->GetBottomRight;
    $dc->DrawLine($bl->x, $bl->y, $br->x, $br->y);
    # shave off the line width of one pixel
    $rect->SetHeight( $rect->GetHeight - 1);
    return;
}

sub OnDrawBackground {
    my( $self, $dc, $rect, $item ) = @_;
    my $bgcolour = ( $self->IsSelected( $item ) ) ?  Wx::Colour->new(255,255,200) : wxWHITE;
    $dc->SetBrush(Wx::Brush->new($bgcolour, wxSOLID ));
    $dc->SetPen(Wx::Pen->new($bgcolour, 1, wxSOLID ));
    $dc->DrawRectangle($rect->x, $rect->y, $rect->width, $rect->height);
    return;
}

1;

package main; ## no critic(ProhibitMultiplePackages)
my $app = WicsGui->new;
$app->MainLoop;

__END__

=pod

=head1 NAME

WICS-GUI.pl - GUI frontent for converting ITS-decorated data

=head1 VERSION

version 0.04

=head1 DESCRIPTION

This is a graphical interface for converting ITS-decorated
data into other formats. Currently it only supports XML->HTML
conversion.

Choose the file or files you would like to convert by clicking
"Choose file...". Execute the conversion process by clicking
"Convert". A frame with the log messages will pop up. Errors
are shown in red.

Converted files are written to the same directory as the source file.
Filenames are created by stripping the extension from the input file
and replacing it with the extension for the target format (html, xliff,
etc.). If a file with that name already exists, additional numbers
(-1, -2, etc.) will be appended to the filename to ensure uniqueness.

=head1 STANDALONE EXECUTABLE

To create a standalone executable of this script, you will need
to install the following modules (besides the dependencies
required to run this script in the first place):

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

=item zlib and lzma (or libz if you don't have those)

=back

It's possible that if you're running a different version of XML::LibXML
that the names of these libraries could be different. On my Windows 7 machine,
they are all DLL files, and they all have a __ suffix. zlib and lzma are
C<zlib1__.dll> and C<liblzma-5__.dll>, respectively. Since I'm using
Strawberry Perl, they are all located in C<C:/strawberry/c/bin>. Notice that
I have replaced all backslashes with forward slashes in the path. This is
essential, as C<pp> will fail if paths have backslashes in them.

Finally, you'll need to make the ITS-WICS distribution available to C<pp>
and C<wxpar>, either by installing it or by adding the C<lib> folder to the
include path via the C<-I> option.

Here's a sample command to make the standalone executable. We use C<-l>
to make C<wxpar> include the DLL files in the executable file. The working
directory contains the ITS-WICS distribution, and we use -I to include its
C<lib> folders (remember that this is unnecessary if this distribution
has been installed). We use C<-o> to specify the name of the created
executable. We pass the path to this script as the final argument. Run
in a Windows CMD, this should all be one line; I have broken it into several
lines for display purposes.

  wxpar -o WICS-GUI.exe -l C:/strawberry/c/bin/libxml2-2__.dll
  -l C:/strawberry/c/bin/libiconv-2__.dll -l C:/strawberry/c/bin/zlib1__.dll
  -l C:/strawberry/c/bin/liblzma-5__.dll -I ITS-WICS/lib
  ITS-WICS/bin/WICS-GUI.pl

=head1 TODO

A checkbox for indicating whether files should be overwritten or not
would be nice.

Sometimes fonts change in the display box. Figure out the whole RTF thing
and maybe do some escaping so that everything stays consistent.

Real icons instead of colored boxes would be less cheesy.

Use XRC to clean up the bulk of the code.

It would be useful to be able to add and remove files from a list for conversion,
instead of just selecting all of the files for processing at once.

=head1 AUTHOR

Nathan Glenn <garfieldnate@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by DFKI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
