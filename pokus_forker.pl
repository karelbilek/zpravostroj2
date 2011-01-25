use warnings;
use strict;

use Zpravostroj::Forker;

my $forker = new Zpravostroj::Forker(size=>10);
$|=1;
for my $i (1..20) {
	print "v cyklu $i\n";
	
	my $sub = sub {
		$|=1;
		print "v sub $i. pred cekanim.\n";
		
		sleep($i);
		print "v sub $i. po cekani.\n";
	};
	
	$forker->run($sub);
}

$forker->wait();