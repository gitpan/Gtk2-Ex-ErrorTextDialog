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


use strict;
use warnings;
use Gtk2::Ex::ErrorTextDialog;
use Test::More;

require Gtk2;
Gtk2->disable_setlocale;  # leave LC_NUMERIC alone for version nums
my $have_display = Gtk2->init_check;
if (! $have_display) {
  plan skip_all => "due to no DISPLAY available";
}
plan tests => 19;

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
ok ($Gtk2::Ex::ErrorTextDialog::VERSION >= $want_version,
    'VERSION variable');
ok (Gtk2::Ex::ErrorTextDialog->VERSION  >= $want_version,
    'VERSION class method');
ok (eval { Gtk2::Ex::ErrorTextDialog->VERSION($want_version); 1 },
    "VERSION class check $want_version");
{ my $check_version = $want_version + 1000;
  ok (! eval { Gtk2::Ex::ErrorTextDialog->VERSION($check_version); 1 },
      "VERSION class check $check_version");
}
{
  my $dialog = Gtk2::Ex::ErrorTextDialog->new;

  ok ($dialog->VERSION  >= $want_version,
      'VERSION object method');
  ok (eval { $dialog->VERSION($want_version); 1 },
      "VERSION object check $want_version");
  my $check_version = $want_version + 1000;
  ok (! eval { $dialog->VERSION($check_version); 1 },
      "VERSION class check $check_version");

  $dialog->destroy;
}

#------------------------------------------------------------------------------
# Scalar::Util::weaken

diag "Scalar::Util::weaken";
{
  my $dialog = Gtk2::Ex::ErrorTextDialog->new;
  require Scalar::Util;
  Scalar::Util::weaken ($dialog);
  $dialog->destroy;
  main_iterations ();
  is ($dialog, undef, 'garbage collect after destroy');
}

#------------------------------------------------------------------------------
# instance()

{
  my $instance = Gtk2::Ex::ErrorTextDialog->instance;
  my $i2 = Gtk2::Ex::ErrorTextDialog->instance;
  is ($instance, $i2, 'instance() same from two calls');

  $instance->destroy;
  $i2 = Gtk2::Ex::ErrorTextDialog->instance;
  isnt ($instance, $i2, 'instance() different after ->destroy');
}

#------------------------------------------------------------------------------
# _textbuf_ensure_final_newline()

{
  my $textbuf = Gtk2::TextBuffer->new;
  foreach my $elem (['', ''],
                    ["\n", "\n"],
                    ["hello", "hello\n"],
                    ["hello\n", "hello\n"],
                    ["hello\nhello", "hello\nhello\n"],
                    ["hello\nhello\n", "hello\nhello\n"],
                   ) {
    my ($text, $want) = @$elem;

    $textbuf->set (text => $text);
    Gtk2::Ex::ErrorTextDialog::_textbuf_ensure_final_newline($textbuf);
    is ($textbuf->get('text'), $want,
        "_textbuf_ensure_final_newline() on '$text'");
  }
}

#------------------------------------------------------------------------------
# _message_dialog_set_text()

{
  my $dialog = Gtk2::MessageDialog->new (undef, [], 'info', 'ok',
                                         'An informational message');
  Gtk2::Ex::ErrorTextDialog::_message_dialog_set_text($dialog, 'new message');

  if ($dialog->find_property('text')) {
    is ($dialog->get('text'), 'new message',
        '_message_dialog_text_widget() messagedialog');
  } else {
    ok (1,
        "_message_dialog_text_widget() no 'text' property to read back");
  }
  $dialog->destroy;
}

#------------------------------------------------------------------------------
# get_text()

{
  my $dialog = Gtk2::Ex::ErrorTextDialog->new;
  is ($dialog->get_text, '', 'get_text() empty');
  $dialog->add_text ('hello');
  is ($dialog->get_text, 'hello', 'get_text() some text');
  $dialog->destroy;
}

exit 0;
