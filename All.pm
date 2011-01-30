package All;

use 5.008;
use forks;
use forks::shared;

use strict;
use warnings;
use Date;
use Zpravostroj::Globals;
use Zpravostroj::TectoServer;
use Zpravostroj::RSS;

use Zpravostroj::Forker;

use File::Slurp;
use Data::Dumper;
use Scalar::Util qw(blessed);

use Zpravostroj::Theme;





sub get_all_dates {
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
		for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/*>) {
			my $year = get_last_folder($_);;
			for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/$year/*>) {
				my $month = get_last_folder($_);
				for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/$year/$month/*>) {
					my $day = get_last_folder($_);
					push(@res,new Date(day=>$day, month=>$month, year=>$year));
				}
			}
		}
		return @res;
	}
}

sub do_for_all(&$) {
	my $subref = shift;
	my $do_thread = shift;
	my @dates = get_all_dates;
	#my @dates = (new Date(day=>24,month=>11,year=>2009), new Date(day=>25,month=>11,year=>2009), new Date(day=>26,month=>11,year=>2009));
	
	say "Datumu je ".scalar @dates;
	
	my @shared;
	if ($do_thread) {
		share(@shared);
	}

	for (@dates) {
		if ($do_thread) {
			my $thread =  threads->new( {'context' => 'list'}, sub { @shared= $subref->($_, @shared)});
			#@shared = $thread->join();
			$thread->join();
		} else {
			
			@shared = $subref->($_, @shared);
			
		}
	}
	return @shared;
}

sub get_total_before_count {
	my ($last_date, $last_article) = get_last_saved();
	if (!$last_date) {
		$last_date = new Date(day=>0, month=>0, year=>0);
	}
	say "Last day je ".$last_date->get_to_string();
	
	#my $total;
	my ($res) = do_for_all(sub{
		
		#say "Whatever start.";
		
		my $d = shift;
		
		my $total = shift;

		if ($last_date->is_the_same_as($d)) {
			$total += $last_article+1;
		}
		if ($d->is_older_than($last_date)) {
			$total += $d->article_count();
		}
		
		return $total;
		#say "Zkoumam ".$d->get_to_string." ; zatim ".$total;
		
	},0);
	
	return $res;
	
}



1;
