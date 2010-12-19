#http://www.lidovky.cz/ln_domov.asp?strana=375
use strict;
use warnings;

use WebReader;
use Article;
use Date;
use Globals;

use 5.010;

for my $page (reverse(1..374)) {
	say "Page $page";
	my $archiv_page = read_from_web("http://www.lidovky.cz/ln_domov.asp?strana=$page");
	
	say "archiv stahnut";
	
	while ($archiv_page=~/<h3><a href="([^"]*)">[^<]*<\/a><\/h3><a href="[^"]*"><img src="[^"]*" width="[^"]*" height="[^"]*" border="[^"]*" alt="[^"]*"><\/a><p class="perex">[^<]*<a class="more" href="[^"]*">/g){
		my $url = $1;
		
		if ($url=~/\?c=A10(..)(..)/) {
			my $m = $1;
			my $d = $2;
			my $day = new Date(day=>$d, month=>$m, year=>2010);
			say "Day stvoren";
			my $art_obj = new Article(url=>$url);
		
			say "Art obj stvoren";
		
			say "Day je ", $day->get_to_string;
		
			
			
			$day->save_article($art_obj);
			
			say "Ulozeno.";
			
		}
		
	}
}

say "end";