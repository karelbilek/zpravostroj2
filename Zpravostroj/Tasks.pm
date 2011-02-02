package Zpravostroj::Tasks;
#ma zakladni ulohy, co ma zpravostroj umet.

#vsechno by se melo teoreticky volat "pres" Tasks

use 5.008;
use strict;
use warnings;
use Zpravostroj::RSS;
use Zpravostroj::Globals;
use Zpravostroj::AllDates;
use Zpravostroj::DateArticles;
use Zpravostroj::TectoServer;
use Zpravostroj::Forker;
use Zpravostroj::AllWordCounts;

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
		push (@links, $RSS->get_urls);
		dump_bz2($f, $RSS);
	}
	return @links;
}

sub create_articles_from_URLs {
	my @links = @_;
	
	my $datea = new Zpravostroj::DateArticles(date=>new Date());
	my $forker = new Zpravostroj::Forker(size=>$FORKER_SIZES{ARTICLE_CREATION});
	my $i : shared;
	$i = $datea->get_last_number;
	$i++;
	for my $link (@links) {
		$forker->run(sub{
			say "tvorim link";
		
			my $a = new Article(url=>$link); #the whole creation happens here
		
			say "ukladam $link";
			my $n;
			{
				lock($i);
				$n=$i;
				$i++;
			}
			$datea->save_article($datea->filename($n),$a);
		});
	}
	$forker->wait();
}

my $alldates=new Zpravostroj::AllDates;
sub download_articles_counts_and_themes {
	refresh_all_RSS();
	
	
	say ">>>>>>>>>>>>>>RUN TEcTOSERVER";
	Zpravostroj::TectoServer::run_tectoserver();
		
	say ">>>>>>>>>>>>>>GET ALL RSS";

	my @links = get_all_RSS;
	for (@links){say "URL -> $_"}
	
	say ">>>>>>>>>>>>>>CREATE ARTICLES FROM URLS";

	
	#mění data/articles
	create_articles_from_URLs(@links);

	say ">>>>>>>>>>>>>>STOP TECTOSERVER";

	
	Zpravostroj::TectoServer::stop_tectoserver(); #so it doesn't mess the memory when I don't really need it
	
	say ">>>>>>>>>>>>>>SET LATEST WORDCOUNT";
	
	$alldates->set_latest_wordcount(); #looks at the latest count, adds all younger stuff (which means all the new articles, basically)
	#mění word_counts
	
	say ">>>>>>>>>>>>>>RECOUNT ALL THEMES";

	Zpravostroj::Tasks::recount_all_themes(); #goes through ALL the articles - including the new ones - and sets new themes, based on the new counts
	#mění - znova themes ve VŠECH articles
	
}

sub just_went_through_all {
	$alldates->traverse(sub{},$FORKER_SIZES{MOOT});
}

sub remove_unusable {
	$alldates->delete_all_unusable();
}

sub recount_all_themes {
	
	say "==============================get_count===";
	my %wordcount = Zpravostroj::AllWordCounts::get_count();
	
	say "==============================get_total_before_count===";

	my $artcount = $alldates->get_total_article_count_before_last_wordcount();
	
	
	say "==============================get_and_save_themes===";
	
	$alldates->traverse(sub{(shift)->get_and_save_themes_themefiles(\%wordcount, $artcount)},$FORKER_SIZES{THEMES_DAYS});
	
	
}


sub recount_all_articles {
	$|=1;

	Zpravostroj::TectoServer::run_tectoserver();
	
	$alldates->traverse(sub{(shift)->review_all()}, $FORKER_SIZES{REVIEW_DAYS});
	
	Zpravostroj::TectoServer::stop_tectoserver();
}

sub say_all_top_themes {
	my @tt = all_top_themes();
	
	for (@tt) {say $_->lemma}
}


sub all_top_themes {
	return $alldates->get_top_themes;
}

1;