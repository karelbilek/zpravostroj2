package Zpravostroj::DateArticles;
use Zpravostroj::Globals;
use strict;
use warnings;

use List::Util qw(min);
use forks;
use forks::shared;

use Zpravostroj::ThemeHash;
use Zpravostroj::Forker;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

my $THREADS_SIZE=20;

use Date;

has 'date' => (
	is=>'ro',
	required=>1,
	weak_ref => 1,
	isa=>'Date'
);




sub pathname {
	my $s = shift;
	mkdir "data";
	mkdir "data/articles";
	my $year = int($s->date->year);
	my $month = int($s->date->month);
	my $day = int($s->date->day);
	mkdir "data/articles/".$year;
	mkdir "data/articles/".$year."/".$month;	
	mkdir "data/articles/".$year."/".$month."/".$day;
	return "data/articles/".$year."/".$month."/".$day;
}


sub article_names {
	my $s=shift;
	my $ds = $s->pathname;
	my @s = <$ds/*>;
	@s = grep {/\/[0-9]*\.bz2$/} @s;
	return (@s);
}



sub save_article {
	my $s = shift;
	my $n = shift;
	my $article = shift;
	if (defined $article) {
		dump_bz2($n, $article, "Article");
	}
}

sub remove_article {
	my $s = shift;
	my $n = shift;
	
	say "Mazu $n.";
	system ("rm $n");
}


sub load_article {
	my $s = shift;
	my $n = shift;
	
	return undump_bz2($n, "Article");
}


sub get_and_save_themes {
	my $s = shift;
		
	my $count = shift;
	my $total = shift;
	
	my $themhash:shared;
	$themhash = shared_clone(new Zpravostroj::ThemeHash());
	
	my %urls:shared;
	
	$s->do_for_all(sub {
		my $a = shift;
		if (defined $a) {
			{
				lock(%urls);
				if (exists $urls{$a->url}) {
					return (-1);
				}
				
				$urls{$a->url} = 1;
			}
			
			say "----------------------JDU POCITAT THEMES-------";
		
			$a->count_themes($total, $count);
			
			say "----------------------HOTOVO-------";

			
		
			my $themes = $a->themes;
		
				
			for (@$themes) {
				{
					lock($themhash);
					$themhash->add_theme($_, 1);
				}
			}
		
			return(1);
		} else {
			return(0);
		}
	},1
	);	
	return $themhash;
}

sub do_for_all {
	my $s=shift;
	my $subr = shift;
	my $do_thread = shift;
	
	my $start = if_undef(shift,0);
	
	my @art_names = $s->article_names;
		
	my $c = $#art_names;
	
	my $end = if_undef(shift, ($c-1));
	$|=1;
	
	my $forker = new Zpravostroj::Forker(size=>$THREADS_SIZE);
	
	for my $art_name (@art_names[$start..$end]) {
	
		my $subref = sub {
			
			
			
			my $a = $s->load_article($art_name);
			
			
			if (defined $a) {
				my ($art_changed, $res_a) = $subr->($a, $c);
				
				if ($art_changed>=1) {
					if ($art_changed==2) {
						$a = $res_a;
					}
					
					$s->save_article($art_name, $a);
				} elsif ($art_changed==-1) {
					
					$s->remove_article($art_name);
				}
			}
			say $art_name;
		};
		
		if ($do_thread) {
			
			$forker->run($subref);
			
		} else {
			$subref->();
		}
	} 
	$forker->wait();
}

1;


__PACKAGE__->meta->make_immutable;