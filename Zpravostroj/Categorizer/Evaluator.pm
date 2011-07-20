package Zpravostroj::Categorizer::Evaluator;

use warnings;
use strict;

use Zpravostroj::Globals;
use Zpravostroj::ManualCategorization::NewsTopics;
use Zpravostroj::ManualCategorization::Unlimited;

use List::Util qw(shuffle);


my $unlimited_tuples_preloaded;
my $limited_tuples_preloaded;
sub preload_articles{
	my $unlimited = shift;
	my $limited = shift;
	
	if ($unlimited and !defined $unlimited_tuples_preloaded) {
		$unlimited_tuples_preloaded = _load_tuples(1);
	}
	
	if ($limited and !defined $limited_tuples_preloaded) {
		$unlimited_tuples_preloaded = _load_tuples(0);
	}
}

sub _load_tuples {
	my $unlimited_categories = shift;
	if ($unlimited_categories and defined $unlimited_tuples_preloaded) {
		return $unlimited_tuples_preloaded;
	}
	
	if ((!$unlimited_categories) and defined $limited_tuples_preloaded) {
		return $limited_tuples_preloaded;
	}
	
	
	my @articles = $unlimited_categories ? Zpravostroj::ManualCategorization::Unlimited::get_articles : Zpravostroj::ManualCategorization::NewsTopics::get_articles;
	
	my @tuples;
	
	if ($unlimited_categories) {
		
		@tuples = map {my $a=$_;{article=>$a, tags=>[$a->unlimited_manual_tags]}} @articles;
	} else {
		
		@tuples = map {my $a=$_;{article=>$a, tags=>[$a->news_topics_manual_tags]}} @articles;
	}
	return \@tuples;

}

sub evaluate_on_manual_categories {
	my $classname = shift;
	my $weak_evaluation = shift;
	
	my $unlimited_categories = shift;
	my $trial_count = $TRIAL_COUNT;
	
	my @options = @_;
	
	my $tuples = _load_tuples($unlimited_categories);
	
	my @res = evaluate($classname, $tuples, $weak_evaluation, $trial_count, @options);
	
	my $res_string = join (" ", map {"& ".sprintf ("%.2f", $_*100)." \\%"} @res);
	say $res_string;
	return $res_string;;

}

