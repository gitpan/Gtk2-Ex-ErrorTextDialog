#!/usr/bin/perl -w

# Copyright 2008, 2009, 2010 Kevin Ryde

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

use strict;
use warnings;
use File::Basename;
use Gtk2 '-init';
use Gtk2::Pango;
use Gtk2::Ex::ErrorTextDialog;
use POSIX ();

use lib::abs '.';
use Gtk2ExWindowManagerFrame;


# PNG spec 11.3.4.2 suggests RFC822 (or rather RFC1123) for CreationTime
use constant STRFTIME_FORMAT_RFC822 => '%a, %d %b %Y %H:%M:%S %z';

use FindBin;
my $progname = $FindBin::Script; # basename part
print "progname '$progname'\n";
my $output_filename = (@ARGV >= 1 ? $ARGV[0] : '/tmp/screenshot.png');

my $dialog = Gtk2::Ex::ErrorTextDialog->instance;
$dialog->signal_connect (destroy => sub { Gtk2->main_quit });

{
  my $textview = $dialog->{'textview'};

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
     my $pixbuf = Gtk2ExWindowManagerFrame::widget_to_pixbuf_with_frame ($dialog);

     print "save to $output_filename\n";
     $pixbuf->save
       ($output_filename, 'png',
        'tEXt::Title'         => 'ErrorTextDialog Screenshot',
        'tEXt::Author'        => 'Kevin Ryde',
        'tEXt::Copyright'     => 'Copyright 2009, 2010 Kevin Ryde',
        'tEXt::Creation Time' => POSIX::strftime (STRFTIME_FORMAT_RFC822,
                                                  localtime(time)),
        'tEXt::Description'   => 'A sample screenshot of a Gtk2::Ex::ErrorTextDialog',
        'tEXt::Software'      => "Generated by $progname",
        'tEXt::Homepage'      => 'http://user42.tuxfamily.org/gtk2-ex-errortextdialog/index.html',
        # must be last or gtk 2.18 botches the text keys
        compression           => 9,
       );
     $dialog->destroy;
     Gtk2->main_quit;
     return 0; # Glib::SOURCE_REMOVE
   });

$dialog->show;
Gtk2->main;
exit 0;