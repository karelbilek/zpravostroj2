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
	
	if (((blessed $theme_list)||"") eq "Zpravostroj::ThemeHash") {
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
				if ($wcount->{$_}>=$MIN_ARTICLE_COUNT_PER_DAY_WTF) {
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


1;
