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
use PerlIO;   # for F_UTF8
use Devel::GlobalDestruction ();
our $VERSION = 3;

# If there's both errors and warnings from a "require" file then a
# $SIG{'__WARN__'} handler can run while PL_error_count is non-zero.  It's
# then not possible to load modules like ErrorTextDialog.pm which use BEGIN
# blocks, they get "BEGIN not safe after compilation error".
#
# The strategy at the moment is to pre-load enough to get a message to
# STDERR, and then if ErrorTextDialog.pm can't load (and isn't already
# loaded) hold in @pending_messages until later.
#
my @pending_messages;
if (_fh_prints_wide('STDERR')) {
    require Encode;
    require I18N::Langinfo;
}

# not documented ...
our $exception_handler_depth = 0;

sub exception_handler {
  my ($msg) = @_;

  # Normally $SIG handlers run without themselves shadowed out, and the Glib
  # exception handler doesn't re-invoke, so suspect warnings or errors in
  # the code here won't recurse normally, but have this as some protection
  # anyway.
  #
  if ($exception_handler_depth >= 3) {
    return 1; # stay installed
  }
  if ($exception_handler_depth >= 2) {
    print STDERR "ErrorTextDialog::Handler - ignoring recursive exception_handler calls\n";
    return 1; # stay installed
  }
  local $exception_handler_depth = $exception_handler_depth + 1;

  my $stderr_wide = _fh_prints_wide('STDERR');
  if ($stderr_wide) {
    $msg = _maybe_locale_bytes_to_wide ($msg);
    print STDERR $msg;  # wide chars
    if (Devel::GlobalDestruction::in_global_destruction()) {
      return 1; # stay installed
    }
  } else {
    print STDERR $msg;  # bytes
    if (Devel::GlobalDestruction::in_global_destruction()) {
      return 1; # stay installed
    }
    $msg = _maybe_locale_bytes_to_wide ($msg);
  }

  unshift @pending_messages, $msg;
  if (_attempt_load ('Gtk2::Ex::TextView::FollowAppend')
      && _attempt_load ('Gtk2::Ex::ErrorTextDialog')) {
    while (@pending_messages) {
      $msg = pop @pending_messages;
      # Various internal Perl_warn() and Perl_warner() calls have the
      # message followed by a second separate call for an extra remark about
      # what might be wrong.  Append the latter instead of making it a
      # separate message.
      my $method = ($msg =~ /^\t/ ? 'append_message' : 'add_message');
      Gtk2::Ex::ErrorTextDialog->$method ($msg);
      Gtk2::Ex::ErrorTextDialog->popup (undef);
    }
  } else {
    $msg = $@;
    if ($stderr_wide) { $msg = _maybe_locale_bytes_to_wide ($msg) }
    print STDERR $msg;
  }
  return 1; # stay installed
}

sub _attempt_load {
  my ($class) = @_;
  # print "\nrequire $class\n";
  if (eval "require $class") {
    return 1;
  } else {
    # print "eval bad: $@\n";
    if ($@ =~ /BEGIN not safe/) {
      my $filename = $class;
      $filename =~ s{::}{/};
      delete $INC{"$filename.pm"}; # retry later
    }
    return 0;
  }
}

sub warn_handler {
  my ($msg) = @_;
  if ($msg =~ /^\t/) {
  }
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
  return (PerlIO::get_layers($fh, output => 1, details => 1))[-1] # top flags
    & PerlIO::F_UTF8();
}

# If $str is not wide, and it has some non-ascii, then try to decode them in
# the locale charset.  PERLQQ means bad stuff is escaped.
sub _maybe_locale_bytes_to_wide {
  my ($str) = @_;
  if (! utf8::is_utf8 ($str) && $str =~ /[^[:ascii:]]/) {
    require Encode;
    my $charset = _locale_charset_or_ascii();
    $str = Encode::decode ($charset, $str, Encode::FB_PERLQQ());
  }
  return $str;
}

