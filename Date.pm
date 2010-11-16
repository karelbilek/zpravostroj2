package Date;
 
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use MooseX::Storage;

with Storage;

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

	open my $f, "<:utf8", $pth;
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
	open my $f, ">:utf8", $where;
	print $f $s->get_to_string;
	close $f;
}

sub get_days_after_today {
	my $h = shift;
	my $d = new Date(year=>getpartoftime(5, $h)+1900, month=>getpartoftime(4, $h)+1, day=>getpartoftime(3, $h));
	return $d;
}

sub get_days_before_today {
	my $h = shift;
	return get_days_after_today(-$h);
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

sub daypath_themes {
	my $s = shift;
	mkdir "data";
	mkdir "data/daythemes";
	my $year = int($s->year);
	my $month = int($s->month);
	my $day = int($s->day);
	mkdir "data/daythemes/".$year;
	mkdir "data/daythemes/".$year."/".$month;	
	return "data/daythemes/".$year."/".$month."/".$day.".bz2";
}

sub save_day_themes {
	my $s = shift;
	my $themes = shift;

	my $path = $s->daypath_themes;
	dump_bz2($path, $themes);
}

sub get_top_themes{
	my $s = shift;
	my $path = $s->daypath_themes;
	
	
	my $themes = undump_bz2($path);
	
	my @themes_top = ((sort{$b->importance <=> $a->importance} values %$themes)[0..29]);
	
	return @themes_top;
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

sub temp_daypath_perldump {
	my $s = shift;
	mkdir "data";
	mkdir "data/perldump_articles";
	my $year = int($s->year);
	my $month = int($s->month);
	my $day = int($s->day);
	mkdir "data/perldump_articles/".$year;
	mkdir "data/perldump_articles/".$year."/".$month;	
	mkdir "data/perldump_articles/".$year."/".$month."/".$day;
	return "data/perldump_articles/".$year."/".$month."/".$day;
}


sub article_count{
	my $s=shift;
	my $ds = $s->daypath;
	my @s = <$ds/*>;
	return scalar @s;

}

sub temp_pdump_article_count {
	my $s=shift;
	my $ds = $s->temp_daypath_perldump;
	my @s = <$ds/*>;
	return scalar @s;
}


sub save_article {
	my $s = shift;
	my $a = shift;
	my $c = shift || $s->article_count();
	
	dump_bz2_new($s->daypath."/".$c.".bz2", $a);
	
}



sub read_article {
	my $s = shift;
	my $n = shift;
	return undump_bz2_new($s->daypath."/".$n.".bz2");
	
}

sub temp_pdump_read_article {
	my $s = shift;
	my $n = shift;
	return undump_bz2($s->temp_daypath_perldump."/".$n.".bz2");
	
}

sub do_for_all {
	my $s=shift;
	my $subr = shift;
	my $num = shift//0;
	my $c = $s->article_count;
	my $endnum = shift//($c-1);
	
	for ($num..$endnum) {
		my $a = $s->read_article($_);
		my $changed = $subr->($a);
		if ($changed) {$s->save_article($a, $_)}
	}
}

sub temp_resave_all {
	my $s=shift;
	my $num = shift//0;
	my $c = $s->temp_pdump_article_count;
	my $endnum = shift//($c-1);
	
	for ($num..$endnum) {
		my $a = $s->temp_pdump_read_article($_);
		$s->save_article($a, $_);
	}
}

sub get_and_save_themes {
	my $s = shift;
	my %day_themes;
	
	my $count = shift;
	my $total = shift;
	
	say "DAN.";
	my $i = 0;
	$s->do_for_all(sub {
		my $a = shift;
		say "I je $i.";
		if ($a->has_themes) {
			my $themes = $a->themes;
			All::delete_from_theme_files($themes, $s, $i);
			
		}
		$a->count_themes($total, $count);
		my $themes = $a->themes;
		for (@$themes) {
			if (exists $day_themes{$_->lemma}) {
				$day_themes{$_->lemma} = $day_themes{$_->lemma}->add_1;
			} else {
				$day_themes{$_->lemma} = $_->same_with_1;
			}
		}
		All::add_to_theme_files($themes, $s, $i);
		$i++;
		1;
	}
	);
	$s->save_day_themes(\%day_themes);
	say "ALLDAN";
}

sub get_count {
	my $s = shift;
	my $num = shift;
	my %counts;
	my $i=0;
	$s->do_for_all(sub{
		
		my $a = shift;
		say "i je $i";
		$i++;
		my $wcount = $a->word_counts;
		for (keys %$wcount) {
			$counts{$_}++;
		}
		return 0;
	}, $num);
	return \%counts;
}

sub get_counts_parts {
	my $s = shift;
	my $c = $s->get_count;
	
	my @k = keys %$c;
	say "naplno : ",scalar @k;
	my $max=0;
	for (@k) {if ($max<$c->{$_}) {$max=$c->{$_}}}
	for my $i (1..$max) {
		my @q = grep {$c->{$_}>=$i} @k;
		my $podil = (scalar @q) / (scalar @k);
		$podil *= 100;
		
		say $i," : ",$podil," %";
	}
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