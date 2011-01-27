use strict;
use warnings;

use Zpravostroj::WebReader;
use Article;
use Date;
use Globals;
use All;

use Zpravostroj::Forker;

my $f = new Zpravostroj::Forker(size=>10);

All::run_tectomt();

for my $page (reverse(1..1)) {
	say "Page $page";
	my $archiv_page = Zpravostroj::WebReader::wread("http://www.tyden.cz/archiv/?page=$page&obsah=clanek&rubrika=6");
	
	say "archiv stahnut";
	
	
	while ($archiv_page=~/<h2>\s*<small>[^<]*<\/small><br \/><a href="([^"]*)" class="tahoma">[^<]*<\/a><\/h2>\s*<p class="author">Autor: <a href="[^"]*">[^<]*<\/a><\/p>\s*<p class="date">(..)\.(..)\.(201[01])/sg){
		
		my $url = "http://www.tyden.cz".$1;
		
		my $d = $2;
		my $m = $3;
		my $y = $4;
		if ($y) {
			$f->run(sub {
				
			
			
				say $url, " M: ",$m," D: ",$d," Y :",$y;
		
				my $day = new Date(day=>$d, month=>$m, year=>$y);
				say "Day stvoren";
				my $art_obj = new Article(url=>$url);
	
				say "Art obj stvoren";
	
				say "Day je ", $day->get_to_string;
		
				$day->save_article($art_obj);
		
				say "Ulozeno.";
			});
		}
		
	}
}

say "pred wait...";
$f->wait;


say "pred stop_tectomt...";
All::stop_tectomt();

say "end.";