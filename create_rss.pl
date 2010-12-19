use Globals;
use RSS;

use 5.010;
use warnings;
use strict;

my $i=0;
for my $rss_url(qw(http://www.blesk.cz/rss
http://servis.idnes.cz/rss.asp?c=zpravodaj
http://www.lidovky.cz/export/rss.asp
http://www.tyden.cz/rss-export.php
http://ihned.cz/?p=000000_rss
http://aktualne.centrum.cz/export/rss-hp.phtml
http://www.ceskenoviny.cz/sluzby/rss/index.php
http://www.financninoviny.cz/sluzby/rss/index.php
http://bleskove.aktualne.centrum.cz/export/rss-bleskove-hp.phtml)) {
	
	dump_bz2("data/RSS/".$i.".bz2", new RSS(url=>$rss_url));
	
}continue{
	
	$i++
}