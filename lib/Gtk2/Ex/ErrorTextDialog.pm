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


package Gtk2::Ex::ErrorTextDialog;
use 5.008001; # for utf8::is_utf8()
use strict;
use warnings;
use Gtk2;
use Locale::TextDomain 1.16; # for bind_textdomain_filter()
use Locale::TextDomain ('Gtk2-Ex-ErrorTextDialog');
use Locale::Messages;

our $VERSION = 2;

# set this to 1 for some diagnostic prints
use constant DEBUG => 0;

Locale::Messages::bind_textdomain_codeset ('Gtk2-Ex-ErrorTextDialog','UTF-8');
Locale::Messages::bind_textdomain_filter  ('Gtk2-Ex-ErrorTextDialog',
                                           \&Locale::Messages::turn_utf_8_on);

use Glib::Object::Subclass
  'Gtk2::MessageDialog',
  signals => { destroy => \&_do_destroy };

use constant { RESPONSE_CLEAR => 0,
               RESPONSE_SAVE  => 1,

               MESSAGE_SEPARATOR => "-----\n" };

my $instance;
sub instance {
  my ($class) = @_;
  if (! $instance) {
    $instance = $class->new;
    $instance->signal_connect (delete_event => \&Gtk2::Widget::hide_on_delete);
  }
  return $instance;
}

sub INIT_INSTANCE {
  my ($self) = @_;
  $self->{'pending_separator'} = '';

  { my $title = __('Errors');
    if (defined (my $appname = Glib::get_application_name())) {
      $title = "$appname: $title";
    }
    $self->set_title ($title);
  }

  $self->set (message_type => 'error',
              resizable => 1);

  $self->add_buttons ('gtk-clear'   => RESPONSE_CLEAR,
                      'gtk-save-as' => RESPONSE_SAVE,
                      'gtk-close'   => 'close');

  # connect to self instead of a class handler because as of Gtk2-Perl 1.200
  # a Gtk2::Dialog class handler for 'response' is called with response IDs
  # as numbers, not enum strings like 'accept'
  $self->signal_connect (response   => \&_do_response);

  my $vbox = $self->vbox;

  my $scrolled = Gtk2::ScrolledWindow->new;
  $scrolled->set_policy ('never', 'always');
  $vbox->pack_start ($scrolled, 1,1,0);

  my $textbuf = $self->{'textbuf'} = Gtk2::TextBuffer->new;
  $textbuf->signal_connect ('changed', \&_do_textbuf_changed, $self);
  _do_textbuf_changed ($textbuf, $self);  # initial settings

  require Gtk2::Ex::TextView::FollowAppend;
  my $textview = $self->{'textview'}
    = Gtk2::Ex::TextView::FollowAppend->new_with_buffer ($textbuf);
  $textview->set (wrap_mode => 'char',
                  editable  => 0);
  $scrolled->add ($textview);

  $vbox->show_all;
  $self->set_default_size_chars (70, 20);
}

# 'destroy' class closure
# this can be called more than once!
sub _do_destroy {
  my ($self) = @_;
  if (DEBUG) { print "ErrorTextDialog destroy $self\n"; }

  # break circular reference from $textbuf 'changed' signal userdata $self
  # nothing for $self->{'save_dialog'} as it's destroy-with-parent already
  delete $self->{'textbuf'};

  if (defined $instance && $self == $instance) {
    # ready for subsequence instance() call to make a new one
    undef $instance;
  }
  $self->signal_chain_from_overridden;
}

# 'changed' signal on the textbuf
sub _do_textbuf_changed {
  my ($textbuf, $self) = @_;
  if (DEBUG) { print "ErrorTextDialog textbuf changed\n"; }
  my $any_errors = ($textbuf->get_char_count != 0);
  _message_dialog_set_text ($self, $any_errors
                            ? __('An error has occurred')
                            : __('No errors'));
  $self->set_response_sensitive (RESPONSE_CLEAR, $any_errors);
}

