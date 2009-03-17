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

use 5.008001;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::Basename;

WriteMakefile
  (NAME         => 'Gtk2-Ex-ErrorTextDialog',
   ABSTRACT     => 'Dialog showing error messages in a TextView.',
   VERSION_FROM => 'lib/Gtk2/Ex/ErrorTextDialog.pm',
   AUTHOR       => 'Kevin Ryde <user42@zip.com.au>',
   LICENSE      => 'gpl',
   SIGN         => 1,

   PREREQ_PM    => {
                    'Glib::Ex::SignalIds' => 0,

                    'Gtk2' => 0,  # probably any version ok
                    'Gtk2::Pango' => 0,

                    # version 1.16 for bind_textdomain_filter() to mung
                    # gettext strings
                    'Locale::TextDomain' => 1.16,
                    # Locale::Messages doesn't declare a version, only in
                    # Locale::TextDomain
                    'Locale::Messages'   => 0,
                   },
   clean     => { FILES => [ '$(POT_TEMP_FILE)' # if bad xgettext
                           ] },

   EXTRA_META => <<'HERE',
optional_features:
    maximum_tests:
        description: Have "make test" do as much as possible.
        requires:
            Test::Pod: 1.00
            Test::Weaken: 1.002
no_index:
    directory:
        - devel
resources:
    homepage: http://www.geocities.com/user42_kevin/gtk2-ex-errortextdialog/index.html
    license: http://www.gnu.org/licenses/#GPL
HERE
  );



sub MY::postamble {
  my ($self) = @_;
  my $ret = <<'MAKE_FRAG';

#---------------------------------------------------------------------------
# message translation stuff

MAKE_FRAG

  # must have PO_FILES var before use in dependency
  $ret .= generate_po_rules($self);

  $ret .= <<'MAKE_FRAG';

POT_FILE = po/$(DISTNAME).pot
pot: $(POT_FILE)

POT_TEMP_FILE = $(DISTNAME)-messages.tmp
$(POT_FILE): po/header.pot $(PO_FILES)
	xgettext \
	  --omit-header \
	  --add-comments=TRANSLATORS: \
	  --width=78 \
	  --msgid-bugs-address='Kevin Ryde <user42@zip.com.au>' \
	  --copyright-holder="Kevin Ryde" \
	  --default-domain=$(DISTNAME) \
	  --package-name=$(DISTNAME) \
	  --package-version='$(VERSION)' \
	  --output=$(POT_TEMP_FILE) \
	  --from-code=utf-8 \
	  --language=Perl \
	  --keyword=__ \
	  --keyword=__x \
	  --keyword=__nx:1,2 \
	  $(PO_FILES)
	cat po/header.pot $(POT_TEMP_FILE) >$(POT_FILE)
	rm $(POT_TEMP_FILE)

#------------------------------------------------------------------------------
# misc devel stuff

myman:
	mv MANIFEST MANIFEST.old
	touch SIGNATURE
	(make manifest 2>&1; diff -u MANIFEST.old MANIFEST) |less

LINT_FILES = $(TO_INST_PM) t/*.t examples/*.pl devel/*.pl
lint:
	for i in $(LINT_FILES); do perl -MO=Lint $$i; done
pc:
	-podchecker $(LINT_FILES)
	perlcritic $(LINT_FILES)
unused:
	for i in $(LINT_FILES); do perl -Mwarnings::unused -I lib $$i; done

# find files in the dist with mod times this year, but without this year in
# the copyright line
copyright-years-check:
	year=`date +%Y`; \
	tar tvfz $(DISTVNAME).tar.gz \
	| egrep '$$year-|debian/copyright' \
	| sed 's:^.*$(DISTVNAME)/::' \
	| (result=0; \
	  while read i; do \
	    case $$i in \
	      '' | */ \
	      | debian/changelog | debian/compat \
	      | t/pod.t \
	      | COPYING | MANIFEST* | SIGNATURE | META.yml) \
	      continue ;; \
	    esac; \
	    if test -e "$(srcdir)/$$i"; then f="$(srcdir)/$$i"; \
	    else f="$$i"; fi; \
	    if ! grep -q "Copyright.*$$year" $$f; then \
	      echo "$$i":"1: this file"; \
	      grep Copyright $$f; \
	      result=1; \
	    fi; \
	  done; \
	  exit $$result)

debug-constants-check:
	if egrep -n 'DEBUG => [^0]' $(TO_INST_PM); then exit 1; else exit 0; fi

diff-prev:
	rm -rf diff.tmp
	mkdir diff.tmp
	cd diff.tmp \
	&& tar xfz ../$(NAME)-`expr $(VERSION) - 1`.tar.gz \
	&& tar xfz ../$(NAME)-$(VERSION).tar.gz
	-cd diff.tmp; diff -ur $(NAME)-`expr $(VERSION) - 1` \
	                       $(NAME)-$(VERSION) >tree.diff
	-less diff.tmp/tree.diff
	rm -rf diff.tmp

MAKE_FRAG

  return $ret;
}

# $self is a MakeMaker object, return a string of rules for the po/mo files
# Each po/XX.po is merged from the .pot, and generates a .mo under LocaleData.
sub generate_po_rules {
  my ($self) = @_;
  #   use Data::Dumper;
  #   print Dumper($self);
  my $ret = '';

  my @pmfiles = grep {/\.pm$/} keys %{$self->{'PM'}};
  my $pmfiles_list = $self->wraplist (@pmfiles);
  $ret .= "\
# basically all the .pm's from \$(TO_INST_PM)
PO_FILES = $pmfiles_list
";

  my @mofiles;
  my @pofiles;
  foreach my $pofile (glob('po/*.po')) {
    my $lang = File::Basename::basename ($pofile, '.po');
    my $mofile = "lib/LocaleData/$lang/LC_MESSAGES/$(DISTNAME).mo";
    push @pofiles, $pofile;
    push @mofiles, $mofile;

    $ret .= "\
$pofile: \$(POT_FILE)
	msgmerge --verbose --update \$@ \$<
	touch \$@
$mofile: $pofile
	msgfmt --check --statistics --verbose -o \$@ \$<
";
  }
  $ret = "mo: " . join(' ',@mofiles) . "\n" . $ret;
  $ret = "po: " . join(' ',@pofiles) . "\n" . $ret;

  return $ret;
}
