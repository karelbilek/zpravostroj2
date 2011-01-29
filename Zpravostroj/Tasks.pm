package Zpravostroj::Tasks;
#ma zakladni ulohy, co ma zpravostroj umet.

#vsechno by se melo teoreticky volat "pres" Tasks

use 5.008;
use strict;
use warnings;
use Zpravostroj::RSS;
use Zpravostroj::Globals;
use All;

use forks;
use forks::shared;

sub refresh_all_RSS {
	for my $f (<data/RSS/*>) {
		my $RSS = undump_bz2($f);
		$RSS->refresh_urls;
		dump_bz2($f, $RSS);
	}
}

sub get_all_RSS {
	my @links;
	for my $f (<data/RSS/*>) {
		my $RSS = undump_bz2($f);
		push (@links, $RSS->get_article_urls);
		dump_bz2($f, $RSS);
	}
	return @links;
}

sub create_articles_from_URLs {
	my @links = @_;
	
	my $date = new Date();
	for my $link (@links) {
		
		say "tvorim link";
		
		my $a = new Article(url=>$link); #the whole creation happens here
		
		say "ukladam $link";
		
		$date->save_article($a);
	}
}

sub download_articles_count_and_themes {
	
	Zpravostroj::TectoServer::run_tectoserver();
		
	my @links = get_all_RSS;
	
	create_articles_from_URLs(@links);
	
	Zpravostroj::TectoServer::stop_tectoserver(); #so it doesn't mess the memory when I don't really need it
	
	All::set_latest_count(); #looks at the latest count, adds all younger stuff (which means all the new articles, basically)
	
	recount_all_themes(); #goes through ALL the articles - including the new ones - and sets new themes, based on the new counts
	
}

sub recount_all_themes {
	
	my $count = All::get_count();
	
	
	my $total = All::get_total_before_count();
		
	All::do_for_all(sub{
		my $date = shift;
		$date->get_and_save_themes($count, $total);
	},1);
}


sub recount_all_articles {
	$|=1;
	
	Zpravostroj::TectoServer::run_tectoserver();
	
	All::do_for_all(sub{
		my $d = shift;
		$d->review_all();
	}, 1);
	
	Zpravostroj::TectoServer::stop_tectoserver();
}

sub say_all_top_themes {
	my @tt = all_top_themes();
	
	for (@tt) {say $_->lemma}
}


sub all_top_themes {
	
	my %themes : shared;
	
	say "Pred do_for_all";
	All::do_for_all(sub{
		my $d = shift;
		say "Day ", $d->get_to_string();
		
		my @d_themes = $d->get_top_themes(100);
		for my $theme (@d_themes) {
			
			lock(%themes);
			if (exists $themes{$theme->lemma}) {
				$themes{$theme->lemma} = shared_clone($theme->add_another($themes{$theme->lemma}));
			} else {
				$themes{$theme->lemma} = shared_clone($theme);
			}
		}
		
		return ();
	}, 0);
	
	my @r_themes = values %themes;
	
	@r_themes = sort {$b->importance <=> $a->importance} @r_themes;
	
	return @r_themes[0..100];
}

1;