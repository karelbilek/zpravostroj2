package Zpravostroj::DateArticles;
#Modul, který představuje všechny články pro dané datum
#a umožňuje nad nimi iterovat

use Zpravostroj::Globals;
use strict;
use warnings;

use forks;
use forks::shared;

use Zpravostroj::Forker;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Zpravostroj::OutCounter;

with 'Zpravostroj::Traversable';

use Zpravostroj::Date;


#Date, co mu přísluší
#(1 Date má přesně 1 DateArticles, resp. jsou všichni stejní, a jeden DateArticles má jeden Date.)
has 'date' => (
	is=>'ro',
	required=>1,
	isa=>'Zpravostroj::Date'
);


#Pro dané číslo článku "složí" název souboru
sub filename {
	my $s = shift;
	my $number = shift;
	return $s->pathname."/".$number.".bz2";
}

#Vrátí adresář, určený danému dni
sub pathname {
	my $s = shift;
	mkdir "data";
	mkdir "data/articles";
	my $year = int($s->date->year);
	my $month = int($s->date->month);
	my $day = int($s->date->day);
	mkdir "data/articles/".$year;
	mkdir "data/articles/".$year."/".$month;	
	mkdir "data/articles/".$year."/".$month."/".$day;
	return "data/articles/".$year."/".$month."/".$day;
}

#Vrátí článek na daném čísle
sub get_article_from_number {
	my $s = shift;
	my $number = shift;
	return $s->_get_object_from_string($s->pathname."/".$number.".bz2");
}


#Uloží článek na zadanou POZICI
sub save_article {
	my $s = shift;
	my $name = shift;
	my $article = shift;
	if (defined $article) {
		
		#Mažu article_number a date proto, že čísla článků a dny nechci ukládat přímo do .yaml.bz2 těch článků,
		#ale chci je přiřazovat znovu na základě toho, který den a ze kterého souboru je načítám
		
		$article->clear_article_number();
		$article->clear_date();
		
		say "Jdu dumpovat do $n.";
		dump_bz2($name, $article, "Article");
	}
}


sub load_article {
	my $s = shift;
	my $name = shift;
	
	$name=~/\/([0-9]*)\.bz2$/;
	my $num = $1;
	my $article = undump_bz2($n);
	if (defined $article) {
		
		#Tady article_number a date do článku naopak přidám (do souborů je neukládám)
		
		$article->date($s->date);
		$article->article_number($num);
	}
	return $article;
}

#Smaže článek ze zadané pozice
#(skutečně to, mám pocit, nikdy nedělám, ale možné to je)
sub remove_article {
	my $s = shift;
	my $n = shift;
	
	say "Mazu $n.";
	system ("rm $n");
}

#Vrátí poslední číslo článku
#(pokud není ani jeden článek, vrátí -1)
sub get_last_number {
	my $s = shift;
	my @a = sort {$a<=>$b} map {/\/([0-9]*)\.bz2/; $1} $s->_get_traversed_array();
	if (@a) {
		return $a[-1];
	} else {
		return -1;
	}
}

#Vezme počet všech článků
sub article_count {
	my $s = shift;
	return scalar ($s->_get_traversed_array());
}

