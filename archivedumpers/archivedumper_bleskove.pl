#Tyto skripty pro stahovani z archivu NEFUNGUJI, potrebovaly by upravu. Jsou prilozeny spise pro informaci.
use strict;
use warnings;

use WebReader;
use Article;
use Date;
use Globals;

use 5.010;

my $day_ = 12;
my $month_ = 12;
while ($month_ >= 4) {
	my $url = "http://bleskove.centrum.cz/archiv.phtml?section=1541&limit=20000&date=$day_.$month_.2010&type[1]=clanky";
	my $archive = read_from_web($url);
	while ($archive=~/<p> <span><b>(..)\.(..)\.2010<\/b><\/span> <span>[^<]*nek<\/span> <span><a href="([^"]*)" title="[^"]*">[^<]*<\/a><\/span> <\/p>/g) {
		my $d = $1;
		my $m = $2;
		my $art = $3;
		
		say "d ", $d, " m ", $m, " art ", $art;
		
		
		$day_ = $d;
		$month_ = $m;
		if ($m>=4) {
			my $day = new Date(day=>$d, month=>$m, year=>2010);
			say "Day stvoren";
			my $art_obj = new Article(url=>"http:".$art);
		
			say "Art obj stvoren";
		
			say "Day je ", $day->get_to_string;
			
			$day->save_article($art_obj);
			say "Ulozeno.";

		}
		
		# say ".";
	}
	
	my $helpday = new Date(day=>$day_, month=>$month_, year=>2010);
	my $prevday = $helpday->get_days_after(-1);
	$day_ = $prevday->day;
	$month_ = $prevday->month;
}
say "end.";
