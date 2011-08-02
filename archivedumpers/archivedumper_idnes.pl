#Tyto skripty pro stahovani z archivu NEFUNGUJI, potrebovaly by upravu. Jsou prilozeny spise pro informaci.

use strict;
use warnings;

use WebReader;
use Article;
use Date;

use 5.010;



my $start = new Date(day=>31, month=>10, year=>2010);

my $day = $start;

while (!($day->is_the_same_as(new Date()))) {
#for (1..10) {
	my $archiv_url = "http://zpravy.idnes.cz/archiv.asp?datum=".$day->day.".".$day->month.".".$day->year."&ostrov=zpravodaj";
	$|=1;
	
	say $day->get_to_string();

	my $archiv_page = read_from_web($archiv_url);

	my $count;
	if ($archiv_page =~ /href="\?datum=[^&]*&amp;ostrov=zpravodaj&amp;strana=([^"]*)"><span><\/span>dal/) {
		$count = $1;
	} else {
		$count = 1;
	}
	
	for my $page (1..$count) {
		if ($page==1) {
			$archiv_url = "http://zpravy.idnes.cz/archiv.asp?datum=".$day->day.".".$day->month.".".$day->year."&ostrov=zpravodaj&strana=".$page;
			$archiv_page = read_from_web($archiv_url);
		}
		
		while ($archiv_page =~ /<h3><a href="([^"]*)">/g) {
			my $article_url = $1;
			my $art_obj = new Article(url=>$article_url);
			$day->save_article($art_obj);
		}
		
	}
	say "endday";
} continue {
	$day = $day->get_days_after(1);
}

say "end";