package Zpravostroj::AllDates;

use Zpravostroj::Globals;
use Moose;
use Date;
use Zpravostroj::AllWordCounts;

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
	return new DateArticles(date=>Date::get_from_string(shift));
}

sub _after_traverse{
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
								{$d->get_count_before_article($last_article_counted+1)}
							) : (
								{$d->get_count_before_article(0)}
							);
			for (keys %$day_count) {
				lock(%counts);
				$counts{$_}=if_undef($counts{$_},0) + $day_count->{$_};
			}
		}
		
		say "done";
		
		return ();
		
	},10);
	
	my $l = Date::get_from_string($s->_last_accessed);
	say "pred set count, last accessed je ",$l->get_to_string;
	Zpravostroj::AllWordCounts::set_count(\%counts);
	say "pred set last saved";
	Zpravostroj::AllWordCounts::set_last_saved($l, $l->article_count-1);
	say "slc done";
}

sub get_total_article_count_before_last_wordcount {
	my $s = shift;
	
	my ($last_date, $last_article) = Zpravostroj::AllWordCounts::get_last_saved();
	if (!$last_date) {
		$last_date = new Date(day=>0, month=>0, year=>0);
	}
	say "Last day je ".$last_date->get_to_string();
	
	my $total:shared;
	$total=0;
	$s->traverse(sub{
				
		my $d = shift;
		
		lock($total);
		if ($last_date->is_the_same_as($d->date)) {
			$total += $last_article+1;
		}
		if ($d->date->is_older_than($last_date)) {
			$total += $d->article_count();
		}
		
		return();		
	},40);
	
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
	}, 40);
	say "Count je $count.";
}

sub get_top_themes {

	my $s = shift;
	
	my %themes : shared;
	
	$s->traverse(sub{
		my $d = shift;
		
		my @d_themes = $d->get_top_themes(100);
		for my $theme (@d_themes) {
			
			lock(%themes);
			if (exists $themes{$theme->lemma}) {
				$themes{$theme->lemma} = shared_clone($theme->add_another($themes{$theme->lemma}));
			} else {
				$themes{$theme->lemma} = shared_clone($theme);
			}
		}
		
		return ();
	}, 10);
	
	my @r_themes = values %themes;
	
	@r_themes = sort {$b->importance <=> $a->importance} @r_themes;
	
	return @r_themes[0..100];
}


__PACKAGE__->meta->make_immutable;


1;