package Zpravostroj::AllDates;
#Modul, který umožňuje iterovat přes všechny datumy

#Spolu s tím dělá všechny úlohy, co mají co dělat se statistikou všech článků
#(tj. v podstatě všechny úlohy kromě těch, co hodnotí kvalitu zatřiďování)

#Aby to mohlo mít moose role, musí to být Moose objekt - tj. je to Moose objekt, ale nemá žádné datové položky


use Zpravostroj::Globals;
use Moose;
use Zpravostroj::Date;
use Zpravostroj::InverseDocumentFrequencies;

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

#Obecná
sub get_statistics {
	my $s=new Zpravostroj::AllDates();
	my $name = shift;
	my $subref = shift;
	my $size_days = shift;
	my $size_articles = shift;
	
	my $allcounter = new Zpravostroj::OutCounter(name=>"data/allresults/$name");
	
	$s->traverse(sub{
		my $d = shift;
		
		
		my $hash = $d->get_statistics($size_articles, $subref, $name);
		
		
		$allcounter->add_hash($hash);
		
		return ();
	},$size_days);
	
	$allcounter->count_and_sort_it();
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
	
	
	get_statistics("f_themes", sub{map {$_->lemma()} $_[0]->frequency_themes}, $FORKER_SIZES{F_THEMES_DAYS}, $FORKER_SIZES{F_THEMES_ARTICLES});
	
}


#=========================================

#Ukol (3) - statistiky zpravodajskych zdroju

sub get_statistics_news_source {
	
	get_statistics("news_source", sub{$_[0]->news_source}, $FORKER_SIZES{NEWS_SOURCE_DAYS}, $FORKER_SIZES{NEWS_SOURCE_ARTICLES});
	
}



sub get_statistics_tf_idf_themes {

	
	
	my $idf = Zpravostroj::InverseDocumentFrequencies::get_frequencies();
	
	my $article_count = get_saved_article_count();
	
	get_statistics("tf_idf", 
		sub{
			$_[0]->count_tf_idf_themes($idf, $article_count); 
			map {$_->lemma()} @{$_[0]->tf_idf_themes};
		}
		, $FORKER_SIZES{TF_IDF_DAYS}, $FORKER_SIZES{TF_IDF_ARTICLES});
	
}


sub get_statistics_stop_themes {

	get_statistics("stop", sub{map {$_->lemma()} $_[0]->stop_themes}, $FORKER_SIZES{STOP_THEMES_DAYS}, $FORKER_SIZES{STOP_THEMES_ARTICLES});


}

sub update_saved_article_names {
	my @all = get_real_article_names();
	mkdir "data/";
	mkdir "data/all_article_names/";
	open my $anames, ">", "data/all_article_names/names";
	for (@all) {
		print $anames $_."\n";
	}
	close $anames;
}


sub get_real_article_names {
	my $s=new Zpravostroj::AllDates();
	my @all : shared;
	
	$s->traverse(sub {
		my $d = shift;
		my @a = $d->_get_traversed_array;
		lock(@all);
		push @all, @a;
	}, $FORKER_SIZES{REAL_ARTICLE_NAMES});
	
	
	return @all;
}


sub get_saved_article_names {
	if (!-e "data/all_article_names/names") {
		update_saved_article_names;
	}
	
	open my $anames, "<", "data/all_article_names/names";
	my @all = <$anames>;
	close $anames;
	chomp(@all);
	return @all;
	
}


sub get_saved_article_count {
	if (!-e "data/all_article_names/names") {
		update_saved_article_names;
	}
	
	return `cat data/all_article_names/names | wc -l`;
}


sub get_random_article {
	#$s potrebuju kvuli traverse nekde dal
	my $s = new Zpravostroj::AllDates();;
	
	
	my @names = $s->get_saved_article_names;
	my $size = scalar @names;
	say "Size je $size.";
	
	
	my $rand_name;
	
	my $r = rand $size;
	$rand_name = $names[$r];
	
	$rand_name =~ s/\//-/g;
	$rand_name =~ s/data-articles-//g;
	$rand_name =~ s/\.bz2//g;
	
	return get_from_article_id($rand_name);
}


sub get_from_article_id {
	
	
	my $id = shift;
	if ($id =~ /^(\d\d\d\d)-(\d+)-(\d+)-(\d+)$/){
		my $date = new Zpravostroj::Date(year=>$1, month=>$2, day=>$3);
		my $article = (new Zpravostroj::DateArticles(date=>$date))->get_article_from_number($4);
		
		return $article;
	} else {
		
		return undef;
	}
}


sub PAPER__dates {
	
	mkdir "data/R_data";
	
	open my $dny, ">:utf8","data/R_data/all_dates";
	
	my @a = _get_traversed_array();
	for (@a) {
		/^(....)-(.*)-(.*)/;
		print $dny $3.".".$2;
		print $dny "\n";
	}
	
	close $dny;
	
	open my $days_filter, ">:utf8","data/R_data/filtered_dates__places";
	open my $marks, ">:utf8","data/R_data/filtered_dates__marks";
	
	my $previous_year=0;
	my $previous_month=0;

	for my $i (0..$#a) {
		my $d = $a[$i];
		
		$d=~/^(....)-(.*)-(.*)/;
		my $year = $1;
		my $month = $2;
		
		if ($month != $previous_month) {
			print $days_filter $i."\n";
			
			
			if ($year != $previous_year) {
				$year=~/..(..)/;
				print $marks '"'.$month.'/'.$1."\"\n";
			} else {
				print $marks '"'.$month."\"\n";
			}
			
		} 
		
		$previous_year = $year;
		$previous_month = $month;
	} 
	close $days_filter;
	close $marks;
}


sub PAPER__average_tf_idf_themes_on_article {
	_PAPER__average_themes_on_article("tf_idf");
}

sub _PAPER__average_themes_on_article {
	my $s = new Zpravostroj::AllDates();
	my $type=shift;
	
	mkdir "data/R_data";

	
	open my $podily, ">:utf8", "data/R_data/average_".$type;

	
	$s->traverse(sub{
		my $d = shift;
				
		my $filename = "data/daycounters/".$type."_".$d->date->get_to_string();

		my $count_themes;

		{
			no warnings 'numeric';
			$count_themes = int(`wc -l $filename`);
		}

		my $count_articles = scalar($d->_get_traversed_array);
		my $podil = ($count_articles > 0) ? ($count_themes/$count_articles) : 0;
		print $podily $podil."\n";
	}, 0);
	
	close $podily
	
}

sub _PAPER__selected_words {
	my $s = shift;
	
	my $type = shift;
	my @words_array = shift;
	#my %words = map {($_=>undef)} qw(ods čssd volební blesk premiér paroubek klaus zemřít zápas demokrat 09 auto nehoda modelka fischer);
	#my %words = map {($_=>undef)} qw(nečas);
	
	my %words = map {($_=>undef)}  @words_array;
	
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
