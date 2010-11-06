package Date;
 
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;



use Article;
use Globals;

# with 'ReturnsNewerCounts';

has 'day' => (
	is=>'ro',
	isa=>'Int',
	default=>sub{getpartoftime(3)}
);

has 'month' => (
	is=>'ro',
	isa=>'Int',
	default=>sub{getpartoftime(4)+1}
);

has 'year' => (
	is=>'ro',
	isa=>'Int',
	default=>sub{getpartoftime(5)+1900}
);

sub get_from_string {
    my $d = shift; 
	$d=~/(\d\d\d\d)-(\d+)-(\d+)/;
	return new Date(day=>$3, month=>$2, year=>$1);
}

sub get_from_file {
	my $pth = shift;

	open my $f, "<", $pth;
	my $d = <$f>;
	close $f;
	return get_from_string($d);
}

sub get_to_string {
	my $s = shift;
	return $s->year."-".$s->month."-".$s->day;
}

sub get_to_file {
	my $s = shift;
	my $where = shift;
	say "Get to file: s je $s , where je $where";
	open my $f, ">", $where;
	print $f $s->get_to_string;
	close $f;
}

sub get_days_after_today {
	my $h = shift;
	my $d = new Date(year=>getpartoftime(5, $h)+1900, month=>getpartoftime(4, $h)+1, day=>getpartoftime(3, $h));
	return $d;
}

sub is_the_same_as {
	my ($a, $b) = @_;
	return($a->year == $b->year and $a->month eq $b->month and $a->day eq $b->day);
}

sub is_older_than {
	my ($s, $newer)=@_;
	if ($newer->year > $s->year) {
			return 1;
		}
		if ($newer->year < $s->year) {
			return 0;
		}
		if ($newer->month > $s->month) {
			return 1;
		}
		if ($newer->month < $s->month) {
			return 0;
		}
		if ($newer->day > $s->day) {
			return 1;
		}
		if ($newer->day < $s->day) {
			return 0;
		}
		
		return 0;
}

sub getpartoftime {
	
	my $w=shift;
	my $plus = shift || 0;
	my @r = localtime(time() + $plus * 86400);
	return $r[$w];
}

sub daypath {
	my $s = shift;
	mkdir "data";
	mkdir "data/articles";
	my $year = int($s->year);
	my $month = int($s->month);
	my $day = int($s->day);
	mkdir "data/articles/".$year;
	mkdir "data/articles/".$year."/".$month;	
	mkdir "data/articles/".$year."/".$month."/".$day;
	return "data/articles/".$year."/".$month."/".$day;
}


sub article_count{
	my $s=shift;
	my $ds = $s->daypath;
	my @s = <$ds/*>;
	return scalar @s;

}

sub save_article {
	my $s = shift;
	my $a = shift;
	my $c = shift || $s->article_count();
	
	dump_bz2($s->daypath."/".$c.".bz2", $a);
	
}

sub read_article {
	my $s = shift;
	my $n = shift;
	return undump_bz2($s->daypath."/".$n.".bz2");
	
}

sub do_for_all {
	my $s=shift;
	my $subr = shift;
	my $num = shift||0;
	my $c = $s->article_count;
	for ($num..$c-1) {
		my $a = $s->read_article($_);
		my $changed = $subr->($a);
		if ($changed) {$s->save_article($a, $_)}
	}
}

sub get_count {
	my $s = shift;
	my $num = shift;
	my %counts;
	$s->do_for_all(sub{
		
		my $a = shift;
		my $wcount = $a->word_counts;
		for (keys %$wcount) {
			$counts{$_}++;
		}
		return 0;
	}, $num);
	return \%counts;
}

# sub lastcount_path {
	# my $s = shift;
	# return $s->daypath."/lastcount.bz2";
# }

# sub datestamp_path {
	# my $s = shift;
	# return $s->daypath."/datestamp";
# }

__PACKAGE__->meta->make_immutable;


1;


# package main;
# use Data::Dumper;

# my $d = Date->new();
 # my $r = Article->new(url=>"http://aktualne.centrum.cz/domaci/volby/komunalni-volby/clanek.phtml?id=680222");
 # print "CREATION DONE!\n";

# $d->save_article($r);