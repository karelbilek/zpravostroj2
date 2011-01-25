package All;

use 5.008;
use forks;
use forks::shared;
# with 'ReturnsNewerCounts';

use strict;
use warnings;
use Date;
use Globals;
use Zpravostroj::TectoServer;
use RSS;

use Zpravostroj::Forker;

use File::Slurp;
use Data::Dumper;
use Scalar::Util qw(blessed);

use MyTimer;
use Theme;

$|=1;

my $tecto_thread;

sub run_tectomt {
	$|=1;
	$tecto_thread = threads->new( sub {    
		$|=1;
		
		
		$SIG{'KILL'} = sub { threads->exit(); }; 
		
		
		Zpravostroj::TectoServer::run;
		
		
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
	},1);
	
	stop_tectomt();
}

sub review_all_2 {
	set_latest_count();
}

sub review_all_3 {
	set_all_themes();
}


sub review_all_final {
	
	my %r = do_for_all(sub{
		my $d = shift;
		say "Day ", $d->get_to_string();
		my %imp_themes = @_;
		
		
		my @d_themes = $d->get_top_themes(100);
		for my $theme (@d_themes) {
			if (exists $imp_themes{$theme->lemma}) {
				$imp_themes{$theme->lemma} = $theme->add_another($imp_themes{$theme->lemma});
			} else {
				$imp_themes{$theme->lemma} = $theme;
				
			}
		}
		
		#my @res = map {$_->to_string()} values %imp_themes;
		return %imp_themes;
	}, 0);
	
	my @r_themes = values %r;
	
	@r_themes = sort {$b->importance <=> $a->importance} @r_themes;
	
	return @r_themes[0..100];
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
	},1);
	my @arr = sort{$b->importance <=> $a->importance} values %res_all;
	dump_bz2("sem", \@arr);
}

sub set_all_themes {
	MyTimer::start_timing("get all count");
	
	my $count = All::get_count();
	
	MyTimer::start_timing("get total before count");

	my $total = All::get_total_before_count();
	MyTimer::start_timing("prvni doforall priprava");
	
	#my $begin = new Date(day=>1, month=>7, year=>2010);
	
	do_for_all(sub{
		my $date = shift;
		#if ($begin->is_older_than($date)) {
			$date->get_and_save_themes($count, $total);
		#}
	},1);
	MyTimer::say_all();
}

sub resave_to_new {
	my $begin = new Date(day=>17,year=>2010, month=>8);
	do_for_all(sub{
		my $date = shift;
		if ($begin->is_older_than($date)) {
			say "Du na den ",$date->get_to_string();
			$date->resave_to_new();
		}
	},1);
}

sub get_theme_path{
	my $n = shift;
	$n=~s/[^a-zA-Z]//g;
	if ($n eq '') {
		$n = "empty";
	}
	$n = lc ($n);
	if (length $n < 4) {
		$n = $n."____";
	}
	my $first = substr($n, 0, 1);
	my $second = substr($n, 1, 1);
	my $third = substr($n,2,2);
	
	mkdir "data";
	mkdir "data/themes_history";
	mkdir "data/themes_history/".$first;
	mkdir "data/themes_history/".$first."/".$second;

	
	return "data/themes_history/".$first."/".$second."/".$third.".bz2";
}

sub delete_from_theme_files{
	my $theme_list = shift;
	my $date = shift;
	
	if (((blessed $theme_list)||"") eq "ThemeHash") {
		#_change_theme_files(0,$theme_list, $date);
		#ted ne, protoze smazano rucne
	}
	
	
}

sub add_to_theme_files{
	my $theme_list = shift;
	my $date = shift;
	
	
	
	_change_theme_files(1,$theme_list, $date);
}

sub _change_theme_files{
	my $add = shift;
	my $theme_list = shift;
	
	my $forker = new Forker(size=>40);
	
	my $date = shift;
	
	#pro kazde tema
	for my $theme ($theme_list->all_themes) {
		
		if ($theme->importance > 7 or (!$add)) {
			my $subref = sub {
				my $lemma = $theme->lemma;
				my $form = $theme->form;
		
				my $should_dump;
		
				#vezmi cestu a nacti soubor s tematy, pokud existuje
				my $path = get_theme_path($lemma);
				my $theme_file_load;
				if (-e $path) {
					$theme_file_load = undump_bz2($path, "themefile");
				}
		
				if ($add) {
			
					$theme_file_load -> {$lemma} {$form} {$date->get_to_string()} = $theme->{importance};
					$should_dump = 1;
			
				} else {
			
					#postupne cistit vsechny pripadne prazdne hashe
					delete $theme_file_load -> {$lemma} {$form} {$date->get_to_string()};
			
					{
						#pokud dana kombinace soubor - lemma - form nema smysl...
				
						my $lemmahash = $theme_file_load -> {$lemma};
						if (scalar keys %{$lemmahash -> {$form}}==0) {
							#smaz ji
							delete $lemmahash -> {$form};
						}
					}
			
					{
						#totez s kombinaci soubor - lemma (v jednom souboru je hafo lemmat)
						if (scalar keys %{$theme_file_load -> {$lemma}} == 0) {
							delete $theme_file_load -> {$lemma};
						}
					}
			
					{
						#a pokud je prazdny i hash, proc drzet soubor?
						if (scalar keys %{$theme_file_load} == 0) {
							$should_dump = 0;
						} else {
							$should_dump = 1;
						}
					}
				}
				if ($should_dump) {
					dump_bz2($path, $theme_file_load, "themefile");
				} else {
					system("rm $path") if (-e $path);
				}
			};
			$forker->run($subref);
		}
	}
	
	$forker->wait();
	
	
}

sub _get_last_folder {
	my $w = shift;
	$w=~/\/([^\/]*)$/;
	return $1;
}


sub get_all_dates {
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
		for (sort {_get_last_folder($a)<=>_get_last_folder($b)} <data/articles/*>) {
			my $year = _get_last_folder($_);;
			for (sort {_get_last_folder($a)<=>_get_last_folder($b)} <data/articles/$year/*>) {
				my $month = _get_last_folder($_);
				for (sort {_get_last_folder($a)<=>_get_last_folder($b)} <data/articles/$year/$month/*>) {
					my $day = _get_last_folder($_);
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
	
	my @res = do_for_all(sub{
		
		my $d = shift;
		shift;
		my %counts = @_;
		if ((scalar keys %counts)==0 and defined $defcounts) {
			%counts = %$defcounts;
		}
		
		say "d je ".$d->get_to_string();
		my $wcount = undef;
		if ($last_date->is_the_same_as($d)) {
			$wcount = {$d->get_count($last_article+1)};
		}
		if ($last_date->is_older_than($d)) {
			$wcount = {$d->get_count(0)};
			
		}
		if (defined $wcount) {
			for (keys %$wcount) {
				if ($wcount->{$_}>=$min_article_count_per_day) {
					$counts{$_}+=$wcount->{$_};
				}
			}
		}
		
		#if (!($i%5)) {
			say "POZOR POZOR UKLADAM MEZISOUCTY na datu ", $d->get_to_string();
			dump_bz2("data/all/counts.bz2", \%counts);
			set_last_saved($d, $d->article_count-1);
		#}
		
		return ($d->get_to_string, %counts);
		#return ($counts, $d, $i);
		
	},1);
	my $last_day_string = shift @res;
	my $last_d = Date::get_from_string($last_day_string);
	my $res_counts = {@res};
	dump_bz2("data/all/counts.bz2", $res_counts);
	set_last_saved($last_d, $last_d->article_count-1);
	return $res_counts;
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
