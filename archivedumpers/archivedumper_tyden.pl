use strict;
use warnings;

use WebReader;
use Article;
use Date;
use Globals;

use 5.010;

for my $page (reverse(1..164)) {
	say "Page $page";
	my $archiv_page = read_from_web("http://www.tyden.cz/archiv/?page=$page&obsah=clanek&rubrika=6");
	
	say "archiv stahnut";
	
	while ($archiv_page=~/<h2>\s*<a href="([^"]*)" class="tahoma">[^<]*<\/a><\/h2>\s*<p class="author">Autor: <a href="[^"]*">[^<]*<\/a><\/p>\s*<p class="date">(..)\.(..)\.2010/sg){
		my $url = "http://www.tyden.cz".$1;
		my $d = $2;
		my $m = $3;
		
		say $url, " M: ",$m," D: ",$d;
		
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