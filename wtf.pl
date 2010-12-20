use forks;
use HTML::DOM;

$|=1;

print "before\n";
threads->new( sub {
	$|=1;
	print "inside\n";
} );

print "after\n";

sleep(3600);