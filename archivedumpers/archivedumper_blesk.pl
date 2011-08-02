#Tyto skripty pro stahovani z archivu NEFUNGUJI, potrebovaly by upravu. Jsou prilozeny spise pro informaci.
use strict;
use warnings;

use WebReader;
use Article;
use Date;
use Globals;

use 5.010;

for my $page (reverse(1..355)) {
	say "Page $page";
	my $archiv_page = read_from_web("http://www.blesk.cz/kategorie/7/zpravy?page=$page");
	
	say "archiv stahnut";
	while ($archiv_page=~/<a href="([^"]*)" target="_top" class="titleAnotA( top)?"/g){
		my $url = $1;
		
		my $art = read_from_web($url);
		say "$url stahnuto";
		
		if ($art=~/<span class="artTime">(..)\.(..)\.2010/) {

			my $d = $1;
			my $m = $2;
			say "D je $d, M je $m";
		
			my $day = new Date(day=>$d, month=>$m, year=>2010);
			say "Day stvoren";
			my $art_obj = new Article(url=>$url, html_contents=>$art);
		
			say "Art obj stvoren";
		
			say "Day je ", $day->get_to_string;
		
			
			
			$day->save_article($art_obj);
			say "Ulozeno.";
		}
	}
}