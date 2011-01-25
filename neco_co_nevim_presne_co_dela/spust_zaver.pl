use warnings;
use strict;
use 5.008;
use Globals;

use All;
say "start";

#All::get_total_themes();
my $p = Globals::undump_bz2("sem");
say "lodnuta";
for (@{$p}[0..100]) {
	say $_->lemma;
}

say "end";
