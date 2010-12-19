package MyTimer;

use 5.008;
use strict;
use warnings;

sub new {
	my $c = shift;
	bless {}, $c;
}

my $bezi;
my $start;
my %measured;

sub start_timing {
	my $what = shift;
	
	if (defined $bezi) {
		stop_timing();
	}
	
	$start = time;
	$bezi = $what;
}

sub stop_timing {
	my $what = $bezi;
	$bezi = undef;
	
	my $st = $start;
	my $ted = time;
	
	$measured{$what}+=($ted-$st);
	
}

my %errors;

sub count_error {
	my $what = shift;
	$errors{$what}++;
}

sub say_all {
	if (defined $bezi) {
		stop_timing();
	}
	
	my $soucet;
	for (keys %measured) {
		$soucet+=$measured{$_};
	}
	
	print "CASY:","\n";
	
	for (keys %measured) {
		print $_, " ma ", (100 * $measured{$_} / $soucet), "%\n";
	}
	
	print "CHYBY:\n";
	
	for (keys %errors) {
		print $_," dela chyb :", $errors{$_},"\n";
	}
}



1;