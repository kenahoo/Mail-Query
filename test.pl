# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

use Test;
BEGIN { plan tests => 15, todo => [] }

use Mail::Query;

######################### End of black magic.

#$::RD_TRACE = 1;
open my $fh, 'sample.txt' or die $!;
my $mail = new Mail::Query('data' => [<$fh>]);
close $fh;

ok  $mail->query("To LIKE /swarth/");
ok !$mail->query("To LIKE /gesundheit/");
ok  $mail->query("To NOT LIKE /gesundheit/");
ok  $mail->query("MIME-Version =  '1.0\n'");
ok  $mail->query("MIME-Version <= '3.0'");
ok  $mail->query("Content-type >= 'mashed/potatoes'");
ok  $mail->query("Unknown-header IS NULL");
ok  $mail->query("To IS NOT NULL");
ok  $mail->query("Recipient LIKE /swarth/");
ok  $mail->query("NOT Recipient NOT LIKE /swarth/");
ok  $mail->query("NOT (Recipient NOT LIKE /swarth/)");
ok  $mail->query("To LIKE /swarth/ AND Unknown-header IS NULL");
ok  $mail->query("To LIKE /swarth/ AND NOT (Unknown-header IS NOT NULL OR To IS NULL)");
ok  $mail->query("Body LIKE /609218347983745/");
ok !$mail->query("Body LIKE /609218347983746/");