# set_default_size() based on desired size_request() with a sensible rows
# and columns size for the TextView.  This is just a default, the user can
# resize to smaller.  Must have 'resizable' turned on in INIT_INSTANCE above
# to make this work (the default from GtkMessageDialog is resizable false).
#
# not documented yet ...
sub set_default_size_chars {
  my ($self, $width_chars, $height_chars) = @_;
  my $textview = $self->{'textview'};
  my $scrolled = $textview->get_parent;
  require Gtk2::Pango;
  my $context = $textview->get_pango_context;
  my $font_desc = $textview->style->font_desc;
  my $metrics = $context->get_metrics ($font_desc, $context->get_language);
  my $char_width_pixels = $metrics->get_approximate_char_width
    / Gtk2::Pango::PANGO_SCALE();
  my $line_height_pixels = ($metrics->get_ascent + $metrics->get_descent)
    / Gtk2::Pango::PANGO_SCALE();

  # Width on textview so the vertical scrollbar is added on top, but height
  # on the scrolled since the scrollbar means any desired height from the
  # textview is ignored.  Fractions of a pixel get rounded in the calls.
  #
  $textview->set_size_request ($width_chars * $char_width_pixels, -1);
  $scrolled->set_size_request (-1, $height_chars * $line_height_pixels);

  my $req = $self->size_request;
  $scrolled->set_size_request (-1, -1);
  $textview->set_size_request (-1, -1);

  $self->set_default_size ($req->width, $req->height);
}

#-----------------------------------------------------------------------------
# button/response actions

sub _do_response {
  my ($self, $response) = @_;
  if ($response eq RESPONSE_CLEAR) {
    $self->clear;

  } elsif ($response eq RESPONSE_SAVE) {
    $self->popup_save_dialog;

  } elsif ($response eq 'close') {
    # as per a keyboard close, defaults to raising 'delete-event', which in
    # turn defaults to a destroy
    $self->signal_emit ('close');
  }
}

sub clear {
  my ($self) = @_;
  ref $self or $self = $self->instance;
  $self->{'pending_separator'} = '';
  my $textbuf = $self->{'textbuf'};
  $textbuf->delete ($textbuf->get_start_iter, $textbuf->get_end_iter);
}

sub popup_save_dialog {
  my ($self) = @_;
  ref $self or $self = $self->instance;
  $self->_save_dialog->present;
}
sub _save_dialog {
  my ($self) = @_;
  return ($self->{'save_dialog'} ||= do {
    require Gtk2::Ex::ErrorTextDialog::SaveDialog;
    my $save_dialog = Gtk2::Ex::ErrorTextDialog::SaveDialog->new;
    # set_transient_for() is always available, whereas 'transient-for' as
    # property only since gtk 2.10
    $save_dialog->set_transient_for ($self);
    $save_dialog
  });
}

#-----------------------------------------------------------------------------
# messages

sub get_text {
  my ($self) = @_;
  return $self->{'textbuf'}->get('text');
}

sub add_message {
  my ($class_or_self, $msg) = @_;
  $class_or_self->add_separator;
  $class_or_self->add_text ($msg);
  $class_or_self->add_separator;
}

# not documented yet ...
sub append_message {
  my ($self, $msg) = @_;
  ref $self or $self = $self->instance;
  my $textbuf = $self->{'textbuf'};
  $textbuf->insert ($textbuf->get_end_iter, $msg);
  $self->add_separator;
}

# not documented yet ...
sub add_text {
  my ($self, $msg) = @_;
  ref $self or $self = $self->instance;

  require Gtk2::Ex::ErrorTextDialog::Handler;
  $msg = $self->{'pending_separator'}
    . Gtk2::Ex::ErrorTextDialog::Handler::_maybe_locale_bytes_to_wide($msg);
  $self->{'pending_separator'} = '';

  my $textbuf = $self->{'textbuf'};
  $textbuf->insert ($textbuf->get_end_iter, $msg);
}

# not documented yet ...
sub add_separator {
  my ($self) = @_;
  ref $self or $self = $self->instance;

  my $textbuf = $self->{'textbuf'};
  _textbuf_ensure_final_newline ($textbuf);
  if ($textbuf->get_char_count) {
    # not empty, so want separator
    $self->{'pending_separator'} = MESSAGE_SEPARATOR;
  }
}


