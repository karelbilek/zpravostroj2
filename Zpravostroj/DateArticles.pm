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

with 'Zpravostroj::Traversable';

use Date;

has 'date' => (
	is=>'ro',
	required=>1,
	isa=>'Date'
);

sub article_count{
	my $s=shift;
	my $ds = $s->date->daypath;
	my @s = <$ds/*>;
	return scalar @s;

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

sub save_article {
	my $s = shift;
	my $n = shift;
	my $article = shift;
	if (defined $article) {
		dump_bz2($n, $article, "Article");
	}
}

sub remove_article {
	my $s = shift;
	my $n = shift;
	
	say "Mazu $n.";
	system ("rm $n");
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
	
	return undump_bz2($n, "Article");
}

sub _after_traverse{
	my $s = shift;
	my $art_name = shift;
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

sub _should_delete_dup_url {
	my $url = shift;
	my $urls = shift;
	lock ($urls);
	if (exists $urls->{$a->url}) {
		return 1;
	} else {
		$urls->{$a->url} = 1;
		return 0;
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
		
			if (_should_delete_dup_url($a->url, \%urls) {
				return (-1);
			}
					
			$a->count_themes($total, $count);

			my $themes = $a->themes;
			
			for (@$themes) {
				{
					lock($themhash);
					$themhash->add_theme($_, 1);
				}
			}
		
			return(1);
		} else {
			return(0);
		}
	},$FORKER_SIZES{THEMES_ARTICLES}
	);	
	return $themhash;
}


sub get_and_save_themes_themefiles {
	my $s = shift;
	
	my $count = shift;
	my $total = shift;
	
	{
		my $old_day_themes = Zpravostroj::ThemeFiles::get_day_themes($s->date);
		Zpravostroj::ThemeFiles::delete_from_theme_history($old_day_themes, $s->date);
	}
		
	my $themhash = $s->_get_and_save_articles_themes($count, $total);	

	Zpravostroj::ThemeFiles::save_day_themes($s->date, $themhash);
	
	Zpravostroj::ThemeFiles::add_to_theme_history($themhash, $s->date);
	
}

sub review_all {
	my $s = shift;
	$s->traverse(sub{
		my $a = shift;
		my $has = $a->has_counts;
		if (!$has) {
			say "Nema counts! pocitam";
			$a->counts();
			return (1);
		} else {
			return (0);
		}
	},$FORKER_SIZES{REVIEW_ARTICLES});
}


sub get_wordcount_before_article {
	my $s = shift;
	my $num = shift;
	my %counts:shared;
	
	my %urls:shared;
	
	$s->traverse(sub{
		
		my $a = shift;
		my $artname = shift;
		$artname =~ /\/([0-9]*)\.bz2/;
		if ($1 < $num) {
			return (0);
		}
		
		if (_should_delete_dup_url($a->url, \%urls) {
			return (-1);
		}
		
		my $had = $a->has_counts;
		
		#tohle vrací počty slov ve článku
		my $wcount = $a->counts;
		for (keys %$wcount) {
			#pro každé slovo se přičte pouze JEDNOU ZA ČLÁNEK
			#tj. je tam POČET ČLÁNKŮ
			lock(%counts);
			$counts{$_}++;
		}
		
		if ($had) {
			return (0);
		} else {
			return (1);
		}
	}, $FORKER_SIZES{LATEST_WORDCOUNT_ARTICLES});
	
	for (keys %counts) {
		if ($counts{$_}<$MIN_ARTICLES_PER_DAY_FOR_ALLWORDCOUNTS_INCLUSION) {
			delete $counts{$_};
		}
	}
	#tady vyjde slovo->inverzní počet článků
	return %counts;
}


sub delete_all_unusable {
	my $s = shift;
	my $ada = new DateArticles(date=>$s);
	my $subr = shift;
		

	my $ps = $ada->pathname;
			
	for my $fname (<$ps/*>) {
		my $delete = 0;
		if ($fname !~ /\.bz2$/) {
			$delete = 1;
		} else {
			my $s = -s $fname;
			$delete = ($s < $MINIMAL_USABLE_BZ2_SIZE);
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