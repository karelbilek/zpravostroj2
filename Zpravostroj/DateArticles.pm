package Zpravostroj::DateArticles;
use Zpravostroj::Globals;
use strict;
use warnings;

use forks;
use forks::shared;

use Zpravostroj::ThemeHash;
use Zpravostroj::Forker;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Zpravostroj::OutCounter;

with 'Zpravostroj::Traversable';

use Zpravostroj::Date;

has 'date' => (
	is=>'ro',
	required=>1,
	isa=>'Zpravostroj::Date'
);

has '_last_number' => (
	is => 'rw',
	isa=>'Maybe[Int]',
	default=>undef
);


sub filename {
	my $s = shift;
	my $n = shift;
	return $s->pathname."/".$n.".bz2";
}

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

sub get_article_from_number {
	my $s = shift;
	my $number = shift;
	return $s->_get_object_from_string($s->pathname."/".$number.".bz2");
}

sub save_article {
	my $s = shift;
	my $n = shift;
	my $article = shift;
	if (defined $article) {
		$article->clear_article_number();
		$article->clear_date();
		say "Jdu dumpovat do $n. TECKA.";
		dump_bz2($n, $article, "Article");
	}
}

sub remove_article {
	my $s = shift;
	my $n = shift;
	
	say "Mazu $n.";
	system ("rm $n");
}

sub get_last_number {
	my $s = shift;
	my @a = sort {$a<=>$b} map {/\/([0-9]*)\.bz2/; $1} $s->_get_traversed_array();
	if (@a) {
		return $a[-1];
	} else {
		return -1;
	}
}

sub article_count {
	my $s = shift;
	return scalar ($s->_get_traversed_array());
}


sub _get_traversed_array {
	my $s = shift;
	my $ds = $s->pathname;
	my @s = <$ds/*>;
	@s = grep {/\/[0-9]*\.bz2$/} @s;
	return (@s);
}


sub _get_object_from_string {
	my $s = shift;
	my $n = shift;
	
	$n=~/\/([0-9]*)\.bz2$/;
	my $num = $1;
	my $article = undump_bz2($n);
	if (defined $article) {
		$article->date($s->date);
		$article->article_number($num);
	}
	return $article;
}

sub _after_subroutine{
	say "Jsem v after traverse.";
	my $s = shift;
	my $art_name = shift;
	my $a = shift;
	my ($art_changed, $res_a) = @_;
					
	if ($art_changed>=1) {
		if ($art_changed==2) {
			$a = $res_a;
		}
		
		$s->save_article($art_name, $a);
	} elsif ($art_changed==-1) {
		
		$s->remove_article($art_name);
	}
}



sub _get_and_save_articles_themes {
	my $s = shift;
		
	my $count = shift;
	my $total = shift;
	
	my $themhash:shared;
	$themhash = shared_clone(new Zpravostroj::ThemeHash());
	
	my %urls:shared;
	
	$s->traverse(sub {
		my $a = shift;
		if (defined $a) {
		
			if (_should_delete_dup_url($a->url, \%urls)) {
				say "Vracim DUPLICATE";
				return (-1);
			}
			
			say "Jdu pocitat temata.";
			$a->count_themes($total, $count);

			my $themes = $a->themes;
			
			for (@$themes) {
				{
					lock($themhash);
					$themhash->add_theme($_, 1);
				}
			}
			
			$a->date($s->date);
			
			say "Vracim 1 -> UKLADEJ!";
			return(1);
		} else {
			return(0);
		}
	},$FORKER_SIZES{THEMES_ARTICLES}
	);	
	return $themhash;
}

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




sub get_statistics_tf_idf_themes {
	
	
	my $s = shift;
		
	my ($word_frequencies, $article_count)=@_;
	
	my %count:shared;
	
	$s->traverse(sub {
		my $a = shift;
		if (defined $a) {
	
			$a->count_themes($word_frequencies, $article_count);

			my $themes = $a->themes;
			
			for (@$themes) {
				my $lemma = $_->lemma;
				
				lock(%count);
				if (exists $count{$lemma}) {
					$count{$lemma}++;
				} else {
					$count{$lemma}=1;
				}
			}
			return(1);
		} else {
			return(0);
		}
	},$FORKER_SIZES{THEMES_ARTICLES}
	);	
	
	
	say "Pisu do data/daycounters/tfidf_".$s->date->get_to_string;
	open my $of, ">:utf8", "data/daycounters/tfidf_".$s->date->get_to_string;
	for (sort {$count{$b}<=>$count{$a}} keys %count) {
		print $of $_."\t".$count{$_}."\n";
	}
	
	close $of;
	
	
	return \%count;
}

sub get_and_save_themes_themefiles {
	my $s = shift;
	
	my $count = shift;
	my $total = shift;
	
	my $themhash = $s->_get_and_save_articles_themes($count, $total);

	say "jsem po _get_and_save_articles_themes";

	
	
}


sub cleanup_all_and_count_words {
	my $s = shift;
	
	my %counts:shared;
	my %urls:shared;

	$s->traverse(sub{
		my $a = shift;
		if (_should_delete_dup_url($a->url, \%urls)) {
			return (-1);
		}
		$a->cleanup();
		
		
		my $wcount = $a->counts;

		for (keys %$wcount) {
			lock(%counts);
			$counts{$_}++;
		}
		return (1);
	}, $FORKER_SIZES{CLEANUP_ARTICLES});
	
	return \%counts;
}

sub get_most_frequent_lemmas {
	my $s = shift;
	
	my %count:shared;
	
	$s->traverse(sub{
		my $ar = shift;
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



sub get_idf_before_article {
	my $s = shift;
	my $start = shift;
	
	my %idf:shared;
	
	
	$s->traverse(sub{
		
		my $a = shift;
		my $artname = shift;
		$artname =~ /\/([0-9]*)\.bz2/;
		if ($1 < $start) {
			return (0);
		}
		
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
	
	#tady vyjde slovo->inverzní počet článků
	return %idf;
}


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
