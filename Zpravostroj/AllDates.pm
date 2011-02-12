package Zpravostroj::AllDates;

use Zpravostroj::Globals;
use Moose;
use Zpravostroj::Date;
use Zpravostroj::AllWordCounts;

use Zpravostroj::ThemeFiles;

with 'Zpravostroj::Traversable';

use forks;
use forks::shared;

sub _get_traversed_array {
	shift;
	
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
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
	shift;
	return new Zpravostroj::DateArticles(date=>Zpravostroj::Date::get_from_string(shift));
}

sub _after_traverse{
}

sub cleanup_all {
	my $s = shift;
	
	my %counts : shared;
	$s->traverse(sub{
		
		my $d = shift;
		my $c = $d->cleanup_all_and_count_words;
		
		for (keys %$c) {
			no warnings 'uninitialized';
			lock(%counts);
			$counts{$_}+=  $c->{$_};
		}
		
		return();
	}, $FORKER_SIZES{CLEANUP_DAYS});

	$s->_set_allwordcounts_from_last_accessed(\%counts);

}

sub set_latest_wordcount {
	my $s=shift;
	
	my ($last_date_counted, $last_article_counted) = Zpravostroj::AllWordCounts::get_last_saved();

	my %counts = Zpravostroj::AllWordCounts::get_count();
	share(%counts); #in forks, it DOES keep its values after share, unlike in ithreads
	
	
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
			for (keys %$day_count) {
				no warnings 'uninitialized';
				lock(%counts);
				$counts{$_} += $day_count->{$_};
			}
		}
		
		say "done";
		
		return ();
		
	},$FORKER_SIZES{LATEST_WORDCOUNT_DAYS});
	
	$s->_set_allwordcounts_from_last_accessed(\%counts);
}

sub _set_allwordcounts_from_last_accessed {
	my $s = shift;
	my $c = shift;
	my $l = Zpravostroj::Date::get_from_string($s->_last_accessed);
	Zpravostroj::AllWordCounts::set_count($c);
	Zpravostroj::AllWordCounts::set_last_saved($l, (new Zpravostroj::DateArticles(date=>$l))->get_last_number);
	
}

sub get_total_article_count_before_last_wordcount {
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

sub get_all_themes {
	my $s = shift;
	
	
	my %themes : shared;
	
	$s->traverse(sub{
		my $d = shift;
		
		my @d_themes = Zpravostroj::ThemeFiles::get_top_themes($d->date, 100);
		for my $theme (@d_themes) {
			
			lock(%themes);
			if (exists $themes{$theme->lemma}) {
				$themes{$theme->lemma} = shared_clone($theme->add_another($themes{$theme->lemma}));
			} else {
				$themes{$theme->lemma} = shared_clone($theme);
			}
		}
		
		return ();
	}, $FORKER_SIZES{ALL_TOPTHEMES});
	
	return %themes;
}



__PACKAGE__->meta->make_immutable;


1;