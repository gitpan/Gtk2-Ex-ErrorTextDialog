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

my $have_test_weaken = eval "use Test::Weaken 2.000; 1";
if (! $have_test_weaken) {
  plan skip_all => "due to Test::Weaken 2.000 not available -- $@";
}
diag ("Test::Weaken version ", Test::Weaken->VERSION);

require Gtk2;
Gtk2->disable_setlocale;  # leave LC_NUMERIC alone for version nums
my $have_display = Gtk2->init_check;
if (! $have_display) {
  plan skip_all => "due to no DISPLAY available";
}

plan tests => 5;

diag ("Perl-Gtk2    version ",Gtk2->VERSION);
diag ("Perl-Glib    version ",Glib->VERSION);
diag ("Compiled against Glib version ",
      Glib::MAJOR_VERSION(), ".",
      Glib::MINOR_VERSION(), ".",
      Glib::MICRO_VERSION());
diag ("Running on       Glib version ",
      Glib::major_version(), ".",
      Glib::minor_version(), ".",
      Glib::micro_version());
diag ("Compiled against Gtk version ",
      Gtk2::MAJOR_VERSION(), ".",
      Gtk2::MINOR_VERSION(), ".",
      Gtk2::MICRO_VERSION());
diag ("Running on       Gtk version ",
      Gtk2::major_version(), ".",
      Gtk2::minor_version(), ".",
      Gtk2::micro_version());

sub main_iterations {
  my $count = 0;
  while (Gtk2->events_pending) {
    $count++;
    Gtk2->main_iteration_do (0);
  }
  diag "main_iterations(): ran $count events/iterations\n";
}
sub container_children_recursively {
  my ($widget) = @_;
  if ($widget->can('get_children')) {
    return ($widget,
            map { container_children_recursively($_) } $widget->get_children);
  } else {
    return ($widget);
  }
}

#------------------------------------------------------------------------------
# TextView::FollowAppend

diag "on TextView::FollowAppend->new()";
{
  require Gtk2::Ex::TextView::FollowAppend;
  my $leaks = Test::Weaken::leaks
    (sub { return Gtk2::Ex::TextView::FollowAppend->new });
  is ($leaks, undef, 'Test::Weaken deep garbage collection');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}
diag "on TextView::FollowAppend->new_with_buffer()";
{
  my $leaks = Test::Weaken::leaks
    (sub {
       my $textbuf = Gtk2::TextBuffer->new;
       my $textview
         = Gtk2::Ex::TextView::FollowAppend->new_with_buffer ($textbuf);
       return [ $textview, $textbuf ];
     });
  is ($leaks, undef, 'Test::Weaken deep garbage collection');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}


#------------------------------------------------------------------------------
# ErrorTextDialog

diag "on new() ErrorTextDialog";
{
  my $leaks = Test::Weaken::leaks
    ({ constructor => sub {
         my $dialog = Gtk2::Ex::ErrorTextDialog->new;
         $dialog->realize;
         return [ $dialog, container_children_recursively($dialog) ];
       },
       destructor => sub {
         my ($aref) = @_;
         my $dialog = $aref->[0];
         $dialog->destroy;
       }
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
         return [ $dialog, container_children_recursively($dialog) ];
       },
       destructor => sub {
         my ($aref) = @_;
         my $dialog = $aref->[0];
         $dialog->destroy;
       }
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
         my $save_dialog = $error_dialog->_save_dialog;
         $error_dialog->present;
         $save_dialog->present;
         return [ $error_dialog, $save_dialog,
                  container_children_recursively($error_dialog),
                  container_children_recursively($save_dialog) ];
       },
       destructor => sub {
         my ($aref) = @_;
         my ($error_dialog) = @$aref;
         $error_dialog->destroy; # save dialog is destroy-with-parent
         main_iterations();
       }
     });
  is ($leaks, undef,
      'Test::Weaken deep garbage collection -- with save dialog too');
  if ($leaks) {
    diag "Test-Weaken ", explain $leaks;
  }
}

exit 0;
