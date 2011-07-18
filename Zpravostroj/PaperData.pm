package Zpravostroj::PaperData;

use Zpravostroj::AllDates;
use Zpravostroj::Globals;


use warnings;
use strict;


use utf8;

use Text::Unaccent;

binmode STDOUT, ":utf8";

sub print_dates {
	
	mkdir "data/R_data";
	
	open my $days, ">:utf8","data/R_data/all_dates";
	
	my @a = Zpravostroj::AllDates::_get_traversed_array();
	for (@a) {
		/^(....)-(.*)-(.*)/;
		print $days $3.".".$2;
		print $days "\n";
	}
	
	close $days;
	
	open my $days_filter, ">:utf8","data/R_data/filtered_dates__places";
	open my $marks, ">:utf8","data/R_data/filtered_dates__marks";
	
	my $previous_month=0;

	for my $i (0..$#a) {
		my $d = $a[$i];
		
		$d=~/^(....)-(.*)-(.*)/;
		my $month = $2;
		
		if ($month != $previous_month) {
			print $days_filter $i."\n";
			print $marks "\"".$month."\"\n";
			
			
		} 
		
		$previous_month = $month;
	} 
	close $days_filter;
	close $marks;
}

sub _write_any_count_data{
	my $s = new Zpravostroj::AllDates();
	my $where = shift;
	my $subref = shift;
	
	mkdir "data/R_data";

	
	open my $of, ">:utf8", "data/R_data/".$where;

	
	$s->traverse(sub{
		
		my $d = shift;
		
		my $c = $subref->($d);
		
		print $of $c."\n";
	}, 0);
	
	close $of;
}

sub _average_theme_count_on_article {
	my $type=shift;
	
	_write_any_count_data("average_$type", sub{
		
		my $d = shift;
		
		my $filename = "data/daycounters/".$type."_".$d->date->get_to_string();
		
		my $count_themes;

		{
			no warnings 'numeric';
			$count_themes = int(`wc -l $filename`);
		}

		my $count_articles = scalar($d->_get_traversed_array);
		
		return ($count_articles > 0) ? ($count_themes/$count_articles) : 0;
		
	});
}

sub _make_R_graph {
	my $what = shift;
	my $line = shift;
	my $target = shift;
	if (!$target) {$target=$what};
	if (!$line) {
		system("cd R_graphs; R< $what.R --no-save; mv Rplot001.pdf $target.pdf");
	} else {
		system("cd R_graphs; echo '\n$line' | cat $what.R - | R --no-save; mv Rplot001.pdf $target.pdf")
	}
}

sub graph_average_stop_themes_on_article {
	_average_theme_count_on_article("stop");
	_make_R_graph("average_stop");
}

#Ve skutečnosti to v práci nikde nepoužívám
sub graph_average_tf_idf_themes_on_article {
	_average_theme_count_on_article("tf_idf");
	_make_R_graph("average_tf_idf");
}

sub graph_article_count {
	_write_any_count_data("article_count", sub {
		my $d = shift;
		return scalar($d->_get_traversed_array);
	});
	_make_R_graph("article_count");
	
}

sub _R_vec{
	my @what = @_;
	return "c(".(
			join(", ", map {'"'.$_.'"'} @what)
		).")";
}

#"aktualne", "blesk", "bleskove", "ceskenoviny", "financninoviny", "idnes", "ihned", "lidovky"
sub graph_news_source {
	my @news = qw(aktualne
	blesk
	bleskove
	ceskenoviny
	financninoviny
	idnes
	ihned
	lidovky
	);
	my @colors = ("red", "darkorange", "slateblue4", "brown","darkseagreen2","darkslategrey", "black",  "brown1");
	
	my $R_do = "do_graph("._R_vec(@news).", "._R_vec(@colors).")";
	
	for (@news) {
		count_selected_word("news_source", $_, 1);
	}
	_make_R_graph("sources", $R_do);
	
}

sub graph_lemma_count {
	_write_lemma_count();
	_make_R_graph("lemmas", "do_graph()", "lemmas_all");
	_make_R_graph("lemmas", "do_graph(5000)", "lemmas_5000");
}


