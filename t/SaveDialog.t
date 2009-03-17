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


use strict;
use warnings;
use Gtk2::Ex::ErrorTextDialog::SaveDialog;
use Test::More;

require Gtk2;
Gtk2->disable_setlocale;  # leave LC_NUMERIC alone for version nums
my $have_display = Gtk2->init_check;
if (! $have_display) {
  plan skip_all => "due to no DISPLAY available";
}
plan tests => 8;

sub main_iterations {
  my $count = 0;
  while (Gtk2->events_pending) {
    $count++;
    Gtk2->main_iteration_do (0);
  }
  diag "main_iterations(): ran $count events/iterations\n";
}

#------------------------------------------------------------------------------

my $want_version = 2;
ok ($Gtk2::Ex::ErrorTextDialog::SaveDialog::VERSION >= $want_version,
    'VERSION variable');
ok (Gtk2::Ex::ErrorTextDialog::SaveDialog->VERSION  >= $want_version,
    'VERSION class method');
ok (eval { Gtk2::Ex::ErrorTextDialog::SaveDialog->VERSION($want_version); 1 },
    "VERSION class check $want_version");
ok (! eval { Gtk2::Ex::ErrorTextDialog::SaveDialog->VERSION($want_version + 1000); 1 },
    "VERSION class check " . ($want_version + 1000));
{
  my $dialog = Gtk2::Ex::ErrorTextDialog::SaveDialog->new;

  ok ($dialog->VERSION  >= $want_version,
      'VERSION object method');
  ok (eval { $dialog->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  ok (! eval { $dialog->VERSION($want_version + 1000); 1 },
      "VERSION object check " . ($want_version + 1000));

  $dialog->destroy;
}

{
  my $dialog = Gtk2::Ex::ErrorTextDialog::SaveDialog->new;
  require Scalar::Util;
  Scalar::Util::weaken ($dialog);
  $dialog->destroy;
  main_iterations ();
  is ($dialog, undef, 'garbage collect after destroy');
}

exit 0;
