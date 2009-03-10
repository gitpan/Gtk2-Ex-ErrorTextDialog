$SIG{'__WARN__'} = \&handler;
print "  sigwarn is $SIG{'__WARN__'}\n";

sub handler {
  print "warn handler\n";
  print "  sigwarn is $SIG{'__WARN__'}\n";
  warn "another level\n";
}
warn "a warning\n";