# _locale_charset_or_ascii() returns the locale charset from I18N::Langinfo,
# or 'ASCII' if nl_langinfo() is not available.
#
# langinfo() croaks "nl_langinfo() not implemented on this architecture" if
# not available.  Though anywhere able to run Gtk would have nl_langinfo(),
# wouldn't it?
#
my $_locale_charset_or_ascii;
sub _locale_charset_or_ascii {
  goto $_locale_charset_or_ascii;
}
BEGIN {
  $_locale_charset_or_ascii = sub {
    require I18N::Langinfo;
    my $subr = sub { I18N::Langinfo::langinfo(I18N::Langinfo::CODESET()) };
    if (! eval { &$subr(); 1 }) {
      $subr = sub { 'ASCII' };
    }
    goto ($_locale_charset_or_ascii = $subr);
  };
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

This module supplies error and warning handler functions which display their
messages in an ErrorTextDialog, as well as printing to C<STDERR>.  The
handlers are small and the idea is to keep memory use down by not loading
the ErrorTextDialog until needed.  If your program works then the dialog may
never be needed!

When a new error occurs an existing ErrorTextDialog is raised so the error
is seen.  It's not "presented" though, so the keyboard focus is unchanged
(unless the window manager is focus-follows-mouse style).  This also means
if the dialog is iconified it's not re-opened for a new message, just the
icon is raised (by the window manager).  Iconifying is a good way to hide
the errors if there's a big cascade.  Perhaps the way this works will change
though.

The default action on closing the error dialog is to hide it, so past
messages remain.  In an application it can be good to have a menu entry etc
which pops up the dialog with C<< Gtk2::Ex::ErrorTextDialog->present >> or
similar, so the user can see past errors after closing the dialog.

=head2 Wide Chars

The dialog displays unicode characters; if a message is a byte string then
the dialog C<add_message> assumes it's in the locale charset and converts
for display.  If C<STDERR> takes wide chars (because it has an encoding
layer pushed) then the same conversion is used to print to it.

If C<STDERR> only takes raw bytes but a message string has wide chars, then
currently they're just printed as normal and will generally provoke a "wide
char in print" warning.  Perhaps this will change in the future.

=head2 Global Destruction

During "global destruction" of objects when Perl or a Perl thread is exiting
(see L<perlobj/Two-Phased Garbage Collection>), messages are printed to
C<STDERR> but not put to the dialog.  The dialog is an object and is either
already destroyed or is about to be destroyed at that point.

Exceptions during global destruction can arise from C<DESTROY> methods on
Perl objects and C<destroy> etc signal emissions on Gtk objects.  Global
destruction phase is identified using
L<C<Devel::GlobalDestruction>|Devel::GlobalDestruction>.

=head2 Compilation Errors and Warnings

In a C<require> etc, if both errors and warnings occur during the compile
then C<$SIG{__WARN__}> calls can be made while a compile error is pending.
Perl doesn't allow the handler code to load other modules in that case
("BEGIN not safe after errors").

C<exception_handler> below will print to C<STDERR> immediately but if the
ErrorTextDialog code hasn't already been loaded then it accumulates messages
until it's possible to load and create the dialog.  Generally this is a
short time later when the compile error comes through the handler.

The prohibition on C<BEGIN> is to protect code which depends on a prior
C<import> etc having run.  (Perhaps it's possible to load something
unrelated like ErrorTextDialog or Encode, or at least attempt it, if the
pending errors could somehow be suspended.)

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

=item C<< Gtk2::Ex::ErrorTextDialog::Handler::log_handler ($log_domain, $log_levels, $message) >>

A function suitable for use with C<< Glib::Log->set_handler >> (see
L<Glib::Log>).  It forms a message similar to the Glib default handler and
prints and displays per the C<exception_handler> function above.

    Glib::Log->set_handler ('My-Domain', ['warning','info'],
      \&Gtk2::Ex::ErrorTextDialog::Handler::log_handler);

As of Glib-Perl 1.200, various standard log domains are trapped already and
turned into Perl C<warn> calls (see C<gperl_handle_logs_for> in
L<Glib::xsapi>).  So if you trap C<< $SIG{'__WARN__'} >> then you already
get Glib and Gtk logs without any explicit C<Glib::Log> handlers.

=back

=head1 SEE ALSO

L<Gtk2::Ex::ErrorTextDialog>, L<Glib/EXCEPTIONS>, L<perlipc>,
L<Glib::xsapi>, L<Devel::GlobalDestruction>

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