sub graph_selected_words_from_paper {
	my $what = shift;
	if ($what==1) {
		graph_selected_words("stop_nehoda_premier_raw", "stop", 0, ["premiér","nehoda"], ["blue", "red"],
			25, _R_vec(5,10,15,20,25));
	}
	if ($what==2) {
		graph_selected_words("stop_nehoda_premier_smooth", "stop", 1, ["premiér","nehoda"], ["blue", "red"], 
			15, _R_vec(5,10,15));
	}
	
	if ($what==3) {
		graph_selected_words("stop_nehoda_premier_various_1", "stop", 1, [
		"nehoda", "premiér", "politika", "demokrat"], ["red", "blue","green","black" ], 15, _R_vec(5,10,15));
	}
	
	if ($what==4) {
		graph_selected_words("stop_nehoda_premier_various_2", "stop", 1, [
		"nehoda", "premiér", "modelka"], ["red", "blue","magenta" ], 15, _R_vec(5,10,15));
	}
	if ($what==5) {
		graph_selected_word_diff("premiér");
	}
	
	if ($what==6) {
		graph_selected_words("tf_idf_various", "tf_idf", 1, 
		["ods", "čssd", "demokrat", "volební"], ["red", "blue","green","black" ], 25, _R_vec(5,10,15,20,25));
	}
	
	if ($what==7) {
		graph_selected_words("tf_idf_zoom", "tf_idf", 2, 
		["ods", "čssd", "demokrat", "volební"], ["red", "blue","green","black" ],50 , _R_vec(10,20,30,40,50), 81,151,1, 9,5);
	}
}

sub graph_selected_words {
	
	my $result_name = shift;
	my $type = shift;
	if ($type ne "tf_idf" and $type ne "stop") {
		die "wrong type";
	}
	my $smooth = shift;
	if ($smooth != 1 and $smooth != 0 and $smooth != 2) {
		die "wrong smooth";
	}
	my $words_ref = shift;
	my $colors_ref = shift;
	if (scalar @$words_ref != scalar @$colors_ref) {
		die "wrong lengths";
	}
	
	my $max = shift;#|| ((!$smooth or $type eq "tf_idf") ? 25:15);
	my $lines = shift;# || ((!$smooth or $type eq "tf_idf" ) ?  ,_R_vec(5,10,15,20,25):_R_vec(5,10,15)) ;

	
	my $from = shift || 0;
	my $to=shift || 0;
	
	my $detailed = shift || 0;
		
	my $width = shift || 0; my $widthinfo = $width ? ", width=$width":"";
	my $height = shift || 0; my $heightinfo = $height ? ", height=$height":"";
	
	for my $word (@$words_ref) {
		#count_selected_word($type, $word);
	}
	
	my $R_words = _R_vec(map {unac_string("utf8", $_)} @$words_ref);
	my $R_cols = _R_vec(@$colors_ref);

	my $R_do = "do_all(max_y=".$max.", lines_y=".$lines.", type=\"".$type."\", ".
		"words=".$R_words.", colors=".$R_cols.", smooth=".$smooth.", from = $from, to=$to, detailed_y=$detailed".
		$widthinfo.$heightinfo.")";

	_make_R_graph("any_word",$R_do, $result_name);
	
}

sub graph_selected_word_diff {
	
	my $word = shift;
	
	count_selected_word("tf_idf", $word);
	count_selected_word("stop", $word);
	my $word_unac = unac_string("utf8", $word);
	
	my $R_do = "do_all(word=\"".$word_unac."\")";

	_make_R_graph("any_word_difference",$R_do, "word_difference_".$word_unac);
	
}




sub count_selected_word {

	my $type = shift;
	my $word = shift;
	
	my $without_prefix = shift;
	
	my $prefix = ($without_prefix) ? ("") : ("word_");
	

	my $name = unac_string("utf8", $word);

	_write_any_count_data($prefix.$type."_".$name, sub {
		my $d = shift;
	
		my $filename = "data/daycounters/".$type."_".$d->date->get_to_string();
	
		
	
		open my $ifile, "<:utf8", $filename or die $!;
	
		while (<$ifile>) {
			chomp;
			/^(.*)\t(.*)$/;
			if ($word eq $1) {
				return $2;
			}
		}
		
		return 0;
	
	});
}


