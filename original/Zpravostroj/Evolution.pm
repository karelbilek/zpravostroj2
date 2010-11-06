package Zpravostroj::Evolution;

use base 'Exporter';
our @EXPORT = qw(evolute);

use Zpravostroj::Other;
use Zpravostroj::Database;
use Zpravostroj::Counter;



my @articles = read_pool_articles;

sub iterate {
	my ($as, $bs, $cs, $ds) = @_;
	
	print "==============NEXT ITERATION====\n";
	
	for my $i (1..10) {
		my %r;
		print".\n";
		eval {%r = count_themes($as->[$i],$bs->[$i],$cs->[$i],$ds->[$i],@articles)};
		while ($@) {
			print".\n";
			$as->[$i] = rand();
			$bs->[$i] = rand();
			$cs->[$i] = rand();
			$ds->[$i] = rand();
			eval {%r = count_themes($as->[$i],$bs->[$i],$cs->[$i],$ds->[$i],@articles)};
		}
		if (!$r{top_themes}) {
			print "SHII --- $@ ----\n";
			die "I DONT UNDERSTAND\n";
		}
		update_pool_themes($r{top_themes}, "test".$i);
	}
	
	print "==========done=\n";
	print "Tell me 1st best:\n";
	my $best1 = <>;
	chomp($best1);
	print "Tell me 2nd best:\n";
	my $best2 = <>;
	chomp($best2);
	
	my @worst;
	for my $i (0..3) {
		print "OK, now tell me $i worst:\n";
		$worst[$i]=<>;
		chomp($worst[$i]);
	}
	
	print "======ok so far the best 2 are:\n";
	print $as->[$best1].":".$bs->[$best1].":".$cs->[$best1].":".$ds->[$best1]."\n";
	print $as->[$best2].":".$bs->[$best2].":".$cs->[$best2].":".$fs->[$best2]."\n";
	
	
	for my $i (0..3) {
		if ($i==0) {
			my $w1=rand();
			my $w2=rand();
			$as->[$worst[$i]] = ($w1*($as->[$best1])+$w2*($as->[$best2]))/($w1+$w2);
		} else {
			$as->[$worst[$i]] = (($as->[$best1])+($as->[$best2]))/2;
		}
		
		if ($i==1) {
			my $w1=rand();
			my $w2=rand();
			$bs->[$worst[$i]] = ($w1*($bs->[$best1])+$w2*($bs->[$best2]))/($w1+$w2);
		} else {
			$bs->[$worst[$i]] = (($bs->[$best1])+($bs->[$best2]))/2;
		}
		
		if ($i==2) {
			my $w1=rand();
			my $w2=rand();
			$cs->[$worst[$i]] = ($w1*($cs->[$best1])+$w2*($cs->[$best2]))/($w1+$w2);
		} else {
			$cs->[$worst[$i]] = (($cs->[$best1])+($cs->[$best2]))/2;
		}
		
		if ($i==3) {
			my $w1=rand();
			my $w2=rand();
			$ds->[$worst[$i]] = ($w1*($ds->[$best1])+$w2*($ds->[$best2]))/($w1+$w2);
		} else {
			$ds->[$worst[$i]] = (($ds->[$best1])+($ds->[$best2]))/2;
		}
	}
	
	
}

sub evolute {
	my @as = map {rand()} (1..10);
	my @bs = map {rand()} (1..10);
	my @cs = map {rand()} (1..10);
	my @ds = map {rand()} (1..10);
	
	for (1...10) {iterate(\@as,\@bs,\@cs,\@ds);}
}
