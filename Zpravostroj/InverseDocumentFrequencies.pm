package Zpravostroj::InverseDocumentFrequencies;
#UPDATE - komentáře pod tím už uplně neplatí. třídim vnějšim třídenim :)


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

#use Zpravostroj::AllDates;


use Zpravostroj::Globals;
use Zpravostroj::Date;
use Zpravostroj::OutCounter;

use File::Slurp;

use Scalar::Util qw(reftype);


mkdir "data";
#mkdir "data/all_count";

my $outcounter = new Zpravostroj::OutCounter(name=>"data/idf/idf", delete_on_start=>0);


sub add_words {
	my $w = shift;
	$outcounter->add_hash($w);
}


sub get_frequencies {
	return $outcounter->return_counted();
	
}

sub get_last_saved {
	if (!-e "data/idf/date_last_counted") {
		return (new Zpravostroj::Date(day=>0, month=>0, year=>0), 0);
	}
	return (Zpravostroj::Date::get_from_file("data/idf/date_last_counted"), read_file("data/idf/article_last_counted"));
}

sub set_last_saved {
	my ($date, $num) = @_;
	$date->get_to_file("data/idf/date_last_counted");
	write_file("data/idf/article_last_counted", $num);
}

sub count_it {
	$outcounter->count_it();
}

sub update_all {
	my ($last_date_counted, $last_article_counted) = get_last_saved();

	
	(new Zpravostroj::AllDates())->traverse(sub{
		
		my $d = shift;
		
		if (! $d->date->is_older_than($last_date_counted)) {
			say "je novejsi, jdu pocitat counts";
			my $day_count = ($last_date_counted->is_the_same_as($d->date)) 
							? (
								{$d->get_idf_before_article($last_article_counted+1)}
							) : (
								{$d->get_idf_before_article(0)}
							);
			#nemusim lockovat!
			Zpravostroj::InverseDocumentFrequencies::add_words($day_count);
		}
		
		say "done";
		
		return ();
		
	},$FORKER_SIZES{IDF_UPDATE_DAYS});
	count_it;
}



1;