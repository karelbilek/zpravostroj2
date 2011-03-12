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
use Zpravostroj::Date;

use Zpravostroj::AllThemes;

use Zpravostroj::UserTagged;

use Zpravostroj::Categorizer::TotallyRetarded;
use Zpravostroj::Categorizer::Evaluator;

use forks;
use forks::shared;

sub save_all_top_themes {Zpravostroj::AllThemes::save}

sub top_themes_from_file {return Zpravostroj::AllThemes::get_sorted(@_)}

sub recount_usermarks {
	my %themeshash;
	my %userdone;
	for my $fname (<data/usermarks/*>) {
		open my $f, "<:utf8", $fname;
		for my $fline (<$f>) {
			chomp $fline;
			if ($fline =~ /^PERSON:\d+$/) {
				$userdone{$fline}++;
			} else {
				if ($fline =~ /PERSON/) {
					die $fname;
				}
				if ($fline) {
					$themeshash{$fline}++;
				}
			}
		}
		close $f;
	}
	
	for my $user (keys %userdone) {
		my $fname = "data/user_done/$user";
		`rm -f $fname`;
		open my $f, ">", $fname;
		print $f $userdone{$user};
		close $f;
		`chmod 777 $fname`;
	}
	
	require YAML::XS;
	my $fname = "data/user_allmarks/allmarks.yaml";
	`rm -f $fname`;
	open my $f, ">:utf8", $fname;
	print $f YAML::XS::Dump($fname, \%themeshash);
	close $f;
	`chmod 777 $fname`;
	
}

sub get_article {
	my $daystr = shift;
	my $art = shift;
	my $da = new Zpravostroj::DateArticles(date=>Zpravostroj::Date::get_from_string($daystr));
	
	my $path = $da->filename($art);
	
	return undump_bz2($path);
}

sub get_day {
	my $daystr = shift;
	my $da = new Zpravostroj::DateArticles(date=>Zpravostroj::Date::get_from_string($daystr));
	return $da;
}

sub check_for_lemma_in_themes {
	my $daystr = shift;
	my $find_theme = shift;
	
	my $da = get_day($daystr);
	$da->traverse(sub{
		my $art = shift;
		my $str = shift;
		
		for my $theme (@{$art->themes}) {
			if ($theme->lemma eq $find_theme) {
				say "MAM TO MAM TO - str $str";
			}
		}
		
	}, 20);
}



sub check_for_lemma_in_words {
	my $daystr = shift;
	my $find_theme = shift;
	
	my $da = get_day($daystr);
	$da->traverse(sub{
		my $art = shift;
		my $str = shift;
		
		for my $word (@{$art->words}) {
			if ($word->lemma eq $find_theme) {
				say "MAM TO MAM TO - str $str";
			}
		}
		
	}, 20);
}


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
	
	my $datea = new Zpravostroj::DateArticles(date=>new Zpravostroj::Date());
	my $forker = new Zpravostroj::Forker(size=>$FORKER_SIZES{ARTICLE_CREATION});
	my $i : shared;
	$i = $datea->get_last_number;
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
	@links = @links[0..1];
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

sub cleanup_all_and_count_themes {
	$alldates->cleanup_all();
	Zpravostroj::Tasks::recount_all_themes();
	get_percentages();
}

sub count_themes_say_top {
	say "--------------------------------recount_all_themes---";
	Zpravostroj::Tasks::recount_all_themes();
	say "--------------------------------say_all_top_themes---";
	
	say_all_top_themes();
}


sub just_went_through_all {
	$alldates->traverse(sub{},$FORKER_SIZES{MOOT});
}

sub remove_unusable {
	$alldates->delete_all_unusable();
}

sub get_percentages {
	say "Beru count...";
	my $total  = $alldates->get_total_article_count_before_last_wordcount();
	
	say "Beru themes...";
	my @tt = hundred_top_themes();
	for (@tt) {
		say $_->lemma," - ", ($_->importance / $total), "%";
	}
}

sub recount_all_themes {
	
	say "==============================get_count===";
	my %wordcount = Zpravostroj::AllWordCounts::get_count();
	
	say "==============================get_total_before_count===";

	my $artcount = $alldates->get_total_article_count_before_last_wordcount();
	
	
	say "==============================get_and_save_themes===";
	
	$alldates->traverse(sub{(shift)->get_and_save_themes_themefiles(\%wordcount, $artcount)},$FORKER_SIZES{THEMES_DAYS});
	
}

sub recount_all_themes_since_day {
	
	my $daystr = shift;
	my $d = Zpravostroj::Date::get_from_string($daystr);
	
	
	
	say "==============================get_count===";
	my %wordcount = Zpravostroj::AllWordCounts::get_count();
	
	say "==============================get_total_before_count===";

	my $artcount = $alldates->get_total_article_count_before_last_wordcount();
	
	
	say "==============================get_and_save_themes===";
	
	$alldates->traverse(sub{
		my $da = shift;
		if ($d->is_older_than($da->date)) {
			$da->get_and_save_themes_themefiles(\%wordcount, $artcount)
		}
	},$FORKER_SIZES{THEMES_DAYS});
	
}


sub recount_all_articles {
	$|=1;

	Zpravostroj::TectoServer::run_tectoserver();
	
	$alldates->traverse(sub{(shift)->review_all()}, $FORKER_SIZES{REVIEW_DAYS});
	
	Zpravostroj::TectoServer::stop_tectoserver();
}

sub say_all_top_themes {
	my @tt = hundred_top_themes();
	
	for (@tt) {say $_->lemma}
}


sub hundred_top_themes {
	return $alldates->get_top_themes(100);
}

sub all_top_themes {
	my %w = $alldates->get_all_themes;
	return (\%w);
}

sub get_percentages_from_file {
	say "Beru count...";
	my $total  = $alldates->get_total_article_count_before_last_wordcount();
	
	say "Beru themes...";
	my @tt = top_themes_from_file(100);
	for (@tt) {
		say $_->lemma," - ", ($_->importance / $total), "%";
	}
}

sub remove_banned {
	say ">>>>>>>>>>>>>>run_tectoserver";
	
	Zpravostroj::TectoServer::run_tectoserver();
	
	say ">>>>>>>>>>>>>>remove_banned";
	
	$alldates->traverse(sub{(shift)->remove_banned()},$FORKER_SIZES{REVIEW_DAYS});
	
	say ">>>>>>>>>>>>>>stop_tectoserver";
	
	Zpravostroj::TectoServer::stop_tectoserver();
	
	say ">>>>>>>>>>>>>>set_latest_wordcount";
	
	$alldates->set_latest_wordcount(); 
	
	say ">>>>>>>>>>>>>>recount_all_themes";

	Zpravostroj::Tasks::recount_all_themes();
}

sub get_sum_percentages{
	
	say "Beru count...";
	my $total  = $alldates->get_total_article_count_before_last_wordcount();
	
	say "Beru themes...";
	my @tt = top_themes_from_file(100);
	my %forbidden = map {$_=>undef} qw(procento strana blesk * . inzerce cz);
	
	my $celkem=0;
	my $i;
	for my $t (@tt) {
		if (!exists $forbidden{$t->lemma}) {
			$celkem += ($t->importance / $total);
			$i++;
			say $i.". ". $t->lemma," - ", $celkem;
		}
	}
	
}

sub say_top_themes {
	my @tt = top_themes_from_file(500);
	say map {$_->lemma."\n"} @tt;
}

sub get_random_article {
	my ($a, $name) = $alldates->get_random_article();
	# say $a->url;
	# 
	# say "--text:";
	# say $a->article_contents;
	# 
	# say "--themes:";
	# say map {$_->lemma."\n"} @{$a->themes};
	# 
	# say "--superthemes:";
	# say map {$_->lemma."\n"} Zpravostroj::Categorizer::find_possible_superthemes($a);
	return ($a, $name);
}

sub evaluate_on_userdata {
	my $classname = shift;
	my @options = @_;
	
	my @tuples = Zpravostroj::UserTagged::get_tuples();
	my ($a, $b) = Zpravostroj::Categorizer::Evaluator::evaluate($classname, \@tuples, @options);
	#jedno je asi precision, jedno asi recall, ale nevim, co je co :(
	
	return ($a, $b);
}

sub try_retarded {
	my ($a, $b) = evaluate_on_userdata("Zpravostroj::Categorizer::TotallyRetarded", "ODS");
	print $a."\n".$b."\n";
}

1;