#Řekne seznam všech článků (resp souborů, ze kterých lze udělat články)
sub _get_traversed_array {
	my $s = shift;
	my $path = $s->pathname;
	my @articles = <$path/*>;
	@articles = grep {/\/[0-9]*\.bz2$/} @articles;
	return (@articles);
}

#jenom zavolá load_article
sub _get_object_from_string {
	my $s = shift;
	my $n = shift;
	
	return load_article($s, $n);
}

#Podle výsledků subroutiny buď článek nechá být, uloží nebo smaže

#subroutina (tj. to, co se spouští na každém článku) může vrátit tři možné stavy:
#0 - nic se nemění
#1 - článek se změnil a chci, aby byl uložen, ale samotný objekt je stejný
#2 - článek se změnil a z nějakého důvodu je to úplně jiný objekt, ten je jako druhý výsledek
#-1 - článek smaž
sub _after_subroutine{
	say "Jsem v after traverse.";
	my $s = shift;
	my $art_name = shift;
	my $article = shift;
	my ($art_changed, $res_a) = @_;
					
	if ($art_changed>=1) {
		if ($art_changed==2) {
			$article = $res_a;
		}
		
		$s->save_article($art_name, $article);
	} elsif ($art_changed==-1) {
		
		$s->remove_article($art_name);
	}
}


#Dostane hash s nějakou statistikou, důležitou část názvu souboru
# a statistiku vypíše do něj
sub print_sorted_hash_to_file {
	my $s = shift;
	my $hash = shift;
	my $name = shift;
	
	open my $of, ">:utf8", "data/daycounters/".$name."_".$s->date->get_to_string;
	for (sort {$hash->{$b}<=>$hash->{$a}} keys %$hash) {
		print $of $_."\t".$hash->{$_}."\n";
	}
	
	close $of;
	
}

#Obecná funkce na počítání statistiky čehokoliv.
#Dostane subroutinu, která vrací pole stringů. (např. tf-idf témata)
#Pro všechny články si to počítá do jednoho sdíleného hashe, který zamyká,
#a pak ten celý hash vytiskne
sub get_statistics {
	my $s = shift;
	my $size = shift;
	my $subref = shift;

	my $filename = shift;
	
	my %count:shared;
		
	$s->traverse(sub {
		my $a = shift;
		if (defined $a) {
	
			my @res = $subref->($a);
			lock(%count);
			for (@res) {
				$count{$_}++;
			}
		} 
		return(0);
	},$size
	);
	
	$s->print_sorted_hash_to_file(\%count, $filename);
	
	return \%count;
}


#Spočítá nejčastější lemmata
sub get_most_frequent_lemmas {
	my $s = shift;
	
	my %count:shared;
	
	$s->traverse(sub{
		my $ar = shift;
		
		#Přiznaný bug, který už nestíhám opravovat - tady beru ->counts,
		#ale ty už jsou s přírůstky podle toho, jestli jsou nebo nejsou pojmenované entity.
		#To by asi nemělo být.
		
		my $wcount = $ar->counts;
		
		while (my($f, $s)=each %$wcount) {
			if (exists $count{$f}) {
				$count{$f}+=$s->score;
			} else {
				$count{$f}=$s->score;
			}
		}
		
		return (0);
	}, $FORKER_SIZES{LEMMAS_ARTICLES});
	
	say "jsem na konci DateArticles::get_most_frequent_lemmas , vracim count";
	return %count;
}


#Pro počítání IDF

#Spočítá všechna slova ve článcích PO daném článku (kvůli updatu IDF, která se tak nemusí přepočítávat celá)
sub get_idf_after_article {
	my $s = shift;
	my $start = shift;
	
	my %idf: shared;
	
	
	$s->traverse(sub{
		
		my $a = shift;
		my $artname = shift;
		$artname =~ /\/([0-9]*)\.bz2/;
		
		if ($1 < $start) {
			return (0);
		}
		
		#Abych věděl, jestli ho nemám nakonec uložit 
		#(nejsem si teď jist, jestli se může stát, že ve článku nebudou spočítány počty.)
		#(každopádně, pokud by se to stalo, tak se to po spočítání uloží, aby tam byly)
		
		my $had_counts = $a->has_counts;
		
		
		#tohle vrací počty slov ve článku
		
		my $wcount = $a->counts;
		for (keys %$wcount) {
			#pro každé slovo se přičte pouze JEDNOU ZA ČLÁNEK
			#tj. je tam POČET ČLÁNKŮ
			lock(%idf);
			$idf{$_}++;
		}
		
		
		if ($had_counts) {
			return (0);
		} else {
			return (1);
		}
	}, $FORKER_SIZES{IDF_UPDATE_ARTICLES});
	
	return %idf;
}

#Smaže všechny soubory, které jsou moc malé na to, aby byly doopravdy soubory článků
#nebo které se nejmenují správně
#(ve skutečnosti je to nesmaže, pouze - radši - přesune do složky "delete")
sub delete_all_unusable {
	my $s = shift;
	my $ada = new Zpravostroj::DateArticles(date=>$s);
	my $subr = shift;
		

	my $ps = $ada->pathname;
			
	for my $fname (<$ps/*>) {
		my $delete = 0;
		if ($fname !~ /\.bz2$/) {
			$delete = 1;
		} else {
			my $sze = -s $fname;
			$delete = ($sze < $MINIMAL_USABLE_BZ2_SIZE);
		}
		if ($delete) {
			$fname =~ /^(.*)\/[^\/]*$/;
			system "mkdir -p delete/$1";
			system "mv $fname delete/$1";
		}
		
	}
}



__PACKAGE__->meta->make_immutable;


1;
