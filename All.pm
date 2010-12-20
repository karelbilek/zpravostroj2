package All;

use 5.008;
use forks;
# with 'ReturnsNewerCounts';

use strict;
use warnings;
use Date;
use Globals;
use TectoServer;
use RSS;

use File::Slurp;
use Data::Dumper;

$|=1;

my $tecto_thread;

sub run_tectomt {
	$|=1;
	$tecto_thread = threads->new( sub {    
		$|=1;
		
		
		$SIG{'KILL'} = sub { threads->exit(); }; 
		
		
		TectoServer::run;
		
		
	} );

}


sub stop_tectomt {
	$|=1;
	say "Zastavuji tectoMT ve Stop_tectomt";
	$tecto_thread->kill('KILL')->detach();
}


sub do_once_per_hour {
	for my $f (<data/RSS/*>) {
		my $RSS = undump_bz2($f);
		$RSS->load_article_urls;
		dump_bz2($f, $RSS);
	}
}

sub review_all {
	$|=1;
	
	run_tectomt();
	
	do_for_all(sub{
		my $d = shift;
		#my $d = new Date(day=>13, month=>12, year=>2010);
		if ($d->month >=3 and $d->year >= 2010) {
		#if ($d->month ==7 and $d->year >= 2010) {	
			$d->review_all();
		}
	});
	
	stop_tectomt();
}

sub do_once_per_day {
	$|=1;
	
	run_tectomt();
	
	my @links;
	my $date = new Date();
	
	for my $f (<data/RSS/*>) {
		my $RSS = undump_bz2($f);
		push (@links, $RSS->get_article_urls);
		dump_bz2($f, $RSS);
	}
	
	for my $link (@links) {
		say "tvorim $link";
		my $a = new Article(url=>$link); #the whole creation happens here
		
		say "ukladam $link";
		$date->save_article($a);
	}
	
	say "zastavuji tmt";
	stop_tectomt(); #so it doesn't mess the memory when I don't really need it
	
	say "set_latest_count (buhvi co to udela)";
	set_latest_count(); #looks at the latest count, adds all younger stuff (which means all the new articles, basically)
	
	say "set_all_themes (modleme se)";
	set_all_themes(); #goes through ALL the articles - including the new ones - and sets new themes, based on the new counts
	
	say "ze by... hotovo?!?";
}

sub get_total_themes {
	my %res_all = do_for_all (sub {
		my $d = shift;
		my %all = @_;
		
		say "Delam den ", $d->get_to_string();
		
		my $ts = $d->get_day_themes;
		
		my @arr = (sort{$ts->{$b}->importance <=> $ts->{$a}->importance} keys %$ts)[0..300];
		#my %ts_filtered = map {($_=>$ts->{$_})} @arr;
		
		for my $key (@arr) {
			if (defined $key) {
				if (exists $all{$key}) {
					$all{$key} = $all{$key}->add_another($ts->{$key});
				} else {
					$all{$key} = $ts->{$key};
				}
			}
		}
		
		return %all;
	});
	my @arr = sort{$b->importance <=> $a->importance} values %res_all;
	dump_bz2("sem", \@arr);
}

sub set_all_themes {
	say "Nacitam count..";
	my $count = All::get_count();
	say "nacitam total_b_count";
	my $total = All::get_total_before_count();
	do_for_all(sub{
		my $date = shift;
		$date->get_and_save_themes($count, $total);
	});
}

sub get_theme_path{
	my $n = shift;
	$n=~s/[^a-zA-Z]//g;
	if ($n eq '') {
		$n = "empty";
	}
	my $first = substr($n, 0, 2);
	
	mkdir "data";
	mkdir "data/themes_history";
	mkdir "data/themes_history/".$first;
	
	return "data/themes_history/".$first."/".$n.".bz2";
}

sub delete_from_theme_files{
	my $theme_list = shift;
	my $date = shift;
	my $artnum = shift;
	_change_theme_files(0,$theme_list, $date, $artnum);
}

sub add_to_theme_files{
	my $theme_list = shift;
	my $date = shift;
	my $artnum = shift;
	_change_theme_files(1,$theme_list, $date, $artnum);
}

sub _change_theme_files{
	my $add = shift;
	my $theme_list = shift;
	my $date = shift;
	my $artnum = shift;
	
	for my $theme (@$theme_list) {
		
		my $path = get_theme_path($theme->lemma);
		
		my $theme_file_load;
		if (-e $path) {
			$theme_file_load = undump_bz2($path);
		}
		if ($add) {
			if (!exists $theme_file_load -> {$theme->lemma}) {
				$theme_file_load->{$theme->lemma}{form} = $theme->form;
			}
			$theme_file_load->{$theme->lemma}{seen}{$date->get_to_string}{$artnum}=undef;
		} else {
			delete $theme_file_load->{$theme->lemma}{seen}{$date->get_to_string}{$artnum};
			if (scalar keys %{$theme_file_load->{$theme->lemma}{seen}{$date->get_to_string}}==0) {
				delete $theme_file_load->{$theme->lemma}{seen}{$date->get_to_string};
			}
			if (scalar keys %{$theme_file_load->{$theme->lemma}{seen}}==0) {
				delete $theme_file_load->{$theme->lemma};
			} 
		}
		dump_bz2($path, $theme_file_load);
	}
	
	
}



sub get_all_dates {
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
		for my $dir_year (<data/articles/*>) {
			$dir_year=~/\/([^\/]*)$/;
			my $year = $1;
			for my $dir_month (<data/articles/$year/*>) {
				$dir_month=~/\/([^\/]*)$/;
				my $month = $1;
				for my $dir_day (<data/articles/$year/$month/*>) {
					$dir_day=~/\/([^\/]*)$/;
					my $day = $1;
					push(@res,new Date(day=>$day, month=>$month, year=>$year));
				}
			}
		}
		return @res;
	}
}

sub do_for_all(&) {
	my $subref = shift;
	my @dates = get_all_dates;
	say "Datumu je ".scalar @dates;
	
	my @pseudoshared;

	for (@dates) {
		my $thread =  threads->new( {'context' => 'list'}, sub { return $subref->($_, @pseudoshared)});
		@pseudoshared = $thread->join();
	}
	return @pseudoshared;
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
		
	});
	
	return $res;
	
}

sub get_count {
	return undump_bz2("data/all/counts.bz2");
	
}

sub set_latest_count {
	
	mkdir "data";
	mkdir "data/all";
	my ($last_date, $last_article) = get_last_saved();
	if (!$last_date) {
		$last_date = new Date(day=>0, month=>0, year=>0);
	}
	say "Last day je ".$last_date->get_to_string();
	
	#my $d;
	my $defcounts;
	{
		my $c = undump_bz2("data/all/counts.bz2");
		if (defined $c) {$defcounts=$c}
	}
	
	my ($res, $last_d) = do_for_all(sub{
		
		my $d = shift;
		my $counts = shift;
		if (!defined $counts) {
			$counts = $defcounts;
		}
		say "d je ".$d->get_to_string();
		my $wcount = undef;
		if ($last_date->is_the_same_as($d)) {
			$wcount = $d->get_count($last_article+1);
		}
		if ($last_date->is_older_than($d)) {
			$wcount = $d->get_count(0);
			
		}
		if (defined $wcount) {
			for (keys %$wcount) {
				if ($wcount->{$_}>=$min_article_count_per_day) {
					$counts->{$_}+=$wcount->{$_};
				}
			}
		}
		return ($counts, $d);
		
	});
	dump_bz2("data/all/counts.bz2", $res);
	set_last_saved($last_d, $last_d->article_count-1);
	return $res;
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
