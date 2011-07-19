package Zpravostroj::AllDates;
#Modul, který umožňuje iterovat přes všechny datumy

#Spolu s tím dělá všechny úlohy, co mají co dělat se statistikou všech článků
#(tj. v podstatě všechny úlohy kromě těch, co hodnotí kvalitu zatřiďování)

#Aby to mohlo mít moose role, musí to být Moose objekt - tj. je to Moose objekt, ale nemá žádné datové položky


use warnings;
use strict;

use Zpravostroj::Globals;
use Moose;
use Zpravostroj::Date;
use Zpravostroj::InverseDocumentFrequencies;

use Zpravostroj::DateArticles;

with 'Zpravostroj::Traversable';

use forks;
use forks::shared;


use utf8;

binmode STDOUT, ":utf8"; 

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


#Načítání DateArticles ze stringu
sub _get_object_from_string {
	shift; #odkaz na self
	return new Zpravostroj::DateArticles(date=>Zpravostroj::Date::get_from_string(shift));
}

#Nic nedělám
sub _after_subroutine{
}

#Obecná funkce na získávání různých statistických dat
#Vezme data z každého dne, které jsou sesbírané pomocí jeho get_statistics
#ty dá do OutCounteru, co se jmenuje předvídatelně, a pak ho seřadí
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



#Spočítá nejčastější lemmata
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



#Statistika f-témat
sub get_statistics_f_themes {
	
	
	get_statistics("f_themes", sub{map {$_->lemma()} $_[0]->frequency_themes}, $FORKER_SIZES{F_THEMES_DAYS}, $FORKER_SIZES{F_THEMES_ARTICLES});
	
}


#Statistika zpravodajských zdrojů
sub get_statistics_news_source {
	
	get_statistics("news_source", sub{$_[0]->news_source}, $FORKER_SIZES{NEWS_SOURCE_DAYS}, $FORKER_SIZES{NEWS_SOURCE_ARTICLES});
	
}


#Statistika tfidf-témat
#(vypočítává je)
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

#statistika stop-témat
sub get_statistics_stop_themes {

	get_statistics("stop", sub{map {$_->lemma()} $_[0]->stop_themes}, $FORKER_SIZES{STOP_THEMES_DAYS}, $FORKER_SIZES{STOP_THEMES_ARTICLES});


}


#Kromě toho si pamatuji seznam všech článků (hodí se to např. na zjišťování celkového počtu nebo pro náhodné články)

#Tady ho updatnu
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

#Tady ho zjistím
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

#Tady si ho přečtu
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

#Vrátí počet všech článků
sub get_saved_article_count {
	if (!-e "data/all_article_names/names") {
		update_saved_article_names;
	}
	
	return `cat data/all_article_names/names | wc -l`;
}

#Vrátí náhodný článek
sub get_random_article {
	#$s potrebuju kvuli get_saved_article_names, ktery muze vyvolat traverse
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

#Vrátí článek na základě jeho ID
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




__PACKAGE__->meta->make_immutable;


1;
