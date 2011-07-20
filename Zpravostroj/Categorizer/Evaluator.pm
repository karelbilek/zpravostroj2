package Zpravostroj::Categorizer::Evaluator;
#Evaluátor obecného Categorizeru
#Categorizer si sám tvoří (jelikož stejně nestačí jeden, ane na každý pokus je vytvořen další znovu)


use warnings;
use strict;

use Zpravostroj::Globals;
use Zpravostroj::ManualCategorization::NewsTopics;
use Zpravostroj::ManualCategorization::Unlimited;

use List::Util qw(shuffle);


my $unlimited_tuples_preloaded;
my $limited_tuples_preloaded;

#Přednačte články a načte je do globálních proměnných (aby se to nemuselo dělat pokaždé znovu)
sub preload_articles{
	my $unlimited = shift;
	my $limited = shift;
	
	if ($unlimited and !defined $unlimited_tuples_preloaded) {
		$unlimited_tuples_preloaded = _load_tuples(1);
	}
	
	if ($limited and !defined $limited_tuples_preloaded) {
		$limited_tuples_preloaded = _load_tuples(0);
	}
}

#Načte články, kategorie a provede celou evaluaci
#Pro moje pohodlí vrací tato funkce už TeXovský string s procenty
#(to by se dalo v budoucnu určitě zlepšit)
sub load_manual_categories_and_evaluate {
	my $classname = shift;
	my $weak_evaluation = shift;
	
	my $unlimited_categories = shift;
	my $trial_count = $TRIAL_COUNT;
	
	my @options = @_;
	
	my $tuples = _load_tuples($unlimited_categories);
	
	my @res = _evaluate($classname, $tuples, $weak_evaluation, $trial_count, @options);
	
	my $res_string = join (" ", map {"& ".sprintf ("%.2f", $_*100)." \\%"} @res);
	say $res_string;
	return $res_string;;

}

#Načtu články, které jsou ručně ohodnocené, a k nim potom ono ohodnocení
#(dalo by se zlepšit, že nenačítá celé články, protože to dlouze načítá data z .bz2 souborů, které
#	stejně nepoužívám skoro na nic)

sub _load_tuples {
	my $unlimited_categories = shift;
	if ($unlimited_categories and defined $unlimited_tuples_preloaded) {
		return $unlimited_tuples_preloaded;
	}
	
	if ((!$unlimited_categories) and defined $limited_tuples_preloaded) {
		return $limited_tuples_preloaded;
	}
	
	#jsou tam načtené celé články (tj. objekt Zpravostroj::Article)
	my @articles = $unlimited_categories ? Zpravostroj::ManualCategorization::Unlimited::get_articles : Zpravostroj::ManualCategorization::NewsTopics::get_articles;
	
	my @tuples;
	
	if ($unlimited_categories) {
		
		@tuples = map {my $a=$_;{article=>$a, tags=>[$a->unlimited_manual_tags]}} @articles;
	} else {
		
		@tuples = map {my $a=$_;{article=>$a, tags=>[$a->news_topics_manual_tags]}} @articles;
	}
	return \@tuples;
}

#samotná evaluace
#(samotné počítání ale proběhne v _trial / _untrained_trial)

#weak_evaluation nazývám to, že jednak probíhá jenom jedna evaluace bez jakéhokoliv trénování
#a jednak to, že mi stačí, že Categorizerem zatřízená kategorie je jedno ze slov původní kategorie, abych
#	prohlásil zatřízení za správné

