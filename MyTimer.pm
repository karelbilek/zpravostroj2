package MyTimer;

use 5.008;
use strict;
use warnings;
use forks;
use forks::shared;

my $bezi:shared;
my $start:shared;
my %measured:shared;

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
	if (defined $what) {
		$bezi = undef;
	
		my $st = $start;
		my $ted = time;
	
		my $addto = $ted-$st;
		my $mw = $measured{$what} || 0;
		my $nw = $mw + $addto; 
	
		$measured{$what}=$nw;
	}
	
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
	
	print "Celkovy cas : $soucet sekund\n";
	
	print "CASY:","\n";
	
	my %res;
	for (keys %measured) {
		$res{$_} = (100 * $measured{$_} / $soucet);
	}
	for (sort {$res{$b}<=>$res{$a}} keys %measured) {
		print $_, " ma ", $res{$_}, "%\n";
	}
	
	print "CHYBY:\n";
	
	for (keys %errors) {
		print $_," dela chyb :", $errors{$_},"\n";
	}
}



1;