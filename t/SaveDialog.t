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

use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin,'inc');
use MyTestHelpers;
use Test::Weaken::Gtk2;

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

my $want_version = 4;
ok ($Gtk2::Ex::ErrorTextDialog::SaveDialog::VERSION >= $want_version,
    'VERSION variable');
ok (Gtk2::Ex::ErrorTextDialog::SaveDialog->VERSION  >= $want_version,
    'VERSION class method');
ok (eval { Gtk2::Ex::ErrorTextDialog::SaveDialog->VERSION($want_version); 1 },
    "VERSION class check $want_version");
ok (! eval { Gtk2::Ex::ErrorTextDialog::SaveDialog->VERSION($want_version + 1000); 1 },
    "VERSION class check " . ($want_version + 1000));
{
  my $dialog = do {
    local $SIG{'__WARN__'} = \&MyTestHelpers::warn_suppress_gtk_icon;
    Gtk2::Ex::ErrorTextDialog::SaveDialog->new;
  };

  ok ($dialog->VERSION  >= $want_version,
      'VERSION object method');
  ok (eval { $dialog->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  ok (! eval { $dialog->VERSION($want_version + 1000); 1 },
      "VERSION object check " . ($want_version + 1000));

  $dialog->destroy;
}

{
  my $dialog = do {
    local $SIG{'__WARN__'} = \&MyTestHelpers::warn_suppress_gtk_icon;
    Gtk2::Ex::ErrorTextDialog::SaveDialog->new;
  };
  require Scalar::Util;
  Scalar::Util::weaken ($dialog);
  $dialog->destroy;
  MyTestHelpers::main_iterations ();
  is ($dialog, undef, 'garbage collect after destroy');
}

exit 0;
