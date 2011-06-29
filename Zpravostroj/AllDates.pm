package Zpravostroj::AllDates;
#Modul, který umožňuje iterovat přes všechny datumy

#Spolu s tím dělá všechny úlohy, co mají co dělat se statistikou všech článků
#(tj. v podstatě všechny úlohy kromě těch, co hodnotí kvalitu zatřiďování)

#Aby to mohlo mít moose role, musí to být Moose objekt - tj. je to Moose objekt, ale nemá žádné datové položky


use Zpravostroj::Globals;
use Moose;
use Zpravostroj::Date;
use Zpravostroj::AllWordCounts;

use Zpravostroj::DateArticles;

with 'Zpravostroj::Traversable';

use forks;
use forks::shared;


use utf8;

#Vrací pole všech dní - podle data/articles
sub _get_traversed_array {
	shift;	#shiftuji "zbytečný" odkaz na sebe sama
	
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
		#get_last_folder je ve Zpravostroj::Globals
		#je to kvůli řazení
		
		for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/*>) {
			my $year = get_last_folder($_);
			
			for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/$year/*>) {
				my $month = get_last_folder($_);
				for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/$year/$month/*>) {
					my $day = get_last_folder($_);
					push(@res, $year."-".$month."-".$day);
				}
			}
		}
		return @res;
	}
}



sub _get_object_from_string {
	shift; #odkaz na self
	return new Zpravostroj::DateArticles(date=>Zpravostroj::Date::get_from_string(shift));
}

#Nic nedělám
sub _after_subroutine{
}



#========================================

#Ukol (1) - spocitat nejpouzivanejsi lemmata
sub get_most_frequent_lemmas {
	my $s=new Zpravostroj::AllDates();
	
	my $allcounter = new Zpravostroj::OutCounter(name=>"data/allresults/lemmas");
	
	$s->traverse(sub{
		my $d = shift;
		
		my %hash = $d->get_most_frequent_lemmas();
		
		say "Ctu veci z hashe, chci je pridat do allcounteru";
		
		$allcounter->add_hash(\%hash);
		
		say "na konci traverse";
		
	},$FORKER_SIZES{LEMMAS_DAYS});
	
	
	$allcounter->count_and_sort_it();
}


#=========================================

#Ukol (2) - statistiky trivialnich f_temat

sub get_statistics_f_themes {
	my $s=new Zpravostroj::AllDates();
	
	my $allcounter = new Zpravostroj::OutCounter(name=>"data/allresults/f_themes");
	
	$s->traverse(sub{
		my $d = shift;
		
		my $hash = $d->get_statistics_f_themes();
		
		$allcounter->add_hash($hash);
		
		return ();
	},$FORKER_SIZES{F_THEMES_DAYS});
	
	$allcounter->count_and_sort_it();
}


#=========================================

#Ukol (3) - statistiky zpravodajskych zdroju

sub get_statistics_news_source {
	my $s=new Zpravostroj::AllDates();
	
	my $allcounter = new Zpravostroj::OutCounter(name=>"data/allresults/news_source");
	
	$s->traverse(sub{
		my $d = shift;
		
		
		my $hash = $d->get_statistics_news_source();
		
		
		$allcounter->add_hash($hash);
			
		
		return ();
	},$FORKER_SIZES{NEWS_SOURCE_DAYS});
	
	$allcounter->count_it();
}


sub review_all {
	my $s=shift;
	my $count = shift;
	my $total = shift;
	
	
	$s->traverse(sub{
		my $d = shift;
		say "POCITAM - ".$d->date->get_to_string();
		
		$d->review_all($count, $total);
		return ();
	},$FORKER_SIZES{REVIEW_DAYS});
}


sub count_and_get_top_tfidf {
	my $s=shift;
	my $count = shift;
	my $total = shift;
	
	my $last_date_counted = new Zpravostroj::Date(year=>2010, month=>2, day=>24);
	my $allcounter = new Zpravostroj::OutCounter(name=>"data/allresults/total_tfidf", delete_on_start=>0);
	
	$s->traverse(sub{
		my $d = shift;
		if (!$d->date->is_older_than($last_date_counted)) {
			say "POCITAM - ".$d->date->get_to_string();
		
		
			my $hash = $d->count_and_get_top_tfidf($count, $total);
			
			say "Pridavam ".$d->date->get_to_string()." do totalu";
		
			$allcounter->add_hash($hash);
			
			say "Dopridavano.";
		}
		
		return ();
	},$FORKER_SIZES{THEMES_DAYS});
	
	$allcounter->count_it();
}


sub get_top_ten_lemmas_stop {
	my $s=shift;
	
	my $allcounter = new Zpravostroj::OutCounter(name=>"data/total_top10_lemmas_stop", delete_on_start=>0);
	my $last_date_counted = new Zpravostroj::Date(year=>2010, month=>9, day=>20);
	
	$s->traverse(sub{
		my $d = shift;
		if (!$d->date->is_older_than($last_date_counted)) {
			say "POCITAM - ".$d->date->get_to_string();
		
			
			my $hash = $d->get_top_ten_lemmas_stop();
			
 
			$allcounter->add_hash($hash);
		}
		
		return ();
	},$FORKER_SIZES{STOP_TOPTHEMES_DAYS});
	
	$allcounter->count_it();
}


sub total_wordcount_dump {
	my $s=shift;
	$s->traverse(sub{
		my $d = shift;
		
		my %count = $d->get_wordcount_before_article(0,1);
		
		
		say "DOPOCITANO, jdu tvorit adresar...";
		while (!mkdir "data/muj") {sleep(10); say "Nepovedlo, cekam.."; }
		
		say "povedlo, jdu strkat. Velikost count je ", scalar keys %count;
		
		open my $of, ">>:utf8", "data/total_data_dump";
		for (keys %count) {
			print $of $_."\t".$count{$_}."\n";
		}
		close $of;
		say "Zavreno.";
		say "Rm reklo :";
		system("rm -r data/muj");
		return ();
	},$FORKER_SIZES{LATEST_WORDCOUNT_DAYS});
}

sub cleanup_all {
	my $s = shift;
	
	Zpravostroj::AllWordCounts::null_all();
	
	
	$s->traverse(sub{
		
		my $d = shift;
		my $c = $d->cleanup_all_and_count_words;
		
		Zpravostroj::AllWordCounts::add_to_count($c);
		
		
		return();
	}, $FORKER_SIZES{CLEANUP_DAYS});


}

sub set_latest_wordcount {
	my $s=shift;
	
	my ($last_date_counted, $last_article_counted) = Zpravostroj::AllWordCounts::get_last_saved();

	
	#my %counts = Zpravostroj::AllWordCounts::get_count();
	#share(%counts); #in forks, it DOES keep its values after share, unlike in ithreads
	
	
	$s->traverse(sub{
		
		my $d = shift;
		
		if (! $d->date->is_older_than($last_date_counted)) {
			say "je novejsi, jdu pocitat counts";
			my $day_count = ($last_date_counted->is_the_same_as($d->date)) 
							? (
								{$d->get_wordcount_before_article($last_article_counted+1)}
							) : (
								{$d->get_wordcount_before_article(0)}
							);
			#nemusim lockovat!
			Zpravostroj::AllWordCounts::add_to_count($day_count);
		}
		
		say "done";
		
		return ();
		
	},$FORKER_SIZES{LATEST_WORDCOUNT_DAYS});
	
	
}

sub get_all_date_addresses {
	my $s = shift;
	my @all : shared;
	
	$s->traverse(sub {
		my $d = shift;
		my @a = $d->_get_traversed_array;
		lock(@all);
		push @all, @a;
	}, $FORKER_SIZES{GET_ALL_DATE_ADDRESSES}, 1);
	
	
	return @all;
}


sub get_article_names {
	my $s = shift;
	if (-e "data/all_article_names/names") {
		open my $anames, "<", "data/all_article_names/names";
		my @all = <$anames>;
		close $anames;
		chomp(@all);
		return @all;
	} else {
		$s->freeze_article_names;
		return $s->get_article_names;
	}
}

sub freeze_article_names {
	my $s = shift;
	my @all = $s->get_all_date_addresses;
	mkdir "data/";
	mkdir "data/all_article_names/";
	open my $anames, ">", "data/all_article_names/names";
	for (@all) {
		print $anames $_."\n";
	}
	close $anames;
}


sub get_random_article {
	#$s potrebuju kvuli traverse nekde dal
	my $s = shift;
	
	
	my @names = $s->get_article_names;
	my $size = scalar @names;
	say "Size je $size.";
	
	
	my $rand_name;
	
	my $r = rand $size;
	$rand_name = $names[$r];
	
	$rand_name =~ s/\//-/g;
	$rand_name =~ s/data-articles-//g;
	$rand_name =~ s/\.bz2//g;
	
	return $s->get_from_article_id($rand_name);
}


sub get_from_article_id {
	
	my $s = shift;
	
	my $id = shift;
	if ($id =~ /^(\d\d\d\d)-(\d+)-(\d+)-(\d+)$/){
		my $date = new Zpravostroj::Date(year=>$1, month=>$2, day=>$3);
		my $article = (new Zpravostroj::DateArticles(date=>$date))->get_article_from_number($4);
		
		return $article;
	} else {
		
		return undef;
	}
}

sub get_total_article_count_before_last_wordcount {
	say "Bacha, cheatuju v AllDates::get_total_article_count_before_last_wordcount !!!";
	
	return 63733;
	
	my $s = shift;
	
	my ($last_date, $last_article) = Zpravostroj::AllWordCounts::get_last_saved();
	if (!$last_date) {
		$last_date = new Zpravostroj::Date(day=>0, month=>0, year=>0);
	}
	say "Last day je ".$last_date->get_to_string();
	
	my $total:shared;
	$total=0;
	$s->traverse(sub{
		
		my $d = shift;
		
		my $add=0;;
		
		if ($last_date->is_the_same_as($d->date)) {
			$add = $last_article+1;
		}
		if ($d->date->is_older_than($last_date)) {
			$add = $d->article_count;
		}
		
		lock($total);
		$total += $add;
		return();		
	},$FORKER_SIZES{ARTICLECOUNT});
	
	say "total je $total";
	return $total;
	
}

sub delete_all_unusable {
	$|=1;
	my $s = shift;
	my $count:shared;
	$count=0;
	say "wtf";
	$s->traverse(sub{
		(shift)->delete_all_unusable;		
	}, $FORKER_SIZES{UNUSABLE});
	say "Count je $count.";
}

sub get_top_themes {

	my $s = shift;
	
	my $c = shift;
	
	my %themes = $s->get_all_themes();
	
	my @r_themes = values %themes;
	
	@r_themes = sort {$b->importance <=> $a->importance} @r_themes;
	
	if (!defined $c) {
		return @r_themes;
	} else {
		return @r_themes[0..$c];
	}
}


sub print_dny {
	my $s = shift;
	
	open my $dny, ">:utf8","data/allresults/R_dny_less_tfidf";
	

	
	$s->traverse(sub{
		my $d = shift;
		
		my $da = $d->date;
		
		


			my $count_articles = scalar($d->_get_traversed_array);
			if ($count_articles > 0) {
				
				print $dny $da->day.".".$da->month;
				print $dny "\n";
				
				
			}		
		#}
		
	}, 0);
	
	close $dny;
}

sub print_podils {
	my $s = shift;
	
	open my $dny, ">:utf8","data/allresults/R_dnywhere_tfidf";
	open my $mesice, ">:utf8","data/allresults/R_mesice_tfidf";
	
	open my $podily, ">:utf8","data/allresults/R_podily_tfidf";

	my $i=0;
	my $predchmesic=0;
	my $predchrok=0;
	
	$s->traverse(sub{
		my $d = shift;
		
		my $da = $d->date;
		
		#if ($da->year==2010 and ($da->month==3 or $da->month==4)) {
		
			my $filename = "data/daycounters/tfidf_".$d->date->get_to_string();

			my $count_themes;

			{
				no warnings 'numeric';
				$count_themes = int(`wc -l $filename`);
			}

			my $count_articles = scalar($d->_get_traversed_array);
			if ($count_articles > 0) {
				my $podil = $count_themes/$count_articles;

				print $podily $podil."\n";
				
				$i++;
				if ($da->month!=$predchmesic) {
					print $dny $i."\n";
				
					my $ye = $da->year;
					$ye=~/..(..)/;
					if ($ye != $predchrok) {
						print $mesice '"'.$da->month.'/'.$1."\"\n";
					} else {
						print $mesice '"'.$da->month."\"\n";
					}
					$predchmesic=$da->month;
					$predchrok=$da->year;
				} 
				
				
			}		
		#}
		
	}, 0);
	
	close $dny;
	close $podily;
}

sub print_pocty_cochci_puvodni {
	my $s = shift;
	
	#my %words = map {($_=>undef)} qw(ods čssd volební blesk premiér paroubek klaus zemřít zápas demokrat 09 auto nehoda modelka fischer);
	my %words = map {($_=>undef)} qw(nečas);
	
	use Text::Unaccent;
	
	my %files;
	for (keys %words) { 
		
		my $name = unac_string("utf8", $_);
		
		open my $of, ">:utf8","data/allresults/R_tfidf_special_".$name;
		$files{$_}=$of;
	}
	
	$s->traverse(sub{
		my $d = shift;
		
		my $da = $d->date;

		my %tytopocty;
		my $filename = "data/daycounters/tfidf_".$d->date->get_to_string();

		open my $f, "<:utf8", $filename;

		while (<$f>) {

			chomp;
			/^(.*)\t(.*)$/;
			if (exists $words{$1}) {
				$tytopocty{$1}=$2;
			}
		}
		
		my $count_articles = scalar($d->_get_traversed_array);
		if ($count_articles > 0) {
			for (keys %words) {
				my $handle = $files{$_};
				my $toto = $tytopocty{$_};
				if ($toto) {
					print $handle $toto
				} else {
					print $handle 0
				}
				print $handle "\n";
			}
		}
	}, 0);
	
	for (keys %words) { 
		my $handle = $files{$_};
		close $handle;
	}
}	

sub print_pocty_noviny {
		my $s = shift;

		my %words = map {($_=>undef)} qw(aktualne
		blesk
		bleskove
		ceskenoviny
		financninoviny
		idnes
		ihned
		lidovky
		);
		

		my %files;
		for (keys %words) { 

			my $name =  $_;

			open my $of, ">:utf8","data/allresults/R_news_source_".$name;
			$files{$_}=$of;
		}

		$s->traverse(sub{
			my $d = shift;

			my $da = $d->date;

			my %tytopocty;
			my $filename = "data/daycounters/news_source_".$d->date->get_to_string();

			open my $f, "<:utf8", $filename;

			while (<$f>) {

				chomp;
				/^(.*)\t(.*)$/;
				if (exists $words{$1}) {
					$tytopocty{$1}=$2;
				} else {
					if ($1 eq "reflex") {
						$tytopocty{reflex}+=$2;
					} else {
						$tytopocty{aktualne}+=$2;
					}
				}
			}

			my $count_articles = scalar($d->_get_traversed_array);
			if ($count_articles > 0) {
				for (keys %words) {
					my $handle = $files{$_};
					my $toto = $tytopocty{$_};
					if ($toto) {
						print $handle $toto
					} else {
						print $handle 0
					}
					print $handle "\n";
				}
			}
		}, 0);

		for (keys %words) { 
			my $handle = $files{$_};
			close $handle;
		}
	}


sub print_pocty_cochci {
	print_pocty_cochci_soucet(@_);
}

sub print_pocty_cochci_soucet {
	my $s = shift;
	
	my %words = map {($_=>undef)} qw(ods čssd premiér demokrat);
	
	use Text::Unaccent;
	
	
	open my $of, ">:utf8","data/allresults/R_tfidf_sums_politika";
	
	
	$s->traverse(sub{
		my $d = shift;
		
		my $da = $d->date;

		my %tytopocty;
		my $filename = "data/daycounters/tfidf_".$d->date->get_to_string();

		open my $f, "<:utf8", $filename;

		while (<$f>) {

			chomp;
			/^(.*)\t(.*)$/;
			if (exists $words{$1}) {
				$tytopocty{$1}=$2;
			}
		}
		
		my $count_articles = scalar($d->_get_traversed_array);
		if ($count_articles > 0) {
			my $celkem = 0;
			for (keys %words) {
				$celkem += $tytopocty{$_}||0;
			}
			print $of $celkem."\n";
		}
	}, 0);
	close $of;
}

sub mnozina {
	my $s = shift;
	
	my %mnozina;
	
	
	
	$s->traverse(sub{
		my $d = shift;
		
		
		my $filename = "data/daycounters/stop_".$d->date->get_to_string();
		
		
		open my $f, "<:utf8", $filename;
		
		while (<$f>) {
			
			chomp;
			/^(.*)\t(.*)$/;
			$mnozina{$1}++;
		}
		
	},0);
	
	
	open my $of, ">:utf8", "data/allresults/stop_dayinfos";
	
	for (sort {$mnozina{$b}<=>$mnozina{$a}} keys %mnozina) {
		print $of $_."\t".$mnozina{$_}."\n";
	}
	
	close $of;
}



__PACKAGE__->meta->make_immutable;


1;
