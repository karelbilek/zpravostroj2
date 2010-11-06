package BotchedDate;
 
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
	mkdir "ufaldata";
	mkdir "ufaldata/articles";
	my $year = int($s->year);
	my $month = int($s->month);
	my $day = int($s->day);
	mkdir "ufaldata/articles/".$year;
	mkdir "ufaldata/articles/".$year."/".$month;
	mkdir "ufaldata/articles/".$year."/".$month."/".$day;
	return "ufaldata/articles/".$year."/".$month."/".$day;
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


package main;

use 5.010;

use Date;
use Data::Dumper;


for my $yearstring (<ufaldata/articles/*>) {
	$yearstring =~ /\/([^\/]*)$/;
	my $year = $1;
	
	for my $monthstring (<ufaldata/articles/$year/*>) {
		$monthstring =~ /\/([^\/]*)$/;
		my $month = $1;
		for my $daystring (<ufaldata/articles/$year/$month/*>) {
			$daystring =~ /\/([^\/]*)$/;
			my $day = $1;
			
			my $botched_day = new BotchedDate(day=>$day, month=>$month, year=>$year);
			
			say $botched_day->get_to_string;
			my $new_day= new Date(day=>$day, month=>$month, year=>$year);
			
			my $all_changed = 0;
			my $last_changed = -1;
			my $i = -1;
			
			$botched_day -> do_for_all (sub {
				$i++;
				my $a = shift;
				
				my $words = $a->words;
				
				$|=1;
				print ".";

				
				my $changed = 0;
				for my $botched_word (@$words) {
					
					if ($botched_word->lemma =~ /[\-\.,_;\/\\\^\?:\(\)!]/) {
						$changed = 1;
					}
				}
				
				if ($changed) {
					
					my @new_words;
					
					
					for my $botched_word (@$words) {
						my $new_word = new Word(lemma=>$botched_word->lemma, form=>$botched_word->form, named_entity=>$botched_word->named_entity);
						push (@new_words, $new_word);
					}
					
					my $new_article = new Article(url=>$a->url, html_contents=>$a->html_contents, article_contents=>$a->article_contents, title=>$a->title, words=>\@new_words);
				
					$new_day->save_article($new_article);
					
					$all_changed = 1;
					$last_changed = $i;
				} else {
					my $s = $new_day->daypath;
					system ("cp ".($botched_day->daypath)."/".$i.".bz2 ".$s."/".$i.".bz2");
					#$new_day->save_article($a);
				}
				return 0;
			});
			
			say "hotov - changed $all_changed last $last_changed";
			die "HOTOV";
			
		}
	} 
}
# use Data::Dumper;

# my $d = Date->new();
 # my $r = Article->new(url=>"http://aktualne.centrum.cz/domaci/volby/komunalni-volby/clanek.phtml?id=680222");
 # print "CREATION DONE!\n";

# $d->save_article($r);