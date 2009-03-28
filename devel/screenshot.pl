#!/usr/bin/perl

# Copyright 2008, 2009 Kevin Ryde

# This file is part of Gtk2-Ex-ErrorTextDialog.
#
# Gtk2-Ex-ErrorTextDialog is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# Gtk2-Ex-ErrorTextDialog is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Gtk2-Ex-ErrorTextDialog.  If not, see <http://www.gnu.org/licenses/>.


# Usage: perl screenshot.pl [outputfile.png]
#
# Capture an ErrorTextDialog to the given outputfile.png.
# The default output file is /tmp/screenshot.png


#------------------------------------------------------------------------------

package MyScreenshot;
use strict;
use warnings;
use Carp;

use constant DEBUG => 0;

# Return a new Gtk2::Gdk::Pixbuf with the contents of $widget's toplevel
# window plus window manager frame (if it has a frame).
#
sub widget_to_pixbuf_with_frame {
  my ($widget) = @_;
  $widget = $widget->get_toplevel;
  my $window = $widget->window;
  my $frame_window = window_get_frame_window ($window);
  my ($width, $height) = $frame_window->get_size;
  return (Gtk2::Gdk::Pixbuf->get_from_drawable ($frame_window,
                                                undef, # colormap
                                                0,0,   # src x,y
                                                0,0,   # dst x,y
                                                $width, $height)
          || croak 'Cannot get widget contents as pixbuf');
}

# $window is a Gtk2::Gdk::Window, return a Gtk2::Gdk::Window (a "foreign"
# window) which is the window manager frame.  Or return $window itself if no
# window manager or it doesn't use a frame.
#
sub window_get_frame_window {
  my ($window) = @_;
  if (DEBUG) { printf "window_get_frame_window(): root %#X\n",
                 $window->get_parent->XID;
               printf "  window: %7X  %dx%d\n",
                 $window->XID, $window->get_size;
             }
  my $root = $window->get_parent;
  my $display = $window->get_display;
  for (;;) {
    my $parent = Gtk2::Gdk::Window->foreign_new_for_display
      ($display, window_get_parent_xid ($window));
    if (DEBUG) { printf "  parent: %7X  %dx%d\n",
                   $parent->XID, $parent->get_size; }
    if ($parent == $root) { last; }
    $window = $parent;
  }
  return $window;
}

# $window is a Gtk2::Gdk::Window, return the X window ID of its parent.
#
# Have to go through X11::Protocol or xwininfo here, since Gtk2::Gdk::Window
# always sets up as if the root window is the parent, even for foreign
# windows.  foreign_new() does an XQueryTree, and so has the real parent
# XID, but it then pretends the root window is the parent.
#
use Scalar::Lazy;
my $have_x11_protocol = lazy { eval { require X11::Protocol } ? 1 : 0 };
if (DEBUG) {
  print "have X11::Protocol: ", $have_x11_protocol?"yes":"no", "\n";
}

sub window_get_parent_xid {
  my ($window) = @_;

  if ($have_x11_protocol) {
    my $display = $window->get_display;
    my $p = ($display->{'X11::Protocol'}
          ||= X11::Protocol->new ($display->get_name));
    my ($root, $parent) = $p->req('QueryTree', $window->XID);
    return $parent;

  } else {
    my $command = 'xwininfo -tree -id ' . $window->XID;
    my $str = `$command`;
    $str =~ /Parent window id: (\w+)/
      or croak "Cannot get parent XID from xwininfo: $str";
    return hex($1);
  }
}

# xwd will only give back the frame with -frame if used interactively.  If
# you give the desired window with -id then it ignores the -frame option.
#
#      my $png_fh = File::Temp->new (SUFFIX => '.png');
#      my $png_filename = $png_fh->filename;
#
#      my $command = "xwd -frame | convert xwd:- $png_filename";
#      print "$command\n";
#      system($command) == 0 or die "xwd error $?";
#
#      my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file ($png_filename);
#      my ($width, $height) = $window->get_size;
#      my $pixbuf = Gtk2::Gdk::Pixbuf->get_from_drawable ($window,
#                                                         undef, # colormap
#                                                         0,0, 0,0,
#                                                         $width, $height);
#
#
#
#      my $xwd_fh = File::Temp->new (SUFFIX => '.xwd');
#      my $xwd_filename = $xwd_fh->filename;
#      $command = "convert $xwd_filename $png_filename";
#      print "$command\n";
#      system($command) == 0 or die "convert error $?";
#


#------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use File::Basename;
use POSIX;
use File::Temp;
use Gtk2 '-init';
use Gtk2::Ex::ErrorTextDialog;

my $progname = basename($0);
my $output_filename = (@ARGV >= 1 ? $ARGV[0] : '/tmp/screenshot.png');

my $dialog = Gtk2::Ex::ErrorTextDialog->instance;
$dialog->signal_connect (destroy => sub { Gtk2->main_quit });

{
  my $textview = $dialog->{'textview'};

  require Gtk2::Pango;
  my $context = $textview->get_pango_context;
  my $font_desc = $textview->style->font_desc;
  my $metrics = $context->get_metrics ($font_desc, $context->get_language);
  my $char_width = $metrics->get_approximate_char_width
    / Gtk2::Pango::PANGO_SCALE();
  my $line_height = ($metrics->get_ascent + $metrics->get_descent)
    / Gtk2::Pango::PANGO_SCALE();

  my $scrolled = $textview->get_parent;
  $scrolled->set_size_request (65 * $char_width, 7.5 * $line_height);
  my $req = $dialog->size_request;
  $scrolled->set_size_request (-1, -1);
  $dialog->set_default_size ($req->width, $req->height);
}

$dialog->add_message ('Some error at foo.pl line 123');
$dialog->add_message ('Look to your orb for the warning at Dopes.pm line 456');
$dialog->add_message ('Application message about something ...');

Glib::Timeout->add
  (2000,
   sub {
     my $pixbuf = MyScreenshot::widget_to_pixbuf_with_frame ($dialog);

     $pixbuf->save
       ($output_filename, 'png',
        'tEXt::Title'         => 'ErrorTextDialog Screenshot',
        'tEXt::Author'        => 'Kevin Ryde',
        'tEXt::Copyright'     => 'Copyright 2009 Kevin Ryde',
        'tEXt::Creation Time' => POSIX::strftime ("%a, %d %b %Y %H:%M:%S %z",
                                                  localtime(time)),
        'tEXt::Description'   => 'A sample screenshot of a Gtk2::Ex::ErrorTextDialog',
        'tEXt::Software'      => "Generated by $progname with help from xwd and ImageMagick convert",
        'tEXt::Homepage'      => 'http://www.geocities.com/user42_kevin/gtk2-ex-errortextdialog/index.html',
       );
     Gtk2->main_quit;
     return 0; # Glib::SOURCE_REMOVE
   });

$dialog->show;
Gtk2->main;
exit 0;
