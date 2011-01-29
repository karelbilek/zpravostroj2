package Zpravostroj::Tasks;
#ma zakladni ulohy, co ma zpravostroj umet.

#vsechno by se melo teoreticky volat "pres" Tasks

use 5.008;
use strict;
use warnings;
use Zpravostroj::RSS;
use Zpravostroj::Globals;

sub refresh_RSS {
	for my $f (<data/RSS/*>) {
		my $RSS = undump_bz2($f);
		$RSS->refresh_urls;
		dump_bz2($f, $RSS);
	}
}


