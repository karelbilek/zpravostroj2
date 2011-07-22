package Zpravostroj::InverseDocumentFrequencies;


#Package ke sledování celkových "reverzních" počtů

#Co je tím myšleno. Pro každé slovo si držím počet článků, ve kterých je uvedeno.

#Všechno dělám pomocí OutCounteru (můj modul pro vnější třídění)

#V tom souboru je hash slovo->počet

#Počítám s tím, že slova se už nebudou u článků měnit. Tedy, jak už článek jednou má counts, tak není potřeba nic řešit.

#Proto si pamatuji "poslední spočítaný den" a "poslední spočítaný článek v tom dni" - když pak, později,
#potřebuji nejnovější counts, starší články už nechávám být, jenom přidávám další slova



use 5.008;
use strict;
use warnings;

#kvuli "circular" use tady mám require
require Zpravostroj::AllDates;


use Zpravostroj::Globals;
use Zpravostroj::Date;
use Zpravostroj::OutCounter;

use File::Slurp;

use Scalar::Util qw(reftype);


mkdir "data";
mkdir "data/idf/";

#hlavní outcounter, kde je vše
#to delete_on_start=>0 je tam důležité!
my $outcounter = new Zpravostroj::OutCounter(name=>"data/idf/idf", delete_on_start=>0);


#Přidá hash slov
sub add_words {
	my $w = shift;
	$outcounter->add_hash($w);
}

#Vrátí IDF
sub get_frequencies {
	return $outcounter->return_counted();
	
}

#Vrátí poslední uložený
sub get_last_saved {
	if (!-e "data/idf/date_last_counted") {
		return (new Zpravostroj::Date(day=>0, month=>0, year=>0), 0);
	}
	return (Zpravostroj::Date::get_from_file("data/idf/date_last_counted"), read_file("data/idf/article_last_counted"));
}

#Nastaví dnešek a poslední dnešní článek jako poslední uložený
sub set_last_saved_today {
	my $date = new Zpravostroj::Date();
	my $count = new Zpravostroj::DateArticles(date=>$date)->get_last_number;
	_set_last_saved($date, $count);
}

#Nastaví libovolné datum/článek jako poslední
sub _set_last_saved {
	my ($date, $num) = @_;
	$date->get_to_file("data/idf/date_last_counted");
	write_file("data/idf/article_last_counted", $num);
}

#Updatne IDF matici
sub update_all {
	my ($last_date_counted, $last_article_counted) = get_last_saved();
	
	say "Last day counted je ".$last_date_counted->get_to_string();
	
	(new Zpravostroj::AllDates())->traverse(sub{
		
		my $d = shift;
		
		if (! $d->date->is_older_than($last_date_counted)) {
			say "je novejsi, jdu pocitat counts";
			my $day_count = ($last_date_counted->is_the_same_as($d->date)) 
							? (
								{$d->get_idf_after_article($last_article_counted+1)}
							) : (
								{$d->get_idf_after_article(0)}
							);
			#nemusim lockovat!
			Zpravostroj::InverseDocumentFrequencies::add_words($day_count);
		} else {
			say "Preskakuji"
		}
		
		say "done";
		
		return ();
		
	},$FORKER_SIZES{IDF_UPDATE_DAYS});
	
	$outcounter->count_it();
	set_last_saved_today;
}



1;