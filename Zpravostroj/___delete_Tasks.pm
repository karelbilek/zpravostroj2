package Zpravostroj::Tasks;
#ma zakladni ulohy, co ma zpravostroj umet.

#vsechno by se melo teoreticky volat "pres" Tasks

#Zpravostroj::Tasks::recount_one_article_themes_without_saving("2010-11-3", 35);
#Zpravostroj::Tasks::recount_one_article_themes_without_saving("2010-5-12", 91);

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



use Zpravostroj::Categorizer::TotallyRetarded;

use Zpravostroj::Categorizer::TotallyRetardedTrained;
use Zpravostroj::Categorizer::Evaluator;

use AI::Categorizer::Learner::NaiveBayes;

use AI::Categorizer::Learner::DecisionTree;
use AI::Categorizer::Learner::SVM;

use Zpravostroj::Categorizer::AICategorizer;
use Zpravostroj::Categorizer::FreqThemes;
use Zpravostroj::Categorizer::StopThemes;
use Zpravostroj::Categorizer::TfIdfThemes;

use forks;
use forks::shared;


sub _recount_usermarks {
	my %themeshash;
	for my $fname (<data/usermarks/*>) {
		open my $f, "<:utf8", $fname;
		for my $fline (<$f>) {
			chomp $fline;
			
			if ($fline) {
				$themeshash{$fline}++;
			}
			
		}
		close $f;
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

sub recount_one_article_themes_without_saving {
	my $datestring = shift;
	my $article = shift;
	
	
	my $wordcount = Zpravostroj::AllWordCounts::get_count();
	my $artcount = $alldates->get_total_article_count_before_last_wordcount();

	
	my $ar = get_article($datestring, $article);
	$ar->count_themes($artcount, $wordcount);
	
	my @t = sort {$b->{importance} <=> $a->{importance}} @{$ar->themes};
	
	for (@t) {
		print '\texttt{';
		print $_->{lemma};
		print '}';
		
		print " & ";
		my $s = sprintf ("%.2f", $_->{importance});
		$s=~s/e-(\d\d)/\\times 10\^{-$1}/;
		print "\$$s\$";
		
		print ' \\\\ \hline';
		print "\n";
	}
}

sub recount_all_themes {
	
	say "==============================get_count===";
	my $wordcount = Zpravostroj::AllWordCounts::get_count();
	
	say "==============================get_total_before_count===";

	my $artcount = $alldates->get_total_article_count_before_last_wordcount();
	
	
	say "==============================get_and_save_themes===";
	
	$alldates->traverse(sub{(shift)->get_and_save_themes_themefiles($wordcount, $artcount)},$FORKER_SIZES{THEMES_DAYS});
	
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


sub review_all {
	$|=1;
	my $wordcount = Zpravostroj::AllWordCounts::get_count();
	my $artcount = $alldates->get_total_article_count_before_last_wordcount();

	
	#Zpravostroj::TectoServer::run_tectoserver();
	
	$alldates->review_all($wordcount, $artcount);
	
	#Zpravostroj::TectoServer::stop_tectoserver();
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


# sub evaluate_on_userdata {
# 	my $classname = shift;
# 	my $fake_classifier = shift;
# 	my @options = @_;
# 	
# 	my @tuples = Zpravostroj::UserTagged::get_tuples(undef, 1);
# 	
# 	
# 	
# 	my @res = Zpravostroj::Categorizer::Evaluator::evaluate($classname, \@tuples, $fake_classifier ? 0 : 10, @options);
# 	
# 	
# 	print (join (" ", map {"& ".sprintf ("%.2f", $_*100)." \\%"} @res));
# 
# #	print '$micro_pi_sum, $micro_ro_sum, microF, $macro_pi_sum, $macro_ro_sum, macroF';
# 	print "\n";
# }

sub try_retarded {
	Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories("Zpravostroj::Categorizer::TotallyRetarded",1, 0, undef, "ODS");
}

sub try_f {
	evaluate_on_userdata("Zpravostroj::Categorizer::FreqThemes",1, 0);
}

sub try_tf_idf {
	evaluate_on_userdata("Zpravostroj::Categorizer::TfIdfThemes", 1, 0, undef, 10);
}


sub try_s {
	evaluate_on_userdata("Zpravostroj::Categorizer::StopThemes",1, 0, undef);
}

sub try_bayes {
	my $all_themes_as_features = shift;
	evaluate_on_userdata("Zpravostroj::Categorizer::AICategorizer", 0, 1, undef, {name=>"AI::Categorizer::Learner::NaiveBayes", all_themes_as_features=>$all_themes_as_features});
}


sub try_svm {
	my $all_themes_as_features = shift;
	evaluate_on_userdata("Zpravostroj::Categorizer::AICategorizer", 0, {name=>"AI::Categorizer::Learner::SVM", all_themes_as_features=>$all_themes_as_features});
}

sub try_dectree {
	my $all_themes_as_features = shift;
	evaluate_on_userdata("Zpravostroj::Categorizer::AICategorizer", 0, {name=>"AI::Categorizer::Learner::DecisionTree", all_themes_as_features=>$all_themes_as_features});
}


sub total_wordcount_dump {
	$alldates->total_wordcount_dump();
}


sub get_top_ten_lemmas_all {
	$alldates->get_top_ten_lemmas_all();
}

sub get_top_lemmas_all {
	$alldates->get_top_lemmas_all();
}

sub get_top_ten_lemmas_stop {
	$alldates->get_top_ten_lemmas_stop();
}

sub print_podils {
	$alldates->print_podils();
}

sub mnozina {
	$alldates->mnozina();
}

sub print_pocty_cochci {
	$alldates->print_pocty_cochci();
}

sub print_dny {
	$alldates->print_dny();
}

sub print_pocty_noviny {
	$alldates->print_pocty_noviny();
}

sub count_and_get_top_tfidf {
	my $wordcount = Zpravostroj::AllWordCounts::get_count();
	my $artcount = $alldates->get_total_article_count_before_last_wordcount();
	
	$alldates->count_and_get_top_tfidf($wordcount, $artcount);
	
}

sub count_and_get_news_source {
	$alldates->count_and_get_news_source();
	
}


sub mydailywtf {
	my $article = get_article("2010-11-3", 35);
	my @r = $article->stop_themes;
	print @r;
	
}

1;
