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


package Gtk2::Ex::WindowManagerFrame;
use strict;
use warnings;
use Exporter;
use Carp;
use Scalar::Lazy;

our @EXPORT_OK = qw(widget_to_pixbuf_with_frame
                    get_frame_window
                    window_get_parent_XID);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use constant DEBUG => 0;


# For reference, the xwd program only gives back the frame with its -frame
# option if used interactively.  If you give a desired window with -id then
# it ignores the -frame option.
#
#      use File::Temp;
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
#      my $xwd_fh = File::Temp->new (SUFFIX => '.xwd');
#      my $xwd_filename = $xwd_fh->filename;
#      $command = "convert $xwd_filename $png_filename";
#      print "$command\n";
#      system($command) == 0 or die "convert error $?";
#

sub widget_to_pixbuf_with_frame {
  my ($widget) = @_;
  $widget = $widget->get_toplevel;
  my $window = $widget->window || croak 'Widget not realized';
  $window = get_frame_window($window) || $window;
  my ($width, $height) = $window->get_size;
  return (Gtk2::Gdk::Pixbuf->get_from_drawable ($window,
                                                undef, # colormap
                                                0,0,   # src x,y
                                                0,0,   # dst x,y
                                                $width, $height)
          || croak 'Cannot get window contents as pixbuf');
}

sub get_frame_window {
  my ($obj) = @_;
  my $xid = get_frame_XID ($window) || return;
  return Gtk2::Gdk::Window->foreign_new_for_display
    ($obj->get_display, $xid);
}

sub window_get_frame_XID {
  my ($window) = @_;
  if (my $func = $window->can('get_toplevel')) {
    $window = $window->$func || croak "No toplevel widget/window";
  }
  if (my $func = $window->can('get_window')) {
    $window = $window->$func || croak "No window";
  }
  if (DEBUG) { my $root = $window->get_screen->get_root_window;
               my $root_xid = ($root->can('XID') ? $root->XID : -1);
               my $window_xid = ($window->can('XID') ? $window->XID : -1);
               printf "get_frame_window(): root %#X\n", $root_xid;
               printf "  window: %7X  %dx%d\n", $window_xid, $window->get_size;
             }
  my $toplevel = $window->get_toplevel;
  $toplevel->can('XID') || return undef; # not X11
  my $toplevel_xid = $toplevel->XID;

  my $display = $window->get_display;
  my $frame_xid = $toplevel_xid;
  my $xid = window_XID_get_parent_XID ($display, $frame_xid);

  for (;;) {
    if (DEBUG) { printf "  up: %7X\n", $xid; }
    my $parent_xid = window_XID_get_parent_XID ($display, $xid) || last;
    $xid = $parent_xid;
  }

  return ($frame_xid == $toplevel_xid
          ? undef  # only root window above $toplevel_xid, no frame
          : $frame_xid);
}

# =item C<< Gtk2::Ex::WindowManagerFrame::window_XID_get_parent_XID ($display, $xid) >>
# 
# Return the X window ID (an integer) which is the parent window of the given
# C<$xid> window, or undef if no parent ($xid is the root window).

my $have_x11_protocol = lazy { eval { require X11::Protocol } ? 1 : 0 };
if (DEBUG) {
  print "have X11::Protocol: ", $have_x11_protocol?"yes":"no", "\n";
}

sub window_XID_get_parent_XID {
  my ($display, $xid) = @_;

  if ($have_x11_protocol) {
    my $p = ($display->{__PACKAGE__.'.x11_protocol'}
             ||= X11::Protocol->new ($display->get_name));
    my ($root, $parent) = $p->req('QueryTree', $xid);
    return ($parent eq 'None' ? undef : $parent);

  } else {
    local $ENV{'DISPLAY'} = $display->get_name;
    my $command = "xwininfo -id $xid -children";
    my $str = `$command`;
    # line like
    #     Parent window id: 0x5f (...)
    # or at the root window get 0 which is None as from XQueryTree
    #     Parent window id: 0x0 (none)
    $str =~ /Parent window id: (\w+)/
      or croak "Cannot get parent XID from xwininfo: $str";
    my $parent = hex($1);
    return ($parent == 0 ? undef : $parent);
  }
}

1;
__END__

=head1 NAME

Gtk2::Ex::WindowManagerFrame -- access to the window manager frame window

=head1 SYNOPSIS

 use Gtk2::Ex::WindowManagerFrame;

=head1 FUNCTIONS

=over 4

=item C<< Gtk2::Ex::WindowManagerFrame::get_frame_window ($widget_or_window) >>

=item C<< Gtk2::Ex::WindowManagerFrame::get_frame_XID ($widget_or_window) >>

Return the frame window added by the window manager to the toplevel of
C<$window_or_widget>.  C<get_frame_window> returns a "foreign" type
C<Gtk2::Gdk::Window>, C<get_frame_XID> returns an X11 ID (a integer).  If
there's no frame then the return is C<undef> in both cases.

C<$widget_or_window> can be a C<Gtk2::Widget> or a C<Gtk2::Gdk::Window>.
A widget must have a toplevel window parent, or be a toplevel
C<Gtk2::Window> itself, and that toplevel must be realized, ie. have an
underlying Gdk window already created.

=item C<< Gtk2::Ex::WindowManagerFrame::widget_to_pixbuf_with_frame ($widget) >>

Return a new C<Gtk2::Gdk::Pixbuf> with the contents of C<$widget>'s toplevel
window plus its window manager frame (if it has one).

Generally the window and frame must be on-screen and unobscured.  (The
gambits in C<gtk_widget_get_snapshot> to redirect window draws, instead of
using GraphicsExpose, of course can't work with the window manager's
drawing.)

=back

=head1 IMPLEMENTATION

Gdk doesn't provide direct access to the window manager frame window (as of
version 2.14).  This module instead uses C<X11::Protocol> if available, or
the C<xwininfo> program if not.  Currently when using C<X11::Protocol> an
extra connection is opened to the display and held open with the
C<Gtk2::Gdk::Display> object of any windows used.

=head1 SEE ALSO

L<Gtk2::Gdk::Window>, L<Gtk2::Gdk::Display>, L<X11::Protocol>,
L<xwininfo(1)>

=cut
