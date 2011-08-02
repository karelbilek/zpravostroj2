#Tyto skripty pro stahovani z archivu NEFUNGUJI, potrebovaly by upravu. Jsou prilozeny spise pro informaci.
use strict;
use warnings;

use WebReader;
use Article;
use Date;
use Globals;

use 5.010;

for my $page (reverse(1..628)) {
	say "Page $page";
	my $archiv_page = read_from_web("http://www.ceskenoviny.cz/archiv/?id_seznam=160&id_rubrika=36&seznam_start=".$page."0");
	
	say "archiv stahnut";
	
	while ($archiv_page=~/<div class='list-item'>\s*<h2><a href='([^']*)' title='[^']*'>[^<]*<\/a><\/h2>\s*<a href='[^']*'><img src='[^']*' border='0' class='image' title='[^']*' alt='[^']*' \/><\/a>\s*<p class='item-content bigger'>[^<]*<a href='[^']*' title='[^']*' class='blue-sip'>[^<]*<\/a><\/p>\s*<div class='cleaner'><\/div>\s*<\/div>\s*<p class='item-bottom' style='color:gray;'>(..)\.(..)\.2010 \| ..:.. \| Témata: <span>/sg){
		my $url = $1;
		my $d = $2;
		my $m = $3;
		
		# say $url, " M: ",$m," D: ",$d;
		my $day = new Date(day=>$d, month=>$m, year=>2010);
		say "Day stvoren";
		my $art_obj = new Article(url=>$url);
	
		say "Art obj stvoren";
	
		say "Day je ", $day->get_to_string;
		
		$day->save_article($art_obj);
		
		say "Ulozeno.";
		
	}
}

say "end.";