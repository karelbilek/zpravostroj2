use forks;
use warnings;
use strict;
use 5.008;
use Globals;
use Date;



use All;

say "start";
$|=1;
#All::resave_to_new();
All::set_all_themes();

my @r = All::review_all_final();

for my $t (@r) {
	my $f = $t->form;
	
	if ($f!~/\ /){
		print $f."\n";
	}
} 

say "end";