sub _evaluate {
	my ($categorizer_classname, $articles_ref, $weak_evaluation, $trials, @categorizer_options) = @_;
	
	my @articles = @$articles_ref;
	
	say "Velikost articles je ", scalar @articles,".";
	
	my ($macro_F_sum, $micro_F_sum, $macro_pi_sum, $micro_pi_sum, $macro_ro_sum, $micro_ro_sum) = 0 x 6;
	
	if (!$weak_evaluation) {
		my @sets = _choose_disjunct_subsets($trials, @articles);
		for my $trial (0..$trials-1) {
			
			my ($micro_pi, $micro_ro, $micro_F, $macro_pi, $macro_ro, $macro_F) =
					_trial(\@sets, $trial, $categorizer_classname, @categorizer_options);
			
			$micro_pi_sum += $micro_pi / $trials;
			$micro_ro_sum += $micro_ro / $trials;
			$micro_F_sum += $micro_F / $trials;

			$macro_pi_sum += $macro_pi / $trials;
			$macro_ro_sum += $macro_ro / $trials;
			$macro_F_sum += $macro_F / $trials;
				
		}
	} else {
		#na tomto kategorizeru se netrenuje
		
		($micro_pi_sum, $micro_ro_sum,  $micro_F_sum, $macro_pi_sum, $macro_ro_sum, $macro_F_sum) = 
				_untrained_trial($articles_ref, $categorizer_classname, @categorizer_options);
		
	}
	
	return ($micro_ro_sum, $micro_pi_sum, $micro_F_sum, $macro_ro_sum,$macro_pi_sum,  $macro_F_sum);
}

