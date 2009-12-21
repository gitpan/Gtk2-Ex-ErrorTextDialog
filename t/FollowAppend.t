#!/usr/bin/perl

# Copyright 2009 Kevin Ryde

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

use 5.008;
use strict;
use warnings;
use Gtk2::Ex::TextView::FollowAppend;
use Test::More;

require Gtk2;
Gtk2->disable_setlocale;  # leave LC_NUMERIC alone for version nums
my $have_display = Gtk2->init_check;
if (! $have_display) {
  plan skip_all => "due to no DISPLAY available";
}
plan tests => 9;

SKIP: { eval 'use Test::NoWarnings; 1'
          or skip 'Test::NoWarnings not available', 1; }

#-----------------------------------------------------------------------------

my $want_version = 5;
ok ($Gtk2::Ex::TextView::FollowAppend::VERSION >= $want_version,
    'VERSION variable');
ok (Gtk2::Ex::TextView::FollowAppend->VERSION  >= $want_version,
    'VERSION class method');
ok (eval { Gtk2::Ex::TextView::FollowAppend->VERSION($want_version); 1 },
    "VERSION class check $want_version");
{ my $check_version = $want_version + 1000;
  ok (! eval { Gtk2::Ex::TextView::FollowAppend->VERSION($check_version); 1 },
      "VERSION class check $check_version");
}
{
  my $textview = Gtk2::Ex::TextView::FollowAppend->new;

  ok ($textview->VERSION  >= $want_version,
      'VERSION object method');
  ok (eval { $textview->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { $textview->VERSION($check_version); 1 },
      "VERSION object check $check_version");
}

#-----------------------------------------------------------------------------
# destruction

{
  my $textview = Gtk2::Ex::TextView::FollowAppend->new;
  require Scalar::Util;
  Scalar::Util::weaken ($textview);
  is ($textview, undef, 'garbage collect after weaken');
}

#-----------------------------------------------------------------------------
# insertions

{
  my $textview = Gtk2::Ex::TextView::FollowAppend->new;
  my $textbuf = $textview->get_buffer;

  $textbuf->insert_at_cursor ("hello\n");

  $textbuf->create_child_anchor ($textbuf->get_end_iter);
  $textbuf->insert ($textbuf->get_end_iter, "\n");

  my $pixbuf = Gtk2::Gdk::Pixbuf->new ('rgb', 0, 8, 30, 10);
  $textbuf->insert_pixbuf ($textbuf->get_end_iter, $pixbuf);
  $textbuf->insert ($textbuf->get_end_iter, "\n");
}

exit 0;