# not sure about this yet ...
#
# =item C<< Gtk2::Ex::ErrorTextDialog->popup_add_message ($str) >>
# 
# =item C<< Gtk2::Ex::ErrorTextDialog->popup_add_message ($str, $parent) >>
# 
# =item C<< $errordialog->popup_add_message ($str) >>
# 
# =item C<< $errordialog->popup_add_message ($str, $parent) >>
# 
# Add C<$str> to the error dialog with C<add_message> below, and popup the
# dialog so it's visible.
# 
# Optional C<$parent> is a widget which the error relates to, or C<undef> for
# none.  C<$parent> may help the window manager position the error dialog when
# first displayed, but is not used after that.
#
# not documented yet ...
sub popup_add_message {
  my ($self, $msg, $parent) = @_;
  $self->popup ($parent);
  $self->add_message ($msg);
}
# not documented yet ... might get some options for how aggressively to pop up
sub popup {
  my ($self, $parent) = @_;
  ref $self or $self = $self->instance;

  if ($self->mapped) {
    $self->window->raise;
  } else {
    # allow for $parent a non-toplevel
    if ($parent) { $parent = $parent->get_toplevel; }
    $self->set_transient_for ($parent);
    $self->present;
    $self->set_transient_for (undef);
  }
}

# ENHANCE-ME: would prefer to show the same string as
# g_log_default_handler(), or even what gperl_log_handler() gives
sub _log_to_string {
  my ($log_domain, $log_level, $message) = @_;

  $log_level -= ['recursion','fatal'];
  $log_level = join('-', @$log_level) || 'LOG';

  return (($log_domain ? "$log_domain-" : "** ")
          . "\U$log_level\E: "
          . (defined $message ? $message : "(no message)"))
}

# probably not wanted ...
# sub popup_add_log {
#   my ($class_or_self, $log_domain, $log_level, $message, $parent) = @_;
#   $self->popup ($parent);
#   $self->add_log ($log_domain, $log_level, $message);
# }
# sub add_log {
#   my ($class_or_self, $log_domain, $log_level, $message) = @_;
#   $class_or_self->add_message
#     (_log_to_string ($log_domain, $log_level, $message));
# }

#-----------------------------------------------------------------------------
# generic helpers

# append a newline to $textbuf if it's non-empty and doesn't already end
# with a newline
sub _textbuf_ensure_final_newline {
  my ($textbuf) = @_;
  my $len = $textbuf->get_char_count || return;  # nothing added if empty

  my $end_iter = $textbuf->get_end_iter;
  if ($textbuf->get_text ($textbuf->get_iter_at_offset($len-1),
                          $end_iter,
                          0) # without invisible text
      ne "\n") {
    $textbuf->insert ($end_iter, "\n");
  }
}

# _message_dialog_set_text() sets the text part of a Gtk2::MessageDialog.
# Gtk 2.10 up has this as a 'text' property, or in past versions it's
# necessary to diag out the label child widget.
#
# Gtk2::Label doesn't have a 'text' property, and Gtk2::MessageDialog
# doesn't have a set_text() method, so the two sets have to be different.
#
# This is in a BEGIN block so the unused sub is garbage collected.
#
BEGIN {
  *_message_dialog_set_text = Gtk2::MessageDialog->find_property('text')
    ? sub {
      my ($dialog, $text) = @_;
      $dialog->set (text => $text);
    } : sub {
      my ($dialog, $text) = @_;
      my $label = ($dialog->{__PACKAGE__.'--text-widget'} ||= do {
        require List::Util;
        my $l;
        my @w = grep {$_->isa('Gtk2::HBox')} $dialog->vbox->get_children;
        for (;;) {
          if (! @w) {
            require Carp;
            Carp::croak ('_message_dialog_text_widget(): oops, label not found');
          }
          $l = List::Util::first (sub {ref $_ eq 'Gtk2::Label'}, @w)
            and last;
          @w = map {$_->isa('Gtk2::Box') ? $_->get_children : ()} @w;
        }
        $l
      });
      $label->set_text ($text);
    };
}

1;
__END__

=head1 NAME

Gtk2::Ex::ErrorTextDialog -- display error messages in a dialog

=head1 SYNOPSIS

 # explicitly adding a message
 use Gtk2::Ex::ErrorTextDialog;
 Gtk2::Ex::ErrorTextDialog->add_message ("Something went wrong");

 # handler for all Glib exceptions
 use Gtk2::Ex::ErrorTextDialog::Handler;
 Glib->install_exception_handler
   (\&Gtk2::Ex::ErrorTextDialog::Handler::exception_handler);

