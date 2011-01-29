package Zpravostroj::AllWordCounts;

use 5.008;
use strict;
use warnings;


use forks;
use forks::shared;

use All;
use Zpravostroj::Globals;
use Date;
use File::Slurp;

use Scalar::Util qw(reftype);


mkdir "data";
mkdir "data/all";

sub get_count {
	
	
	my $c = undump_bz2("data/all/counts.bz2");
	
	if (!$c or reftype($c) ne "HASH") {
		return ();
	} else {
		return %$c;
	}
}

sub get_last_saved {
	if (!-e "data/all/date_last_counted") {
		return (new Date(day=>0, month=>0, year=>0), 0);
	}
	return (Date::get_from_file("data/all/date_last_counted"), read_file("data/all/article_last_counted"));
}

sub set_last_saved {
	my ($date, $num) = @_;
	$date->get_to_file("data/all/date_last_counted");
	write_file("data/all/article_last_counted", $num);
}

sub set_latest_count {
	
	
	my ($last_date_counted, $last_article_counted) = get_last_saved();

	my %counts = get_count();
	share(%counts); #in forks, it DOES keep its values after share, unlike in ithreads
	
	my $last_date_now = shared_clone(new Date());
	
	All::do_for_all(sub{
		
		my $d = shift;
		
		#!!!!!!!!!!!!!!!!!!SPATNE SPATNE SPATNE!!!!! MUSIM ZMENIT NA NECO, CO VRACI TRAVERSABLE, JE TO MIMO PORADI
		$last_date_now = shared_clone($d);
		
		say "d je ".$d->get_to_string();
		
		
		if (! $d->is_older_than($last_date_counted)) {
			my $day_count = ($last_date_counted->is_the_same_as($d)) 
							? (
								{$d->get_count($last_article_counted+1)}
							) : (
								{$d->get_count(0)}
							);
			for (keys %$day_count) {
				if ($day_count->{$_}>=$MIN_ARTICLES_PER_DAY_FOR_ALLWORDCOUNTS_INCLUSION) {
					lock(%counts);
					$counts{$_}=if_undef($counts{$_},0) + $day_count->{$_};
				}
			}
		}
		
		say "done";
		
		return ();
		
	},1);
	dump_bz2("data/all/counts.bz2", \%counts);
	set_last_saved($last_date_now, $last_date_now->article_count-1);
}

1;