sub choose_k_disjunct_subsets{
	my $number = shift;
	my @arr = @_;
	
	
	#@arr = shuffle(@arr);

	my $size = int((scalar @arr) / $number);
	
	my @res;
	

	for my $n (0..$number-1) {
	
		say "Ukazkova prvni skupina." if ($n==9);
		my @set;
		my @complement;
		
		
		my $zac = $n * $size;
		my $kon = $zac + $size- 1;
		for my $i (0..$#arr) {
		
			
			
			say "Clanek $i je ".($arr[$i]->{article}->title) if ($n==9);
			
		
			if ($i >= $zac and $i <= $kon) {
				say "...a je v setu" if ($n==9);
				push (@set, $arr[$i]);
			} else {
								say "...a je v complementu" if ($n==9);
				push (@complement, $arr[$i]); 
			}
		}
		push (@res, [\@set, \@complement]);
	}
	
	#kdyz jsou zbytky
	if ((scalar @arr)%$number) {
		
		
		#zbytky rozdeluju tak, ze je davam skoro vsechny do komplementu, jenom v posledni skupine do samotne mnoziny
	
		#pro vsechny krome posledniho strc do komplementu
		for my $n (0.. $number-2) {
					#komplement n-teho      #ty zbytky
			push (@{$res[$n]->[1]},        @arr[$number*$size..$#arr]);
		}
		
		#pro posledni strc do mnoziny
		push (@{$res[$number-1]->[0]}, @arr[$number*$size..$#arr]);

	}
	return @res;
}

sub _sum_hash {
	my %w = @_;
	
	my $res=0;
	for (values %w) {$res+=$_};
	
	return $res;
	
}

sub _is_one_of_the_words {
	my $longer = shift;
	my $shorter = shift;
	
	my %longer_words = map {(lc($_) => undef)} split(/ /, $longer);
	if (exists $longer_words{lc($shorter)}) {
		return 1;
	} else {
		return 0;
	}
}

sub count_precision_recall {
	my $categorizer_tags_ref = shift;
	my $original_tags_ref = shift;
	
	my $articles_ref = shift;
	
	my $fake_categorizer=shift;
	
	my @all_categorizer_tags = @{$categorizer_tags_ref};
	my @all_original_tags = @{$original_tags_ref};
	
	if (scalar @all_categorizer_tags != scalar @all_original_tags) {
		die "all_categorizer_tags and all_original_tags doesn't have the same size! :(";
	}
	
	my %all_tags_hash;	
	
	my %TP;
	my %FP;
	my %FN;
	
	for my $i (0..$#all_categorizer_tags) {
		my %categorizer_tags = map {($_=>undef)} @{$all_categorizer_tags[$i]};
		my %original_tags = map {($_=>undef)} @{$all_original_tags[$i]};
		
		
		
		say $articles_ref->[$i]->title;
		
		for my $categorized (keys %categorizer_tags) {
			my $is_tp;
			if ($fake_categorizer) {
				$is_tp=0;
				for my $orig (keys %original_tags) {
					if (_is_one_of_the_words($orig, $categorized)) {$is_tp=1}
				}
				
			} else {
				$is_tp = exists $original_tags{$categorized};
			}
			if ($is_tp) {
				$TP{$categorized} ++;
				say "True positive u $categorized.";
			} else {
				$FP{$categorized} ++;
				say "False positive u $categorized.";
			}
			
			$all_tags_hash{$categorized}=undef;
		}
		for my $original (keys %original_tags) {
			
			my $is_fn;
			if ($fake_categorizer) {
				$is_fn=1;
				
				for my $cat (keys %categorizer_tags) {
					if (_is_one_of_the_words($original, $cat)) {$is_fn=0}
				}
				
			} else {
				$is_fn = !exists $categorizer_tags{$original};
			}
			
			if ($is_fn) {
				$FN{$original}++;
				say "False negative u $original.";
			}
			
			$all_tags_hash{$original}=undef;
		}
	}
	
	my $micro_TP = _sum_hash(%TP);
	my $micro_FP = _sum_hash(%FP);
	my $micro_FN = _sum_hash(%FN);	
	
	my $micro_pi = (($micro_TP + $micro_FP)>0) ? (($micro_TP||0)/($micro_TP + $micro_FP)) : (1);
	
	say "Vypocitavam micro pi.";
	say "micro_TP je $micro_TP";
	say "micro_FP je $micro_FP";
	say "micro_pi je $micro_pi";
	
	my $micro_ro = ($micro_TP||0)/($micro_TP + $micro_FN);

	say "Vypocitavam micro ro.";
	say "micro_TP je $micro_TP";
	say "micro_FP je $micro_FN";
	say "micro_pi je $micro_ro";
	
	my $macro_pi_sum=0;
	my $macro_ro_sum=0;
	
	#teoreticky bych tady mel iterovat pres all_tags_hash, ale nahore by byla stejne vzdycky nula
	for my $tag (keys %TP) {
		$macro_pi_sum +=( ($TP{$tag} + ($FP{$tag}||0)) > 0) ? ($TP{$tag}/($TP{$tag} + ($FP{$tag}||0))) : (1);
		$macro_ro_sum += $TP{$tag}/($TP{$tag} + ($FN{$tag}||0));

	}
	
	my $macro_pi = $macro_pi_sum/(scalar keys %all_tags_hash);
	
	
	my $macro_ro = $macro_ro_sum/(scalar keys %all_tags_hash);	
	
	
	
	my $micro_F =0;
	if ($micro_pi!=0 and $micro_ro!=0) {
	
		$micro_F= (2*$micro_pi*$micro_ro)/($micro_pi + $micro_ro);
	}
	
	my $macro_F=0;
	if ($macro_pi!=0 and $macro_ro!=0) {
		$macro_F = (2*$macro_pi*$macro_ro)/($macro_pi + $macro_ro);
	} 
	
	
	return ($micro_pi, $micro_ro, $micro_F, $macro_pi, $macro_ro, $macro_F);
}


sub evaluate {
	my $class = shift;
		
	my $articles_ref = shift;
	

	
	my $weak_evaluation = shift;
	
	my $trials = shift;
	
	my @options = @_;
	
	my @arr = @$articles_ref;
	
	say "Velikost arr je ", scalar @arr,".";
	
	
	my $macro_F_sum=0;
	my $micro_F_sum=0;
	my $macro_pi_sum=0;
	my $micro_pi_sum=0;
	my $macro_ro_sum=0;
	my $micro_ro_sum=0;
	
	if (!$weak_evaluation) {
		my @sets = choose_k_disjunct_subsets($trials, @arr);
		for my $trial (0..$trials-1) {
			say "DALSI POKUS - CISLO $trial";
			my @train = @{$sets[$trial][1]};
			my @eval = @{$sets[$trial][0]};
		
			my $categorizer = $class->new(\@train, @options);
			my @to_tag = map {$_->{article}} @eval;
			
			
			my @tagged = $categorizer->categorize(@to_tag);
		
			my @original_tags_only = map {$_->{tags}} @eval;
			my @categorizer_tags_only = map {$_->{tags}} @tagged;
		
			if (scalar @tagged != scalar @eval) {
				die "Tagged and eval doesn't have the same size! :(";
			}
			
		
		
			my @prec_recall = count_precision_recall(\@categorizer_tags_only, \@original_tags_only, \@to_tag, 0);
		
			my ($micro_pi, $micro_ro, $micro_F, $macro_pi, $macro_ro, $macro_F) = @prec_recall;
		
		
			$micro_pi_sum+=$micro_pi;
			$micro_ro_sum+=$micro_ro;
			$micro_F_sum+=$micro_F;
			
			$macro_pi_sum+=$macro_pi;
			$macro_ro_sum += $macro_ro;
			$macro_F_sum+=$macro_F;
		
		
		
		}
		for ($micro_pi_sum, $micro_ro_sum, $micro_F_sum, $macro_pi_sum, $macro_ro_sum, $macro_F_sum) {$_=$_/$trials}
	} else {
		#na tomto kategorizeru se netrenuje
		my $categorizer = $class->new(undef, @options);
		my @to_tag = map {$_->{article}} @arr;
		

		my @tagged = $categorizer->categorize(@to_tag);
		
		my @original_tags_only = map {$_->{tags}} @arr;
		my @categorizer_tags_only = map {$_->{tags}} @tagged;
		
		my @prec_recall = count_precision_recall(\@categorizer_tags_only, \@original_tags_only, \@to_tag, 1);
		
		($micro_pi_sum, $micro_ro_sum,  $micro_F_sum, $macro_pi_sum, $macro_ro_sum, $macro_F_sum) = @prec_recall;
		
	}
	


	
	return ($micro_ro_sum, $micro_pi_sum, $micro_F_sum, $macro_ro_sum,$macro_pi_sum,  $macro_F_sum);
}

1;