=head1 WIDGET HIERARCHY

C<Gtk2::Ex::ErrorTextDialog> is a subclass of C<Gtk2::MessageDialog>.  But
for now don't rely on more than C<Gtk2::Dialog>.

    Gtk2::Widget
      Gtk2::Container
        Gtk2::Bin
          Gtk2::Window
            Gtk2::Dialog
              Gtk2::MessageDialog
                Gtk2::Ex::ErrorTextDialog

=head1 DESCRIPTION

An ErrorTextDialog presents text error messages to the user in a
L<C<Gtk2::TextView>|Gtk2::TextView>.  It's intended for technical things
like Perl errors and warnings, rather than results of normal user
operations.

    +------------------------------------+
    |   !!    An error has occurred      |
    | +--------------------------------+ |
    | | Something at foo.pl line 123   | |
    | | -----                          | |
    | | Cannot whatever at Bar.pm line | |
    | | 456                            | |
    | |                                | |
    | +--------------------------------+ |
    +------------------------------------+
    |                Clear Save-As Close |
    +------------------------------------+

L<C<Gtk2::Ex::ErrorTextDialog::Handler>|Gtk2::Ex::ErrorTextDialog::Handler>
has functions designed to hook up Glib exceptions and Perl warnings to
display in an ErrorTextDialog.

ErrorTextDialog is good if there might be a long cascade of messages from
one problem, or errors repeated on every screen draw.  In that case the
dialog scrolls along but the app might still mostly work.

The Save-As button lets the user save the messages to a file, say for a bug
report.  Cut-and-paste works in the usual way too of course.

=head1 FUNCTIONS

=head2 Creation

=over 4

=item C<< $errordialog = Gtk2::Ex::ErrorTextDialog->instance () >>

Return an ErrorTextDialog object designed to be shared by all parts of the
program.  This object is used when the methods below are called as class
functions.

You can destroy the instance with C<< $errordialog->destroy >> in the usual
way if you want.  A subsequent call to C<instance> will create a new one.

=item C<< $errordialog = Gtk2::Ex::ErrorTextDialog->new (key=>value,...) >>

Create and return a new ErrorTextDialog.  Optional key/value pairs set
initial properties as per C<< Glib::Object->new >>.  An ErrorTextDialog
created this way is separate from the C<instance()> one above.  But it's
unusual to want more than one error dialog.

=back

=head2 Messages

ErrorTextDialog works with "messages", which are simply strings.  A
horizontal separator line is added between each message, since it can be
hard to tell one from the next when long lines are word-wrapped.  Currently
the separator is just some dashes, but something slimmer might be possible.

=over 4

=item C<< Gtk2::Ex::ErrorTextDialog->add_message ($str) >>

=item C<< $errordialog->add_message ($str) >>

Add a message to the ErrorTextDialog.  C<$str> can be either Perl wide chars
or raw bytes, and it doesn't have to end with a newline.

If C<$str> is raw bytes it's assumed to be in the locale charset and is
converted to unicode for display.  Anything invalid in C<$str> is escaped,
currently just in C<PERLQQ> style (see L<Encode/Handling Malformed Data>) so
it will display, though not necessarily very well.

=item C<< Gtk2::Ex::ErrorTextDialog->get_text() >>

=item C<< $errordialog->get_text() >>

Return a wide-char string of all the messages in the ErrorTextDialog.

=back

=head2 Actions

=over 4

=item C<< Gtk2::Ex::ErrorTextDialog->clear() >>

=item C<< $errordialog->clear() >>

Remove all messages in the dialog.  This is the "Clear" button action.

=item C<< Gtk2::Ex::ErrorTextDialog->popup_save_dialog() >>

=item C<< $errordialog->popup_save_dialog() >>

Popup the Save dialog, which asks the user for a filename to save the error
messages to.  This is the "Save As" button action.

=back

=head1 SEE ALSO

L<Gtk2::Ex::ErrorTextDialog::Handler>

L<Gtk2::Ex::Carp> (which presents messages one at a time)

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
