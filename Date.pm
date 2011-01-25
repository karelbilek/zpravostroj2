package Date;
 
use 5.008;
use Globals;
use forks;
use forks::shared;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use Time::Local 'timelocal';

use MooseX::Storage;

with Storage;

use Article;
use Globals;
use MyTimer;

my $ARTICLE_CLUSTER_SIZE = 10;


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
	say $path;
	dump_bz2($path, $themes, "ThemeHash");
}

sub get_day_themes {
	my $s = shift;
	my $path = $s->daypath_themes;

	my $themes = undump_bz2($path, "ThemeHash");
	return $themes;
}

sub get_top_themes{
	my $s = shift;
	my $n = shift;
	my $path = $s->daypath_themes;
	
	
	my $themes = undump_bz2($path);
	
	
	my @themes_top = $themes->top_themes($n);
	

	
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




sub save_article {
	my $s = shift;
	my $a = shift;
	my $c = if_undef(shift, $s->article_count());
	
	dump_bz2($s->daypath."/".$c.".bz2", $a);
	
}



sub read_article {
	my $s = shift;
	my $n = shift;
	return undump_bz2($s->daypath."/".$n.".bz2", "Article");
	
}



sub do_for_all {
	my $s=shift;
	my $subr = shift;
	my $do_thread = shift;
	my $num = if_undef(shift,0);
	my $c = $s->article_count;
	my $endnum = if_undef(shift, ($c-1));
	$|=1;
	
	#my @pseudoshared; - puvodni
	my @shared;# - novy
	if ($do_thread) {
		share(@shared);
	}
	
	for ($num..$endnum) {
	
		my $subref = sub {
		
			say "Num $_";
			MyTimer::start_timing("read article v DFA");
			
			my $a = $s->read_article($_);
			
			if (defined $a) {
				my $changed;
				@shared = $subr->($a, \$changed, @shared);
				
				if ($changed) {
					MyTimer::start_timing("save article v DFA");
					$s->save_article($a, $_)
				}
			
			} 
		};
		
		if ($do_thread) {
			my $thread = threads->new( {'context' => 'list'}, $subref);
		
			
			$thread->join();
			
		} else {
			$subref->();
		}
		
	}
	return @shared;
}

sub resave_to_new {
	my $s = shift;
	
	$|=1;
	MyTimer::start_timing("tvoreni ada");
	
	my $datearticles = new AllDateArticles(date=>$s);#, size=>$ARTICLE_CLUSTER_SIZE );
	
	$datearticles->resave_to_new();
} 



sub get_and_save_themes {
	my $s = shift;
	
	$|=1;
	say "Jdu na den ", $s->get_to_string;
	
	my $count = shift;
	my $total = shift;
	
	MyTimer::start_timing("delete_from_theme_files in date.pm");
	
	{
		my $old_day_themes = $s->get_day_themes;
		All::delete_from_theme_files($old_day_themes, $s);
	}
	
	
	MyTimer::start_timing("tvorim ada");
	my $datearticles = new AllDateArticles(date=>$s);#, size=>$ARTICLE_CLUSTER_SIZE);
	
	my $themhash = $datearticles->get_and_save_themes($count, $total);
	
	# MyTimer::start_timing("tvorim themehash");
	# 	my $themhash:shared;
	# 	$themhash = shared_clone(new ThemeHash());
	# 	
	# 	MyTimer::start_timing("pred DFA");
	# 	
	# 	
	# 	$s->do_for_all(sub {
	# 		my $a = shift;
	# 		my $changed = shift;
	# 		
	# 		
	# 		MyTimer::start_timing("count themes");
	# 		
	# 		$a->count_themes($total, $count);
	# 		
	# 		MyTimer::start_timing("opetne nacitani");
	# 		my $themes = $a->themes;
	# 		
	# 		MyTimer::start_timing("zapisovani do day_themes hashe");
	# 		
	# 		for (@$themes) {
	# 			$themhash->add_theme($_);
	# 		}
	# 		
	# 		$$changed = 1;
	# 		
	# 		return();
	# 	},1
	# 	);
	
	
	
	

	MyTimer::start_timing("save day themes");
	$s->save_day_themes($themhash);
	
	MyTimer::start_timing("add_to_theme_files in date.pm");
	
	All::add_to_theme_files($themhash, $s);
	MyTimer::stop_timing();
}

sub review_all {
	my $d = shift;
	$d->do_for_all(sub{
		say "Zacinam review_all.";
		my $a = shift;
		my $changed = shift;
		my $i = shift;
		(defined $i) ? ($i++) : ($i=0);
		my $has = $a->has_counts;
		if (!$has) {
			say "Nema has!";
			$a->counts();
		} else {
			say "Ma has! Opakuju, je to den ", $d->get_to_string, " , cislo ",$i;
		}
		$$changed = !$has;
		return $i;
	},0);
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
		say "i je $i -- inside get_count";
		$i++;
		my $wcount = $a->counts;
		for (keys %$wcount) {
			$counts{$_}++;
		}
		$$changed = 0;
		return ($i, %counts);
	}, 0, $num);
	
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
