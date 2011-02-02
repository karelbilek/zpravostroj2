package Zpravostroj::AllWordCounts;
#Package ke sledování celkových "reverzních" počtů

#Co je tím myšleno. Pro každé slovo si držím počet článků, ve kterých je uvedeno.
#To mám v jednom velkém souboru v data/all_count/counts.bz2

#V tom souboru je hash slovo->počet

#Počítám s tím, že slova se už nebudou u článků měnit. Tedy, jak už článek jednou má counts, tak není potřeba nic řešit.

#Proto si pamatuji "poslední spočítaný den" a "poslední spočítaný článek v tom dni" - když pak, později,
#potřebuji nejnovější counts, starší články už nechávám být, jenom nahraju ten hash, přičtu nové články (=novější, než to datum)
#a do counts popřičítám slova pouze z nich



use 5.008;
use strict;
use warnings;


use forks;
use forks::shared;

use Zpravostroj::Globals;
use Zpravostroj::Date;
use File::Slurp;

use Scalar::Util qw(reftype);


mkdir "data";
mkdir "data/all_count";

sub null_all {
	system("rm -r data/all_count/");
}

sub set_count {
	my $w = shift;
	dump_bz2("data/all_count/counts.bz2", $w);
}

sub get_count {
	
	
	my $c = undump_bz2("data/all_count/counts.bz2");
	
	if (!$c or reftype($c) ne "HASH") {
		return ();
	} else {
		return %$c;
	}
}

sub get_last_saved {
	if (!-e "data/all_count/date_last_counted") {
		return (new Zpravostroj::Date(day=>0, month=>0, year=>0), 0);
	}
	return (Zpravostroj::Date::get_from_file("data/all_count/date_last_counted"), read_file("data/all_count/article_last_counted"));
}

sub set_last_saved {
	my ($date, $num) = @_;
	$date->get_to_file("data/all_count/date_last_counted");
	write_file("data/all_count/article_last_counted", $num);
}



1;