#vybere disjunktní množiny a ještě to rozdělí do množiny/doplňku
#vrací pole hashů, kde v hashi jsou klíče "set" a "complement"
sub _choose_disjunct_subsets{
	my $number_of_subsets = shift;
	my @input_array = @_;

	my $set_size = int((scalar @input_array) / $number_of_subsets);
	
	my @res;

	for my $n (0..$number_of_subsets-1) {
	
		my @set;
		my @complement;
		
		my $set_start = $n * $set_size;
		my $set_end = $set_start + $set_size - 1;
		for my $i (0..$#input_array) {
		
			
			if ($i >= $set_start and $i <= $set_end) {
				push (@set, $input_array[$i]);
			} else {
				push (@complement, $input_array[$i]); 
			}
		}
		push (@res, {set=>\@set, complement => \@complement});
	}
	
	my $are_remains = ((scalar @input_array) % $number_of_subsets) > 0;
	
	#kdyz jsou zbytky
	if ($are_remains) {
		
		my $remains_start = $number_of_subsets*$set_size;
		
		#zbytky rozdeluju tak, ze je davam skoro vsechny do komplementu, jenom v posledni skupine do samotne mnoziny
	
		#pro vsechny krome posledniho strc do komplementu
		for my $n (0.. $number_of_subsets-2) {
			push (@{$res[$n]->{complement}}, @input_array[$remains_start..$#input_array]);
		}
		
		#pro posledni strc do mnoziny
		push (@{$res[$number_of_subsets-1]->{set}}, @input_array[$remains_start..$#input_array]);

	}
	return @res;
}

#pokus, kde nic netrénuji, tj. otaguji množinu a rovnou počítám precision a recall
sub _untrained_trial {
	my $articles = shift;
	
	my $categorizer_classname = shift;
	
	my @categorizer_options = @_;
	
	
	my $categorizer = $categorizer_classname->new(undef, @categorizer_options);
	my @to_tag = map {$_->{article}} @$articles;
	

	my @tagged = $categorizer->categorize(@to_tag);
	
	my @original_tags_only = map {$_->{tags}} @$articles;
	my @categorizer_tags_only = map {$_->{tags}} @tagged;
	
	return _count_precision_recall(\@categorizer_tags_only, \@original_tags_only, 1);
}



#pokus, kde trénuji a počítám precision/recall
#dostanu tedy 2 množiny - trénovací a testovací
#Po otagování spočítám precision a recall
sub _trial {
	my $sets = shift;
	my $trial_number = shift;
	my $categorizer_classname = shift;
	my @categorizer_options = @_;
	
	
	say "DALSI POKUS - CISLO $trial_number";
	
	my @train = @{$sets->[$trial_number]{complement}};
	my @eval = @{$sets->[$trial_number]{set}};

	my $categorizer = $categorizer_classname->new(\@train, @categorizer_options);
	my @to_tag = map {$_->{article}} @eval;
	
	my @tagged = $categorizer->categorize(@to_tag);

	my @original_tags_only = map {$_->{tags}} @eval;
	my @categorizer_tags_only = map {$_->{tags}} @tagged;

	if (scalar @tagged != scalar @eval) {
		die "Tagged and eval doesn't have the same size! :(";
	}
	
	return _count_precision_recall(\@categorizer_tags_only, \@original_tags_only, 0);

}

#Spočítá různé druhy precision a recall
sub _count_precision_recall {
	my ($categorizer_tags_ref, $original_tags_ref, $fake_categorizer) = @_;
	
	my ($TP, $FP, $FN, $category_count) = _count_positives_and_negatives($categorizer_tags_ref, $original_tags_ref, $fake_categorizer);
	
	my $micro_TP = _sum_hash($TP);
	my $micro_FP = _sum_hash($FP);
	my $micro_FN = _sum_hash($FN);	
	
	my $micro_pi = _safe_fraction($micro_TP, $micro_FP);
	my $micro_ro = _safe_fraction($micro_TP, $micro_FN);
	
	my $macro_pi_sum=0;
	my $macro_ro_sum=0;
	
	#teoreticky bych tady mel iterovat pres all_tags_hash, ale nahore by byla stejne vzdycky nula
	for my $tag (keys %$TP) {
		$macro_pi_sum += _safe_fraction($TP->{$tag}, $FP->{$tag}); 
		$macro_ro_sum += _safe_fraction($TP->{$tag}, $FN->{$tag}); 
	}
	
	my $macro_pi = $macro_pi_sum/$category_count;
	my $macro_ro = $macro_ro_sum/$category_count;	
	
	my $micro_F = _count_F($micro_pi, $micro_ro);
	my $macro_F = _count_F($macro_pi, $macro_ro);
	
	return ($micro_pi, $micro_ro, $micro_F, $macro_pi, $macro_ro, $macro_F);
}


#Spočítá true positive, false negative a false positive
sub _count_positives_and_negatives {
	my ($categorizer_tags_ref, $original_tags_ref, $fake_categorizer) = @_;
	
	
	my @all_categorizer_tags = @{$categorizer_tags_ref};
	my @all_original_tags = @{$original_tags_ref};
		
	if (scalar @all_categorizer_tags != scalar @all_original_tags) {
		die "all_categorizer_tags and all_original_tags doesn't have the same size! :(";
	}
	
	my %all_tags_hash;
	my (%TP, %FP, %FN);
	
	for my $i (0..$#all_categorizer_tags) {
		my %categorizer_tags = map {($_=>undef)} @{$all_categorizer_tags[$i]};
		my %original_tags = map {($_=>undef)} @{$all_original_tags[$i]};
		
		for my $categorized (keys %categorizer_tags) {
			
			my $is_tp = _exists_in_categories($fake_categorizer, $categorized, \%original_tags);
			
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
			
			my $is_fn = ! _exists_in_categories($fake_categorizer, $original, \%categorizer_tags);
			
			if ($is_fn) {
				$FN{$original}++;
				say "False negative u $original.";
			}
			
			$all_tags_hash{$original}=undef;
		}
	}
	return (\%TP, \%FP, \%FN, scalar keys %all_tags_hash);
}

#Existuje $category v hashi $hash_of_categories?
#Pokud nejde o "weak evaluation", tak je to jednoduchý exists
#pokud jde, tak musím rozsekat na slova
sub _exists_in_categories {
	my ($break_to_words, $category, $hash_of_categories) = @_;
	
	if ($break_to_words) {
		for my $longer_category (keys %$hash_of_categories) {
			if (_is_one_of_the_words($longer_category, $category)) {
				return 1;
			}
		}
		return 0;
		
	} else {
		return exists $hash_of_categories->{$category};
	}
}

#posčítá elementy v hashi
sub _sum_hash {
	my $r = shift;
	my %w = %$r;
	
	my $res=0;
	for (values %w) {$res+=$_};
	
	return $res;
	
}

#řeší, jestli se v delším stringu objevuje slovo z kratšího stringu
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


#Spočítám F (viz bakalarska prace)
sub _count_F {
	my ($pi, $ro) = @_;
	if ($pi==0 or $ro==0) {
		return 0;
	}
	return (2*$pi*$ro)/($pi + $ro);
}

#Pomocná funkce, co mi spočítá "bezpečně" a/(a+b)
sub _safe_fraction {
	my $a = shift;
	my $b = shift;
	
	$a = $a || 0;
	$b = $b || 0;
	if ($a+$b == 0) {
		return 1; #0/0, rozhodl jsem se, že to bude 1
	}
	return ($a / ($a+$b));
}



1;