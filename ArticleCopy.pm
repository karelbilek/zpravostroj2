package ArticleCopy;
use 5.008;

# use Moose;
# use Globals;
# use MooseX::StrictConstructor;
# use Moose::Util::TypeConstraints;
# use Types;
# use WebReader;
 use ReadabilityExtractorCopy;
# use Lemmatizer;
# 
#use Word;
# 
#use DateCopy;
# 
# use Theme;
# 
# use MooseX::Storage;
# 
# with Storage;

# 
# 
# has 'url' => (
# 	is=>'ro',
# 	required=>1,
# 	isa=>'URL'
# );
# 
# has 'html_contents' => (
# 	is=>'ro',
# 	lazy => 1,
# 	default=>sub{read_from_web($_[0]->url)}
# );
# 
# has 'article_contents' => (
# 	is=>'ro',
# 	lazy=>1,
# 	default=>sub{extract_text($_[0]->html_contents)}
# );
# 
# has 'title' => (
# 	is=>'ro',
# 	lazy=>1,
# 	default=>sub{extract_title($_[0]->html_contents)}
# );
# 
# has 'words' => (
# 	is=>'ro',
# 	isa=>'ArrayRef[Word]',
# 	lazy=>1,
# 	default=>sub{my $t = ($_[0]->title)." ".($_[0]->article_contents); lemmatize($t)}
# );
# 
# has 'counts' => (
# 	is=>'ro',
# 	isa=>'HashRef',
# 	clearer   => 'clear_counts',
# 	lazy=>1,
# 	predicate => 'has_counts',
# 	default=>sub{
# 		my $a = shift;
# 
# 		my %mycounts;
# 
# 		# my @words = grep {$_->lemma ne ''} @{$a->words};
# 				
# 		# for my $word (@words) {
# 			# my $l = $word->lemma;
# 			
# 			# my $prirustek = ($word->named_entity)?2:1;
# 			# if ($l=~/^[0-9 ]*$/) {
# 				# $prirustek = 0.33;
# 			# }
# 			
# 			# $mycounts{$l}{counts}+=$prirustek;
# 			
# 			# my $f = $word->form;
# 			
# 			# $mycounts{$l}{back}=$f;
# 			
# 		# }
# 		my $last;
# 		my $before_last;
# 		my @words = grep {$_->lemma ne ''} @{$a->words};
# 				
# 		for my $word (@words) {
# 			my $l = $word->lemma;
# 			
# 			my $prirustek = ($word->named_entity)?2:1;
# 			if ($l=~/^[0-9 ]*$/) {
# 				$prirustek = 0.33;
# 			}
# 			
# 			$mycounts{$l}{counts}+=$prirustek;
# 			
# 			my $f = $word->form;
# 			
# 			$mycounts{$l}{back}=$f;
# 			
# 			if (defined $last) {
# 				my $last_l = $last->{word}->lemma;
# 				
# 				my $last_p = $last->{prirustek};
# 				
# 				$mycounts{$last_l." ".$l}{counts}+=($last_p+$prirustek)/2;
# 				
# 				my $last_f = $last->{word}->form;
# 				
# 				$mycounts{$last_l." ".$l}{back}=$last_f." ".$f;
# 				if (defined $before_last) {
# 					my $b_last_l = $before_last->{word}->lemma;
# 					
# 					my $b_last_p = $before_last->{prirustek};
# 					
# 					$mycounts{$b_last_l." ".$last_l." ".$l}{counts}+=($b_last_p+$last_p+$prirustek)/3;
# 					
# 					my $b_last_f = $before_last->{word}->form;
# 					
# 					$mycounts{$b_last_l." ".$last_l." ".$l}{back}=$b_last_f." ".$last_f." ".$f;
# 				}
# 			}
# 			
# 			$before_last = $last;
# 			$last = {word=>$word, prirustek=>$prirustek};
# 		}
# 		
# 
# 		return \%mycounts;
# 	}
# );
# 
# has 'themes' => (
# 	is => 'rw',
# 	isa=> 'ArrayRef[Theme]',
# 	predicate => 'has_themes'
# );
# 
# has 'last_themes_count' => (
# 	is=>'rw',
# 	isa=>'Date'	
# );
# 
# 
# sub BUILD {
# 	my $s = shift;
# 	$s->counts;
# }
# 
# __PACKAGE__->meta->make_immutable;
# 
# 
# sub get_all_subgroups {
# 	my $w = shift;
# 	my @all = split(/ /, $w);
# 	my $s = scalar @all;
# 	my @res;
# 	while (@all) {
# 		my @copy = @all;
# 		while (@copy) {
# 			if (scalar @copy!=$s) {
# 				push @res, join(" ",@copy);
# 			}
# 			pop @copy;
# 		}
# 		shift @all;
# 	}	
# 	return @res;
# }
# 
# use MyTimer;
# 
# 
# sub count_themes {
# 	my $s = shift;
# 	$s->last_themes_count(new Date());
# 	my $all_count = shift;
# 	my $count_hashref = shift;
# 	
# 	my $document_size = scalar $s->words;
# 	
# 	my %importance;
# 	
# 	MyTimer::start_timing("mazani counts");
# 	
# 	
# 	$s->clear_counts();
# 	
# 	MyTimer::start_timing("ziskavani counts");
# 	
# 	my $word_counts = $s->counts;
# 	
# 	
# 	
# 	
# 	
# 	MyTimer::start_timing("staveni importance");
# 	
# 	
# 	for my $wordgroup (keys %{$word_counts}) {
# 		
# 			
# 			my $d = 1 + ($count_hashref->{$wordgroup}||0);
# 			if ($wordgroup =~ /\ /) {
# 				my @a = split(/ /, $wordgroup);
# 				for my $word (@a) {
# 					$d += ($count_hashref->{$word}||0)/(4*@a);
# 				}
# 			}
# 			
# 			$importance{$wordgroup} = ($word_counts->{$wordgroup}{counts} / $document_size) * log($all_count / $d);
# 			
# 			
# 	}
# 	
# 	MyTimer::start_timing("prvni sorteni");
# 	
# 	
# 	my @sorted = (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..39];
# 	
# 	MyTimer::start_timing("filtrovani");
# 	
# 	for my $lemma (@sorted) {
# 		if (exists $importance{$lemma}) {
# 			for my $subgroup (get_all_subgroups($lemma)) {
# 				delete $importance{$subgroup};
# 			}
# 		}
# 	}
# 	
# 	for my $key (keys %importance) {
# 		if (!exists $word_counts->{$key}{back}) {
# 			say "Vadny key $key. Mazu.";
# 			delete $word_counts->{$key}{back};
# 		}
# 	}
# 	
# 	
# 	MyTimer::start_timing("navraceni");
# 	
# 	my @ll=(map {new Theme(form=>$word_counts->{$_}{back}, lemma=>$_, importance=>$importance{$_})} (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..19]);
# 	$s->themes(\@ll);
# 	return;
# 	
# 	# for (keys %themes_longer) {
# 		# if (/pozice a p.*za/) {
# 			# say "Pozice a poza ma lemma themes longer uz z hashe.";
# 			# say "a je ", $themes_longer{$_};
# 			# say "a key je presne ",$_;
# 		# }
# 	# }
# 	
# 	
# 	
# 
# 	# my %to_join;
# 	# for my $theme_lemma (keys %themes_longer) {
# 		# if ($theme_lemma =~ /.* ([^ ]*) ([^ ]*)$/) {
# 			# if (!$themes_longer{$theme_lemma}) {
# 				# die "Neni dobre $theme_lemma";
# 			# }			
# 			# $to_join{$1." ".$2} = $themes_longer{$theme_lemma};
# 			
# 		# }
# 	# }
# 	
# 	# my $cont = 1;
# 	# say "Jdu spojovat.";
# 	# while ($cont) {
# 		# $cont = 0;
# 		# for my $theme_lemma (keys %themes_longer) {
# 			# if (exists $themes_longer{$theme_lemma} and $theme_lemma =~ /^([^ ]*) ([^ ]*) ([^ ]*)/) {
# 			#  menim hash -> musim testovat na existenci
# 			
# 			
# 		# themes longer - vede od lemmat k hashi
# 		# "pozice a poza" se tam doplni
# 		# to_join ("a poza") je Theme "pozice a poza"
# 		# tady to chytne "a poza museli"
# 				# if (exists $to_join{$1." ".$2}) {
# 				# ...."a poza" existuje, ukazuje na Theme "pozice a poza"
# 					# if (!exists $themes_longer{$theme_lemma}){
# 						# next;
# 					# }
# 					
# 					# if (!exists $themes_longer{$to_join{$1." ".$2}->lemma}){
# 						# next;
# 					# }
# 					
# 					
# 					
# 					# my $theme = $themes_longer{$theme_lemma};
# 					
# 					
# 					
# 					# say "Spojuju ",$to_join{$1." ".$2}->form," a ",$theme->form, ", koef je ", $koef;
# 					# my $newtheme = $to_join{$1." ".$2}->join($theme);
# 					# vytvori se novy Theme, "pozice a poza muset"
# 					 # say "Vysledek je ",$newtheme->form;
# 					
# 					# delete $themes_longer{$theme_lemma};
# 					
# 					# delete $themes_longer{$to_join{$1." ".$2}->lemma};
# 					# delete $to_join{$1." ".$2};
# 					# $to_join{$2." ".$3}=$newtheme;
# 					# $themes_longer{$newtheme->lemma}=$newtheme;
# 					
# 					
# 					
# 					# $cont = 1;
# 				# }
# 			# }
# 		# }
# 	# }
# 	# my @res=(map {new Theme(form=>$word_counts->{$_}{back}, lemma=>$_, importance=>$importance{$_})} (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..100]);
#  # die "dan";
# 	 # my @sorted = (sort {$themes_longer{$b}->importance <=> $themes_longer{$a}->importance} keys %themes_longer);
# 	
# 	# for my $lemma (@sorted) {
# 		# if (exists $themes_longer{$lemma}) {
# 			# for my $subgroup (get_all_subgroups($lemma)) {
# 				# delete $themes_longer{$subgroup};
# 			# }
# 		# }
# 	# }
# 	
# 	# my @res = (sort {$b->importance <=> $a->importance} values %themes_longer);
# 
# 	# $s->themes(\@res);
# }
# 


1;
# 
# package Main;
# 
# my $r = Article->new(url=>"http://www.blesk.cz/clanek/134067/topolanek-dostane-pet-platu-co-s-nim-dal.html");
