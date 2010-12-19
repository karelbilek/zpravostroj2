package Date;
 
use 5.008;
use Globals;
use forks;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use Time::Local 'timelocal';
use MooseX::Storage;

with Storage;

use Article;
use Globals;
use MyTimer;


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


sub get_days_after {
	my $s = shift;
	my $h = shift;
	my $d = new Date(year=>getpartoftime(5, $h, $s)+1900, month=>getpartoftime(4, $h, $s)+1, day=>getpartoftime(3, $h, $s));
	return $d;
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

sub get_day_themes {
	my $s = shift;
	my $path = $s->daypath_themes;
	
	
	my $themes = undump_bz2($path);
	return $themes;
}

sub get_top_themes{
	my $s = shift;
	my $path = $s->daypath_themes;
	
	
	my $themes = undump_bz2($path);
	
	my @themes_top = ((sort{$b->importance <=> $a->importance} values %$themes)[0..29]);
	
	return @themes_top;
}

#localtime -> z casoscalaru pole
#time -> cas
#?? -> 


sub getpartoftime {
	
	my $w=shift;
	my $plus = shift || 0;
	my $d = shift;
	my $tme = $d ? timelocal(0,0,0,$d->day,$d->month-1,$d->year) : time();
	my @r = localtime($tme + $plus * 86400+((defined $d and $d->month==10 and $plus>0)?3600:0));
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


sub if_undef {
	my $what = shift;
	my $ifnull = shift;
	if (defined $what) {
		return $what;
	} else {
		return $ifnull;
	}
}

sub save_article {
	my $s = shift;
	my $a = shift;
	my $c = if_undef(shift, $s->article_count());
	
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
	my $num = if_undef(shift,0);
	my $c = $s->article_count;
	my $endnum = if_undef(shift, ($c-1));
	$|=1;
	
	my @pseudoshared;
	
	for ($num..$endnum) {
		
		my $thread = threads->new( {'context' => 'list'}, sub {
		
			say "Num $_";
			MyTimer::start_timing("nacitani");
			say "nacitani v do_for_all";
			my $a = $s->read_article($_);
			say "hotovo nacitani v do_for_all";
			if (defined $a) {
				say "jdu spustit subref v do_for_all";
				my $changed;
				my @shared_copy = $subr->($a, \$changed, @pseudoshared);
				say "hotovo, jdu ukladat tamtez";
				if ($changed) {$s->save_article($a, $_)}
				say "hotovo ukladani, lezu z do_for_all";
				#say "shared copy je velky ", scalar @shared_copy;
				return @shared_copy;
			} else {
				MyTimer::count_error("undefined a");
				return ();
			}
		});
		
		@pseudoshared=$thread->join();
		#say "pseudoshared copy je velky ", scalar @pseudoshared;

	}
	
	return @pseudoshared;
}



sub get_and_save_themes {
	my $s = shift;
	
	#my %day_themes;
	$|=1;
	say "Jdu na den ", $s->get_to_string;
	
	my $count = shift;
	my $total = shift;
	
	my $i = 0;
	my %res_day_themes = $s->do_for_all(sub {
		my $a = shift;
		my $changed = shift;
		my %day_themes=@_;
		
		say "zacina delete_from_theme_files v get_and_save_themes";
		MyTimer::start_timing("delete_from_theme_files");
		
		if ($a->has_themes) {
			say "has_themes, jdu je nacist";
			my $themes = $a->themes;
			say "hotovo, jdu smazat";
			All::delete_from_theme_files($themes, $s, $i);
			say "hotovo";
		}
		
		say "spoustim count_themes";
		
		$a->count_themes($total, $count);
		
		say "hotovo, znova je nacitam";
		my $themes = $a->themes;
		
		say "hotovo.";
		MyTimer::start_timing("zapisovani do day_themes hashe");
		
		say "jdu si hrat s day_themes...";
		for (@$themes) {
			if (exists $day_themes{$_->lemma}) {
				my $p;#:shared;
				$p = $day_themes{$_->lemma}->add_1;
				$day_themes{$_->lemma} = $p;
			} else {
				my $p;#:shared;
				
				$p=$_->same_with_1;
				
				$day_themes{$_->lemma} = $p;
				
			}
		}
		
		say "hotovo, ted ma keys ",scalar keys %day_themes, ", jdu pridat do souboru";
		MyTimer::start_timing("add_to_theme_files");
		
		All::add_to_theme_files($themes, $s, $i);
		
		say "hotovo, jdu na dalsi rundu.";
		$i++;
		$$changed = 1;
		return %day_themes;
	}
	);
	MyTimer::start_timing("save_day_themes");
	
	$s->save_day_themes(\%res_day_themes);
	MyTimer::say_all;
}

sub review_all {
	my $d = shift;
	$d->do_for_all(sub{
		my $a = shift;
		my $changed = shift;
		my $has = $a->has_counts;
		if (!$has) {
			$a->counts();
		}
		$$changed = !$has;
	});
}

sub get_count {
	my $s = shift;
	my $num = shift;
	#my %counts:shared;
	#my $i:shared;
	
	my @c = $s->do_for_all(sub{
		
		my $a = shift;
		my $changed = shift;
		my $i = shift;
		my %counts=@_;
		say "i je $i";
		$i++;
		my $wcount = $a->counts;
		for (keys %$wcount) {
			$counts{$_}++;
		}
		$$changed = 0;
		return ($i, %counts);
	}, $num);
	shift @c;
	return @c;
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
