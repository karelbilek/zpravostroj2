package ThreadModule;

use forks;
use HTML::DOM;

$|=1;

my $fork;

sub run_thread {
	$|=1;
	print "Pred.\n";
	$fork = threads->new( sub {    
		$|=1;
		print "Uvnitr\n";
	} );
	print "Po - $fork\n";
}

1;