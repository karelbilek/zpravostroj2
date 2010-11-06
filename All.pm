package All;

use 5.010;

# with 'ReturnsNewerCounts';

use strict;
use warnings;
use Date;
use Globals;

use File::Slurp;
use Data::Dumper;


sub get_all_dates {
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
		for my $dir_year (<data/articles/*>) {
			$dir_year=~/\/([^\/]*)$/;
			my $year = $1;
			say "Rok $year";
			for my $dir_month (<data/articles/$year/*>) {
				$dir_month=~/\/([^\/]*)$/;
				my $month = $1;
				say "Mesic $month.";
				for my $dir_day (<data/articles/$year/$month/*>) {
					$dir_day=~/\/([^\/]*)$/;
					my $day = $1;
					say "Day $day.";
					push(@res,new Date(day=>$day, month=>$month, year=>$year));
				}
			}
		}
		return @res;
	}
}

sub do_for_all {
	my $subref = shift;
	my @dates = get_all_dates;
	say "Datumu je ".scalar @dates;
	for (@dates) {
		$subref->($_);
	}
}

sub get_count {
	
	mkdir "data";
	mkdir "data/all";
	my ($last_date, $last_article) = get_last_saved();
	if (!$last_date) {
		$last_date = new Date(day=>0, month=>0, year=>0);
	}
	say "Last day je ".$last_date;
	
	my $d;
	my $counts;
	{
		my $c = undump_bz2("data/all/counts.bz2");
		if (defined $c) {$counts=$c}
	}
	
	do_for_all(sub{
		
		$d = shift;
		say "d je $d";
		my $wcount = undef;
		if ($last_date->is_the_same_as($d)) {
			$wcount = $d->get_count($last_article+1);
		}
		if ($last_date->is_older_than($d)) {
			$wcount = $d->get_count(0);
			
		}
		if (defined $wcount) {
			for (keys %$wcount) {
				$counts->{$_}+=$wcount->{$_};
			}
		}
		
	});
	dump_bz2("data/all/counts.bz2", $counts);
	set_last_saved($d, $d->article_count-1);
	return $counts;
}

sub get_last_saved {
	if (!-e "data/all/date_last_counted") {
		return ();
	}
	return (Date::get_from_file("data/all/date_last_counted"), read_file("data/all/article_last_counted"));
}

sub set_last_saved {
	my ($date, $num) = @_;
	$date->get_to_file("data/all/date_last_counted");
	write_file("data/all/article_last_counted", $num);
}

# sub datestamp_path {
	# mkdir "data";
	# mkdir "data/all";
	# return "data/all/datestamp";
# }

# sub lastcount_path {
	# mkdir "data";
	# mkdir "data/all";
	# return "data/all/lastcount.bz2";
# }



1;
