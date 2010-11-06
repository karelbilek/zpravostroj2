package Zpravostroj::Counter;
use 5.008;
use strict;
use warnings;

use Zpravostroj::Other;
use Zpravostroj::Database; #for reading global counts



use base 'Exporter';
our @EXPORT = qw( count_themes);
use utf8;
use List::Util qw(sum);
# use Clone::Fast qw( clone );


	
	#phase, that counts ALL max_length - long strings
sub first_counting_phase {
	my $max_length = shift;
	my $all_counts_ref = shift;
	my @lemmas = @_;
	
	
	my %local_words; #I need every word-group, that appears here, to show up in the result just ONCE
					 #therefore, I need a helping hash
					
	while (@lemmas) {
		my $smaller_i = ($#lemmas < ($max_length-1)) ? ($#lemmas):($max_length-1);
		my @subgroup = @lemmas[0..$smaller_i];
		while (@subgroup) {
			
			$local_words{join (" ", @subgroup)}=undef;
			
			pop @subgroup;
		}
		shift @lemmas;
	}
	
	for (keys %local_words) {
		$all_counts_ref->{$_}++;
			#just once for every lemma/document!
	}
}

sub second_counting_phase {
	my $min_score;
	my $max_length = shift;
	my $number_of_articles = shift;
	
	my $all_counts_ref = shift;
	my $article_ref = shift;
	
	my @all_words = @{$article_ref->{all_words_copy}};
	
	
	
	my %keys_count;
	my %score;
	my %forms;
	
	while (@all_words) {
		my $smaller_i = ($#all_words < ($max_length-1))?($#all_words):($max_length-1);
		
		my @sub_words = @all_words[0..$smaller_i];
		
		
		while (@sub_words) {
			my $forms_joined = join (" ", map {$_->{form}} @sub_words);
			my $lemmas_joined = join (" ", map {$_->{lemma}} @sub_words);
			push (@{$forms{$lemmas_joined}}, $forms_joined);
			$keys_count{$lemmas_joined}++;#=log($number_of_articles / $all_counts_ref->{$lemmas_joined});
			pop @sub_words;
			
			
		}
		
		shift @all_words;
	}
	%score = map {$_ => ((2 - 1/ split_size($_))*($keys_count{$_})*log($number_of_articles / ($all_counts_ref->{$_})))} keys %keys_count;
	
	my $score_sum=sum (values %score);
	
	my @all_lemmas_sorted= (sort {$score{$b}<=>$score{$a}} (keys %score));
	my @res_lemmas;
	
	# verze A - u prvniho s jednickou se zastavim
	push (@res_lemmas, shift @all_lemmas_sorted) while (@all_lemmas_sorted && $keys_count{$all_lemmas_sorted[0]}>1);
	
	# verze B - vezmi vse co je >1
	# @res_lemmas = map {if ($keys_count{$_}>1){$_}else{()}} @all_lemmas_sorted;
	
	my %res_lemmas_hash;
	@res_lemmas_hash{@res_lemmas}=();
	
	my @named = grep {!($_=~/^\s*\d*\s*$/) and exists $keys_count{$_}} @{$article_ref->{all_named}};
	@res_lemmas_hash{@named}=();
	
	for my $lemma (sort {split_size($b) <=> split_size($a)} keys %res_lemmas_hash) {
		for my $sublemma (all_subthemes(" ", $lemma)) {
			delete $res_lemmas_hash{$sublemma};
		}
	}
	
	my @res;
	for my $lemma (sort {$score{$b}<=>$score{$a}} keys %res_lemmas_hash) {
		push (@res, {lemma=>$lemma, best_form=>most_frequent(@{$forms{$lemma}}),all_forms=>\@{$forms{$lemma}}, score=>100*($score{$lemma}/$score_sum), count=>$keys_count{$lemma}, reverse=>($all_counts_ref->{$lemma})});
	}
	
	return \@res;
	
}

sub connect_bottom {
	my $article_ref = shift;
	my $count_bottom_ref = shift;
	
	my @corrected;
	my $pre="";
	for my $word (@{$article_ref->{all_words}}) {
		if (exists $count_bottom_ref->{$word->{lemma}}) {
			$pre.=$word->{form}."_";
		} else {
			push (@corrected, {form => $pre.($word->{form}), lemma => $word->{lemma}});
			$pre="";
		}
	}
	
	$article_ref->{all_words_copy} = \@corrected;
			# I will HAVE to delete this from article hash later!
	
}

sub make_corrections {
	my $article_ref = shift;
	if (!defined $article_ref->{all_words}) {
		my @empty = ();
		$article_ref->{all_words} = \@empty;
	} else {
		for my $length (1..longest_correction) {
			for my $i (0..(scalar @{$article_ref->{all_words}})-$length){
				
				my $joined_form = join (" ", map {$_->{form}} @{$article_ref->{all_words}}[$i..$i+$length-1]);
			
				if (my $correction = get_correction($joined_form)) {
					my @correction_split = split (" ", $correction);
					for my $j (0..$length-1) {
						${$article_ref->{all_words}}[$j+$i]->{lemma}=$correction_split[$j];
					}
				}
			}
		}
	}
}

sub real_score {
	my ($score_ref, $appearances_ref, $all_counts_ref, $number_of_articles, $what, $a, $b, $c, $d) = @_;
	
	# return ;
	my $score = (log(scalar (keys %{$appearances_ref->{$what}})+1)**$a)*(log($number_of_articles/(($all_counts_ref->{$what})))**$c)* (($score_ref->{$what})**$d);
	if ($score != $score) { #only when NaN
		return 0;
	}
	return $score;
	
}

sub count_top_themes {
	my %appearances;
	my %top_theme_scores;
	my %all_forms;
	
	my $all_counts_ref = shift;
	my $pa = shift;
	my $pb = shift;
	my $pc = shift;
	my $pd = shift;
	my @articles = @_;
	
	for my $i (0..$#articles) {
		my $article = $articles[$i];
		
		my @keys;
		@keys = @{$article->{top_keys}} if $article->{top_keys};
		
		for my $key (@keys) {
			my $lemma = $key->{lemma};
			
			$appearances{$lemma}->{$i} = undef;
			$top_theme_scores{$lemma}+=$key->{score};
			push (@{$all_forms{$lemma}}, @{$key->{all_forms}});
		}
	}
	
	my @results;
	for my $lemma (sort {
			real_score(\%top_theme_scores, \%appearances, $all_counts_ref, scalar @articles, $b, $pa, $pb, $pc, $pd) <=> real_score(\%top_theme_scores, \%appearances, $all_counts_ref, scalar @articles, $a, $pa, $pb, $pc, $pd)
		} keys %top_theme_scores) {
			
		my %result;
		$result{lemma} = $lemma;
		my @res_appearances = map {{id=>$_, title=>$articles[$_]->{title}, url=>$articles[$_]->{url}}} keys %{$appearances{$lemma}};
		$result{articles} = \@res_appearances;
		$result{best_form} = most_frequent(@{$all_forms{$lemma}});
		$result{all_forms} = \@{$all_forms{$lemma}};
		$result{score} = real_score(\%top_theme_scores, \%appearances, $all_counts_ref, scalar @articles, $lemma, $pa, $pb, $pc, $pd);
		push (@results, \%result);
	}
	
	
	splice (@results, 250) if @results>250;
	
	return \@results;
}

sub count_themes {
	my_log("Counter", "count_themes entering. I hope we are all well and all on this board. Lock and load!");
	my $pa = shift;
	my $pb = shift;
	my $pc = shift;
	my $pd = shift;
	
	my $art_ref = shift;
	my @articles = @$art_ref;
	
	
	
	my %all_counts;
	
	my_log("Counter", "First make corrections.");
	
	foreach (@articles) {make_corrections($_)};
	
	my_log("Counter", "Then count it for the first time, ignoring the first-step words.");
	
	
	foreach (@articles) {first_counting_phase(1, \%all_counts,map{$_->{lemma}} @{$_->{all_words}})};
	
	my_log("Counter", "Hey yo. Now, connect the bottoms-");
	
	my @counts_bottom = sort {$all_counts{$b} <=> $all_counts{$a}} keys %all_counts;
	splice (@counts_bottom, @counts_bottom/44);
	
	
	
	my %count_bottom_hash;
	@count_bottom_hash{@counts_bottom}=@all_counts{@counts_bottom};
	my %count_bottom_hash_with_db = (%count_bottom_hash, read_db_bottom());
	
	
		
	# foreach (@articles) {$_->{all_words_clone} = clone ($_->{all_words})};
	foreach (@articles) {connect_bottom($_, \%count_bottom_hash_with_db)};
	
	my_log("Counter", "- dan. now for the 2nd time...");
	
	my $max_length=5;#read_option("max_theme_length");
	
	
	# counting IDF AGAIN!!!! with different words!!
	%all_counts=();
	foreach (@articles) {first_counting_phase($max_length, \%all_counts,map{$_->{lemma}} @{$_->{all_words_copy}})};
	
	my_log("Counter", "- dan. now the socalled 2nd phase...");
	
	my %all_counts_with_db=%all_counts;
	{
		my %db_counts = read_db_all_counts();
		for my $key (keys %db_counts) {
			$all_counts_with_db{$key}+=$db_counts{$key};
		}		
	}
	my_log("Counter", "- something someting -");
	
	foreach (@articles) { $_->{top_keys}=second_counting_phase($max_length, scalar @articles, \%all_counts_with_db,$_) };
	
	my_log("Counter", "- done. now count the top_themes...");
	
	foreach (@articles) { delete $_->{all_words_copy} };
	
	my $top_themes = count_top_themes(\%all_counts_with_db, $pa, $pb, $pc, $pd, @articles);
	
	my_log("Counter", "- done. kthxbai.");
	
	return (articles=>\@articles, top_themes=>$top_themes, count_bottom=>\%count_bottom_hash, all_counts=>\%all_counts);
}

1;