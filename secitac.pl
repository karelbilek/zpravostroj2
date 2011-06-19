use strict;
use warnings;

use Zpravostroj::OutCounter;

my $oc = new Zpravostroj::OutCounter(name=>"data/allresults/top_lemmas_all", delete_on_start=>0);

$oc->count_it;

binmode STDOUT, ":utf8";



open my $if, "<:utf8", "data/allresults/top_lemmas_all_counted";

my %hash;

my $soucet;

for (<$if>) {
	/(.*)\t(.*)\n/;
	my $f = $1;
	my $s = $2;
	$soucet+=$s;
	$hash{$f}=$s;

}

# my %inhash = (pokus=>1, hokus=>1.5);
#  
# for (keys %inhash) {
# 	$soucet+=$inhash{$_};
# 	$hash{$_}=$inhash{$_};
# }


my %rhash;

while (my ($k, $v) = each %hash) {
	$rhash{$k}=$v/$soucet;
}

print $soucet."\n";
$soucet = 0;

#open my $ofX, ">:utf8", "data/allresults/RgraphX";
#open my $ofY, ">:utf8", "data/allresults/RgraphY";
#print $of "x<-c(1:".(scalar keys %hash).")\n";

my $i=0;
#my $first = 1;
for (sort {$rhash{$b}<=>$rhash{$a}} keys %hash) {
	$i++;
	my $per = $rhash{$_}*100;
	if (int($soucet/ 10)!=int(($soucet+$per)/10)) {
		print $i;
		print " & ";
		printf ("%.2f", $soucet+$per);
		print "\\% & ";
		print $_;
		print ' \\\\ \hline';
		print "\n";
	}
	$soucet+=$per;
	
	
}
#print $of ")\n";

#print $of "plot(x,y,type=\"n\"); \n lines(x,y,type=\"l\")\n";