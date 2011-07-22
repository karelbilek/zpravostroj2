package Zpravostroj::Updater;


use warnings;
use strict;

use Zpravostroj::Globals;
use Zpravostroj::RSS;
use Zpravostroj::InverseDocumentFrequencies;
use Zpravostroj::DateArticles;

use Zpravostroj::TectoServer;

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
	
	my $today = new Zpravostroj::DateArticles(date=>new Zpravostroj::Date());
	my $forker = new Zpravostroj::Forker(size=>$FORKER_SIZES{ARTICLE_CREATION});
	my $i : shared;
	$i = $today->get_last_number;
	$i++;
	for my $link (@links) {
		$forker->run(sub{
			say "tvorim link";
		
			my $a = new Zpravostroj::Article(url=>$link); #the whole creation happens here
		
			say "ukladam $link";
			my $n;
			{
				lock($i);
				$n=$i;
				$i++;
			}
			$today->save_article($today->filename($n),$a);
		});
	}
	$forker->wait();
}

sub download_new_articles {
	my $recount_all_tf_idf_themes = shift;
	
	refresh_all_RSS();
	
	Zpravostroj::TectoServer::run_tectoserver();
	
	my @links = get_all_RSS;
	if (scalar @links==0) {
		die "slinks=0";
	}
	@links = @links[0..1];
	for (@links){say "URL -> $_"}
	
	create_articles_from_URLs(@links);
	
	Zpravostroj::TectoServer::stop_tectoserver();
	
	say "PRED UPDATE ALL";

	Zpravostroj::InverseDocumentFrequencies::update_all();
	
	say "PO UPDATE ALL";
	
	Zpravostroj::AllDates::update_saved_article_names();
	
		say "PO UPDATE update_saved_article_names";
	
	if ($recount_all_tf_idf_themes) {
		Zpravostroj::AllDates::get_statistics_tf_idf_themes();
	}
}

1;