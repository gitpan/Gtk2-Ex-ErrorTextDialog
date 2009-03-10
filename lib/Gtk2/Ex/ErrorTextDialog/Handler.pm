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


package Gtk2::Ex::ErrorTextDialog::Handler;
use 5.008001; # for utf8::is_utf8() and PerlIO::get_layers()
use strict;
use warnings;

our $VERSION = 1;

# not documented ...
our $exception_handler_depth = 0;

sub exception_handler {
  my ($msg) = @_;

  # Normally $SIG handlers run without themselves shadowed out, and the Glib
  # exception handler doesn't re-invoke, so suspect warnings or errors in
  # the error handling code won't recurse normally, but have this as some
  # protection anyway.
  #
  if ($exception_handler_depth >= 3) {
    return;
  }
  if ($exception_handler_depth >= 2) {
    print STDERR "ErrorTextDialog::Handler - ignoring recursive exception_handler calls\n";
    return;
  }

  local $exception_handler_depth = $exception_handler_depth + 1;
  require Gtk2::Ex::ErrorTextDialog;

  my $wide = Gtk2::Ex::ErrorTextDialog::_maybe_locale_bytes_to_wide ($msg);
  if (_fh_prints_wide('STDERR')) {
    print STDERR $wide;
  } else {
    print STDERR $msg;
  }
  Gtk2::Ex::ErrorTextDialog->popup_add_message ($wide, undef);
  return 1; # stay installed
}

sub log_handler {
  require Gtk2::Ex::ErrorTextDialog;
  exception_handler (Gtk2::Ex::ErrorTextDialog::_log_to_string (@_));
}

#------------------------------------------------------------------------------
# generic helpers

# _fh_prints_wide($fh) returns true if wide chars can be prited to file
# handle $fh.
#
# PerlIO::get_layers() is pre-loaded, probably, but PerlIO::F_UTF8() from
# PerlIO.pm is not.
#
sub _fh_prints_wide {
  my ($fh) = @_;
  require PerlIO;
  return (PerlIO::get_layers($fh, output => 1, details => 1))[-1] # top flags
    & PerlIO::F_UTF8();
}

1;
__END__

=head1 NAME

Gtk2::Ex::ErrorTextDialog::Handler -- exception handlers using ErrorTextDialog

=head1 SYNOPSIS

 use Gtk2::Ex::ErrorTextDialog::Handler;
 Glib->install_exception_handler
   (\&Gtk2::Ex::ErrorTextDialog::Handler::exception_handler);

 $SIG{'__WARN__'}
   = \&Gtk2::Ex::ErrorTextDialog::Handler::exception_handler;

 Glib::Log->set_handler ('My-Domain', ['warning','info'],
   \&Gtk2::Ex::ErrorTextDialog::Handler::log_handler);

=head1 DESCRIPTION

This module has error and warning handler functions which display their
respective messages in an ErrorTextDialog.  They're all small and the idea
is to keep memory use down by not loading the ErrorTextDialog code or
creating a dialog until needed.  If your program works then the dialog may
never be needed!

=head1 FUNCTIONS

=over 4

=item C<< Gtk2::Ex::ErrorTextDialog::Handler::exception_handler ($str) >>

A function suitable for use with C<< Glib->install_exception_handler >> (see
L<Glib/EXCEPTIONS>) or with Perl's C<< $SIG{'__WARN__'} >> (see L<perlipc>).

    Glib->install_exception_handler
      (\&Gtk2::Ex::ErrorTextDialog::Handler::exception_handler);

    $SIG{'__WARN__'}
      = \&Gtk2::Ex::ErrorTextDialog::Handler::exception_handler;

The given C<$str> is printed to C<STDERR> and displayed in the shared
ErrorTextDialog instance.  C<$str> can be an exception object too, such as a
C<Glib::Error>, and will be stringized for display.

If C<STDERR> only takes raw bytes but C<$str> has wide characters, then
currently they're just printed and will generally provoke a "wide char in
print" warning in the normal way.  Perhaps this will change in the future.

If C<STDERR> takes wide chars but C<$str> is raw bytes, then the bytes are
assumed to be in the locale charset and are converted to wide chars the same
way the ErrorTextDialog C<add_message> does.

=item C<< Gtk2::Ex::ErrorTextDialog::Handler::log_handler ($log_domain, $log_levels, $message) >>

A function suitable for use with C<< Glib::Log->set_handler >> (see
L<Glib::Log>).  It forms a message similar to the Glib default handler and
prints and displays per the C<exception_handler> function above.

    Glib::Log->set_handler ('My-Domain', ['warning','info'],
      \&Gtk2::Ex::ErrorTextDialog::Handler::log_handler);

As of Glib-Perl 1.200, various standard log domains are trapped already and
turned into Perl C<warn> calls (see C<gperl_handle_logs_for> in
L<Glib::xsapi>).  So if you trap C<< $SIG{'__WARN__'} >> then you already
get Glib and Gtk logs into the ErrorTextDialog without any explicit
C<Glib::Log> handlers.

=back

=head1 SEE ALSO

L<Gtk2::Ex::ErrorTextDialog>, L<Glib/EXCEPTIONS>, L<perlipc>, L<Glib::xsapi>

=head1 HOME PAGE

L<http://www.geocities.com/user42_kevin/gtk2-ex-errortextdialog/>

=head1 LICENSE

Gtk2-Ex-ErrorTextDialog is Copyright 2007, 2008, 2009 Kevin Ryde

Gtk2-Ex-ErrorTextDialog is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 3, or (at your option) any
later version.

Gtk2-Ex-ErrorTextDialog is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with Gtk2-Ex-ErrorTextDialog.  If not, see L<http://www.gnu.org/licenses/>.

=cut