sub _total_lemma_sum {
	my $all;
	
	open my $ifile, "<:utf8", "data/allresults/lemmas_counted_sorted_by_frequency";
	while (<$ifile>) {
		chomp;
		/^(.*)\t(.*)$/;
		
		my $count = $2;
		
		$all += $count;
	}
	
	close $ifile;

	return $all;
}

sub _write_lemma_count {
	open my $lemmas_file, ">:utf8", "data/R_data/lemmas";
	open my $counts_file, ">:utf8", "data/R_data/lemma_counts";
	
	#Nejdřív vypočítám celý součet všech lemmat
	
	my $all = _total_lemma_sum();
	
	#A potom píšu už jenom procenta.
	
	open my $ifile, "<:utf8", "data/allresults/lemmas_counted_sorted_by_frequency";
	while (<$ifile>) {
		chomp;
		/^(.*)\t(.*)$/;
		
		my $word = $1;
		my $count = $2;
		if ($word=~/"/) {
			print $lemmas_file "'".$word."'\n";
		} else {
			print $lemmas_file "\"".$word."\"\n";
		}
		print $counts_file (100*$count/$all)."\n";
	}
	close $ifile;
	close $lemmas_file;
	close $counts_file;
}

sub _get_example_articles {
	my $f = Zpravostroj::AllDates::get_from_article_id("2010-5-12-91");
	my $s = Zpravostroj::AllDates::get_from_article_id("2010-11-3-35");

	return ($f, $s);
}

sub example_unlimited_manual_tags {
	for (_get_example_articles()) {
		print "===============\n";
		for ($_->unlimited_manual_tags()) {
			print $_."\n";
		}
	}
}

sub example_text {
	for (_get_example_articles()) {
		print "===============\n";
		print $_->article_contents;
		print "\n";
	}
}

sub example_f_themes {
	for (_get_example_articles()) {
		print "===============\n";
		for ($_->frequency_themes()) {
			print $_->lemma."\t".$_->score."\n";
		}
	}
}

sub example_stop_themes {
	for (_get_example_articles()) {
		print "===============\n";
		for ($_->stop_themes()) {
			print $_->lemma."\t".$_->score."\n";
		}
	}
}


sub _print_first_twenty{
	my $what = shift;
	open my $ifile, "<:utf8", "data/allresults/".$what."_counted_sorted_by_frequency";
	my $i=0;
	while (<$ifile>) {
		if ($i<20) {
			print $_;
			$i++;
		} else {
			last;
		}
	}
	close $ifile;
}

sub most_frequent_f_themes {
	_print_first_twenty("f_themes");
}

sub most_frequent_stop_themes {
	_print_first_twenty("stop");
}

use Zpravostroj::Categorizer::Evaluator;
use Zpravostroj::Categorizer::TotallyRetarded;
use Zpravostroj::Categorizer::FreqThemes;
use Zpravostroj::Categorizer::StopThemes;
use Zpravostroj::Categorizer::TfIdfThemes;
use Zpravostroj::Categorizer::AICategorizer;


use AI::Categorizer::Learner::NaiveBayes;


sub try_trivial {
	Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories("Zpravostroj::Categorizer::TotallyRetarded",1,1, "ODS");
}

sub try_f_themes {
	Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories("Zpravostroj::Categorizer::FreqThemes",1,1 );
}

sub try_stop_themes {
	Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories("Zpravostroj::Categorizer::StopThemes",1, 1);
}

sub try_tf_idf_themes {
	my $first_res = Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories("Zpravostroj::Categorizer::TfIdfThemes",1, 1, 10);
	my $sec_res = Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories("Zpravostroj::Categorizer::TfIdfThemes",1, 1, 20);
	say $first_res;
	say $sec_res;
}

sub try_categorizer {
	Zpravostroj::Categorizer::Evaluator::evaluate_on_manual_categories(
		"Zpravostroj::Categorizer::AICategorizer", 0, 1, 
		{name=>"AI::Categorizer::Learner::NaiveBayes", all_themes_as_features=>1});
	}

1;