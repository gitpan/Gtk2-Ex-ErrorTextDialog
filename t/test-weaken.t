#!/usr/bin/perl

# Copyright 2007, 2008, 2009 Kevin Ryde

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

use strict;
use warnings;
use Gtk2::Ex::ErrorTextDialog;
use Test::More;

use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin,'inc');
use MyTestHelpers;
use Test::Weaken::Gtk2;

# Test::Weaken 3 for "contents"
my $have_test_weaken = eval "use Test::Weaken 3; 1";
if (! $have_test_weaken) {
  plan skip_all => "due to Test::Weaken 3 not available -- $@";
}
diag ("Test::Weaken version ", Test::Weaken->VERSION);

require Gtk2;
Gtk2->disable_setlocale;  # leave LC_NUMERIC alone for version nums
my $have_display = Gtk2->init_check;
if (! $have_display) {
  plan skip_all => "due to no DISPLAY available";
}

# set this to 1 for some diagnostic prints
use constant DEBUG => 0;

plan tests => 6;

SKIP: { eval 'use Test::NoWarnings; 1'
          or skip 'Test::NoWarnings not available', 1; }

MyTestHelpers::glib_gtk_versions();


#-----------------------------------------------------------------------------
# TextView::FollowAppend

diag "on TextView::FollowAppend->new()";
{
  require Gtk2::Ex::TextView::FollowAppend;
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub { return Gtk2::Ex::TextView::FollowAppend->new },
       contents => \&Test::Weaken::Gtk2::contents_container,
     });
  is ($leaks, undef, 'Test::Weaken deep garbage collection');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}
diag "on TextView::FollowAppend->new_with_buffer()";
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $textbuf = Gtk2::TextBuffer->new;
         my $textview
           = Gtk2::Ex::TextView::FollowAppend->new_with_buffer ($textbuf);
         return [ $textview, $textbuf ];
       },
       contents => \&Test::Weaken::Gtk2::contents_container,
     });
  is ($leaks, undef, 'Test::Weaken deep garbage collection');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}


#-----------------------------------------------------------------------------
# ErrorTextDialog

diag "on new() ErrorTextDialog";
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $dialog = Gtk2::Ex::ErrorTextDialog->new;
         $dialog->realize;
         return $dialog;
       },
       destructor => \&Test::Weaken::Gtk2::destructor_destroy,
       contents => \&Test::Weaken::Gtk2::contents_container,
     });
  is ($leaks, undef, 'Test::Weaken deep garbage collection');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}


diag "on instance() ErrorTextDialog";
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $dialog = Gtk2::Ex::ErrorTextDialog->instance;
         $dialog->realize;
         return $dialog;
       },
       destructor => \&Test::Weaken::Gtk2::destructor_destroy,
       contents => \&Test::Weaken::Gtk2::contents_container,
     });
  is ($leaks, undef, 'Test::Weaken deep garbage collection');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}

# with save dialog
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $error_dialog = Gtk2::Ex::ErrorTextDialog->new;
         my $save_dialog = do {
           local $SIG{'__WARN__'} = \&MyTestHelpers::warn_suppress_gtk_icon;
           $error_dialog->_save_dialog
         };
         $error_dialog->present;
         $save_dialog->present;
         return [ $error_dialog, $save_dialog ];
       },
       # save dialog is destroy-with-parent, so just destroy it
       destructor => \&Test::Weaken::Gtk2::destructor_destroy,
       contents => \&Test::Weaken::Gtk2::contents_container,
     });
  is ($leaks, undef,
      'Test::Weaken deep garbage collection -- with save dialog too');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}

exit 0;
