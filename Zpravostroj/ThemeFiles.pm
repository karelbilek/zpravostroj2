package Zpravostroj::ThemeFiles;
#Modul na zpracovávání historií témat

#Historie tématu je - možná bohužel - jenom "hnusný" hash hashů hashů
#Každé téma dostane soubor, co je jeho název založen na prvních 4 písmenech
#v "první vlně" jsou v keys lemmata (jeden soubor sdílejí všechna lemmata co začínají na ta 4 písmena)
#v "druhé vlně" jsou v keys forms 
#ve "třetí vlně" jsou v keys datumy, jako values jsou potom počty článků s tímto tématem tohoto data


use 5.008;
use strict;
use warnings;
use Zpravostroj::Globals;
use Scalar::Util qw(blessed);

use Zpravostroj::Forker;
use Date;
use Zpravostroj::Theme;

#vrátí adresu pro soubor s historií
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

#smaže historii s datem $date ze všech témat v theme_hash
#(tj. jakoby to smaže všechna existující témata toho dne, abych mohl spočítat nová)
sub delete_from_theme_history{

	#theme_hash je Zpravostroj::ThemeHash
	my $theme_hash = shift;
	my $date = shift;
	
	if (((blessed $theme_hash)||"") eq "Zpravostroj::ThemeHash") {
		_change_theme_history(0,$theme_hash, $date);
	}
}

#přidá do historie všechna témata s theme_hash s datem $date
#přičemž v $theme->importance je vždycky počet článků 
sub add_to_theme_history{

	#theme_hash je Zpravostroj::ThemeHash
	my $theme_hash = shift;
	my $date = shift;
	
	_change_theme_history(1,$theme_hash, $date);
}

#pomocná procedura na smazani jednoho tematu z hashe
#(a pripadne vsech dalsich stupnu, pokud jsou ty hashe prazdne)
sub _delete_one_theme {
	my ($theme_file_load, $theme, $date) = @_;
	delete $theme_file_load -> {$theme->lemma} {$theme->form} {$date->get_to_string()};

	
		#pokud dana kombinace "soubor - lemma - form" nema smysl...

	my $lemmahash = $theme_file_load -> {$theme->lemma};
	if (! %{$lemmahash -> {$theme->form}}) {
		#smaz ji
		delete $lemmahash -> {$theme->form};
	}
	

	
	#totez s kombinaci "soubor - lemma" (v jednom souboru je hafo lemmat)
	if (! %{$theme_file_load -> {$theme->lemma}} ) {
		delete $theme_file_load -> {$theme->lemma};
	}
	

	
	#a pokud je prazdny i hash, proc drzet soubor?
	#(mam to takhle, abych nemusel psat return scalar %{$theme_file_load}, coz jsem prave napsal :) )
	if (! %{$theme_file_load}) {
		return 0;
	} else {
		return 1;
	}
}


#pomocná procedura, co VRACÍ PROCEDURU, co změní jedno téma
#dá se jí téma, datum a to, jestli přidávám nebo ubírám
sub _change_one_theme {
	my $theme = shift;
	
	my $date = shift;
	
	my $add = shift;
	
	
	return sub {
		my $path = get_theme_path($theme->lemma);
		say "Jsem v change one theme $path";
		my $theme_file_load;
		#theme_file_load je ten hash, co je v souboru s historií
		
		if (-e $path) {
			$theme_file_load = undump_bz2($path, "themefile");
		}
		
		my $should_keep_file;
		if ($add) {
	
			$theme_file_load -> {$theme->lemma} {$theme->form} {$date->get_to_string()} = $theme->importance;
			$should_keep_file = 1;
	
		} else {
			$should_keep_file = _delete_one_theme($theme_file_load, $theme, $date);
		}
		
		if ($should_keep_file) {
			dump_bz2($path, $theme_file_load, "themefile");
		} else {
			system("rm $path") if (-e $path);
		}
		
	};
}

#pomocná procedura, co dostane themehash z nejakeho dne
#a všechno popřidává nebo poubírá podle toho, jestli add je 1 nebo 0
sub _change_theme_history{
	my $add = shift;
	my $theme_hash = shift;
	
	my $forker = new Zpravostroj::Forker(size=>40);
	
	my $date = shift;
	
	#pro kazde tema
	for my $theme ($theme_hash->all_themes) {
		
		if ($theme->importance > 7) {
			my $subref = _change_one_theme($theme, $date, $add);
			$forker->run($subref);
		}
	}
	
	$forker->wait();
	
}

sub _daypath_themes {
	my $d = shift;
	mkdir "data";
	mkdir "data/daythemes";
	my $year = int($d->year);
	my $month = int($d->month);
	my $day = int($d->day);
	mkdir "data/daythemes/".$year;
	mkdir "data/daythemes/".$year."/".$month;	
	return "data/daythemes/".$year."/".$month."/".$day.".bz2";
}


sub save_day_themes {
	my $d = shift;
	my $themes = shift;

	my $path = _daypath_themes($d);
	say $path;
	dump_bz2($path, $themes, "ThemeHash");
}

sub get_day_themes {
	my $d = shift;
	my $path = _daypath_themes($d);

	my $themes = undump_bz2($path, "ThemeHash");
	return $themes;
}

sub get_top_themes{
	my $d = shift;
	my $n = shift;
	my $path = _daypath_themes($d);
	
	
	my $themes = undump_bz2($path);
	
	if ($themes) {
		my @themes_top = $themes->top_themes($n);
	
	
		return @themes_top;
	} else {
		return ();
	}
}

1;