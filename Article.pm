package AllDateArticles;
use Globals;
use strict;
use warnings;

use List::Util qw(min);
use forks;
use forks::shared;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;



use Date;

has 'date' => (
	is=>'ro',
	required=>1,
	weak_ref => 1,
	isa=>'Date'
);

has 'size' => (
	is=>'ro',
	isa=>'Int',
	required=>1
);



sub pathname {
	my $s = shift;
	mkdir "data";
	mkdir "data/new_articles";
	my $year = int($s->date->year);
	my $month = int($s->date->month);
	my $day = int($s->date->day);
	mkdir "data/new_articles/".$year;
	mkdir "data/new_articles/".$year."/".$month;	
	mkdir "data/new_articles/".$year."/".$month."/".$day;
	return "data/new_articles/".$year."/".$month."/".$day;
}

sub filename {
	my $s = shift;
	my $n = shift;
	return ($s->pathname)."/".$n.".bz2";
}

sub real_article_count {
	my $s=shift;
	my $ds = $s->pathname;
	my @s = <$ds/*>;
	return (scalar @s)*($s->size);
}


sub save_articles {
	my $s = shift;
	my $n = shift;
	my $articles = shift;
	if (!$articles->is_all_undef) {
		my $p = $s->filename($n);
		dump_bz2($p, $articles, "ArticleArray");
	}
}

sub load_articles {
	my $s = shift;
	my $n = shift;
	my $p = $s->filename($n);
	
	my $art = (-e $p) ? (undump_bz2($p, "ArticleArray")) : (new ArticleArray($s->size));
	if (!defined $art) {
		$art = new ArticleArray($s->size);
	}
	return $art;
}

sub resave_to_new {
	my $s = shift;
	
	my $i:shared;
	$i=0;
	$s->do_for_all(sub {
		#my $a = shift;
		my $read_a;
		
		my $pokusy=0;
		while (!defined $read_a and $pokusy<20) {
			MyTimer::start_timing("read article v pseudo gst");
			$read_a = $s->date->read_article($i);
			$i++;
			$pokusy++;
		}
		
		return ($read_a, 1);
	
	}, 1, 0, $s->date->article_count);
}

sub get_and_save_themes {
	my $s = shift;
		
	my $count = shift;
	my $total = shift;
	
	MyTimer::start_timing("tvoreni thash");
	my $themhash:shared;
	$themhash = shared_clone(new ThemeHash());
	
	
	$s->do_for_all(sub {
		my $a = shift;
		if (defined $a) {
			MyTimer::start_timing("count themes");
		
			$a->count_themes($total, $count);
		
			MyTimer::start_timing("opetne nacitani");
		
			my $themes = $a->themes;
		
			MyTimer::start_timing("zapisovani do day_themes hashe");
		
			for (@$themes) {
				$themhash->add_theme($_);
			}
		
			return($a, 1);
		} else {
			return($a, 0);
		}
	},1
	);	
	return $themhash;
}

sub do_for_all {
	my $s=shift;
	my $subr = shift;
	my $do_thread = shift;
	my $num = if_undef(shift,0);
	my $c = $s->real_article_count;
	my $endnum = if_undef(shift, ($c-1));
	$|=1;
	
	
	my $currently=$num;
	while ($currently <= $endnum) {
	
		my $subref = sub {
		
			say "Curr $currently";
			MyTimer::start_timing("read article v art DFA");
			my $articles = $s->load_articles($currently);
			
			my $changed = 0;

			for my $i ($currently..min($currently + $s->size-1, $endnum)) {
				MyTimer::start_timing("pred-subr kecy");
				say $i;
				my $a = $articles->article($i - $currently);
				my ($res_a, $art_changed) = $subr->($a, $c);
				
				MyTimer::start_timing("po-subr kecy");
				if (($res_a||"") ne ($a||"")) {
					$articles->article($i - $currently, $res_a);
				}
				$changed = 1 if ($art_changed);
			}
			if ($changed) {
				MyTimer::start_timing("saving articles v art DFA");
				$s->save_articles($currently, $articles);
			}
		};
		
		if ($do_thread) {
			my $thread = threads->new( {'context' => 'list'}, $subref);
		
			$thread->join();	
		} else {
			$subref->();
		}
	} continue {
		$currently += $s->size;
	}
}

1;


__PACKAGE__->meta->make_immutable;


package ArticleArray;
use strict;
use warnings;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage;


has 'size' => (
	is=>'ro',
	isa=>'Int',
	required=>1
);

has 'articles' => (
	is=>'rw',
	isa=>'ArrayRef[Maybe[Article]]',
	required=>1
);

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;
	
	if ( @_ == 1 && !ref $_[0] ) {
		my $size = shift;
		my @arr = (undef) x $size;
	
		return {articles=>\@arr, size=>$size};
	}  else {
		return $class->$orig(@_);
	}
};

sub is_all_undef {
	my $s = shift;
	my $res = 1;
	for (@{$s->articles}) {
		if (defined $_) {
			$res = 0;
		}
	}
	return $res;
}


sub article {
	$|=1;
	
	my $s = shift;
	my $n = shift;
	my $a = shift;
	if ($n < $s->size) {
		if (defined $a) {			
			$s->articles->[$n] = $a;
		}
		return $s->articles->[$n];
	} else {
		die "Too high index!";
	}
}
1;

__PACKAGE__->meta->make_immutable;


package Article;
use 5.008;
use strict;
use warnings;

use Moose;
use Globals;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Types;
use WebReader;
use ReadabilityExtractor;
use Lemmatizer;
use Word;

use Date;

use Theme;

use MooseX::Storage;

with Storage;


has 'url' => (
	is=>'ro',
	required=>1,
	isa=>'URL'
);

has 'html_contents' => (
	is=>'ro',
	lazy => 1,
	default=>sub{read_from_web($_[0]->url)}
);

has 'article_contents' => (
	is=>'ro',
	lazy=>1,
	default=>sub{extract_text($_[0]->html_contents)}
);

has 'title' => (
	is=>'ro',
	lazy=>1,
	default=>sub{extract_title($_[0]->html_contents)}
);

has 'words' => (
	is=>'ro',
	isa=>'ArrayRef[Word]',
	lazy=>1,
	default=>sub{my $t = ($_[0]->title)." ".($_[0]->article_contents); lemmatize($t)}
);

has 'counts' => (
	is=>'ro',
	isa=>'HashRef',
	clearer   => 'clear_counts',
	lazy=>1,
	predicate => 'has_counts',
	default=>sub{
		my $a = shift;

		my %mycounts;

		# my @words = grep {$_->lemma ne ''} @{$a->words};
				
		# for my $word (@words) {
			# my $l = $word->lemma;
			
			# my $prirustek = ($word->named_entity)?2:1;
			# if ($l=~/^[0-9 ]*$/) {
				# $prirustek = 0.33;
			# }
			
			# $mycounts{$l}{counts}+=$prirustek;
			
			# my $f = $word->form;
			
			# $mycounts{$l}{back}=$f;
			
		# }
		my $last;
		my $before_last;
		my @words = grep {$_->lemma ne ''} @{$a->words};
				
		for my $word (@words) {
			my $l = $word->lemma;
			
			my $prirustek = ($word->named_entity)?2:1;
			if ($l=~/^[0-9 ]*$/) {
				$prirustek = 0.33;
			}
			
			$mycounts{$l}{counts}+=$prirustek;
			
			my $f = $word->form;
			
			$mycounts{$l}{back}=$f;
			
			if (defined $last) {
				my $last_l = $last->{word}->lemma;
				
				my $last_p = $last->{prirustek};
				
				$mycounts{$last_l." ".$l}{counts}+=($last_p+$prirustek)/2;
				
				my $last_f = $last->{word}->form;
				
				$mycounts{$last_l." ".$l}{back}=$last_f." ".$f;
				if (defined $before_last) {
					my $b_last_l = $before_last->{word}->lemma;
					
					my $b_last_p = $before_last->{prirustek};
					
					$mycounts{$b_last_l." ".$last_l." ".$l}{counts}+=($b_last_p+$last_p+$prirustek)/3;
					
					my $b_last_f = $before_last->{word}->form;
					
					$mycounts{$b_last_l." ".$last_l." ".$l}{back}=$b_last_f." ".$last_f." ".$f;
				}
			}
			
			$before_last = $last;
			$last = {word=>$word, prirustek=>$prirustek};
		}
		

		return \%mycounts;
	}
);

has 'themes' => (
	is => 'rw',
	isa=> 'ArrayRef[Theme]',
	predicate => 'has_themes'
);

has 'last_themes_count' => (
	is=>'rw',
	isa=>'Date'	
);


sub BUILD {
	my $s = shift;
	$s->counts;
}

sub get_all_subgroups {
	my $w = shift;
	my @all = split(/ /, $w);
	my $s = scalar @all;
	my @res;
	while (@all) {
		my @copy = @all;
		while (@copy) {
			if (scalar @copy!=$s) {
				push @res, join(" ",@copy);
			}
			pop @copy;
		}
		shift @all;
	}	
	return @res;
}

use MyTimer;


sub count_themes {
	my $s = shift;
	$s->last_themes_count(new Date());
	my $all_count = shift;
	my $count_hashref = shift;
	
	my $document_size = scalar $s->words;
	
	my %importance;
	
	MyTimer::start_timing("mazani counts");
	
	
	$s->clear_counts();
	
	MyTimer::start_timing("ziskavani counts");
	
	my $word_counts = $s->counts;
	
	
	
	#http://en.wikipedia.org/wiki/Tf%E2%80%93idf
	
	MyTimer::start_timing("staveni importance");
	
	
	for my $wordgroup (keys %{$word_counts}) {
		
			
			my $d = 1 + ($count_hashref->{$wordgroup}||0);
			if ($wordgroup =~ /\ /) {
				my @a = split(/ /, $wordgroup);
				for my $word (@a) {
					$d += ($count_hashref->{$word}||0)/(4*@a);
				}
			}
			
			
			$importance{$wordgroup} = ($word_counts->{$wordgroup}{counts} / $document_size) * log($all_count / ($d**(1.5)))if defined $wordgroup;
			
			
	}
	
	MyTimer::start_timing("prvni sorteni");
	
	
	my @sorted = (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..39];
	
	MyTimer::start_timing("filtrovani");
	
	for my $lemma (@sorted) {
		if (exists $importance{$lemma}) {
			for my $subgroup (get_all_subgroups($lemma)) {
				delete $importance{$subgroup};
			}
		}
	}
	
	for my $key (keys %importance) {
		if (!exists $word_counts->{$key}{back}) {
			say "Vadny key $key. Mazu.";
			delete $word_counts->{$key}{back};
		}
	}
	
	
	MyTimer::start_timing("navraceni");
	
	my @ll=(map {new Theme(form=>$word_counts->{$_}{back}, lemma=>$_, importance=>$importance{$_})} (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..19]);
	$s->themes(\@ll);
	return;
	
	# for (keys %themes_longer) {
		# if (/pozice a p.*za/) {
			# say "Pozice a poza ma lemma themes longer uz z hashe.";
			# say "a je ", $themes_longer{$_};
			# say "a key je presne ",$_;
		# }
	# }
	
	
	

	# my %to_join;
	# for my $theme_lemma (keys %themes_longer) {
		# if ($theme_lemma =~ /.* ([^ ]*) ([^ ]*)$/) {
			# if (!$themes_longer{$theme_lemma}) {
				# die "Neni dobre $theme_lemma";
			# }			
			# $to_join{$1." ".$2} = $themes_longer{$theme_lemma};
			
		# }
	# }
	
	# my $cont = 1;
	# say "Jdu spojovat.";
	# while ($cont) {
		# $cont = 0;
		# for my $theme_lemma (keys %themes_longer) {
			# if (exists $themes_longer{$theme_lemma} and $theme_lemma =~ /^([^ ]*) ([^ ]*) ([^ ]*)/) {
			#  menim hash -> musim testovat na existenci
			
			
		# themes longer - vede od lemmat k hashi
		# "pozice a poza" se tam doplni
		# to_join ("a poza") je Theme "pozice a poza"
		# tady to chytne "a poza museli"
				# if (exists $to_join{$1." ".$2}) {
				# ...."a poza" existuje, ukazuje na Theme "pozice a poza"
					# if (!exists $themes_longer{$theme_lemma}){
						# next;
					# }
					
					# if (!exists $themes_longer{$to_join{$1." ".$2}->lemma}){
						# next;
					# }
					
					
					
					# my $theme = $themes_longer{$theme_lemma};
					
					
					
					# say "Spojuju ",$to_join{$1." ".$2}->form," a ",$theme->form, ", koef je ", $koef;
					# my $newtheme = $to_join{$1." ".$2}->join($theme);
					# vytvori se novy Theme, "pozice a poza muset"
					 # say "Vysledek je ",$newtheme->form;
					
					# delete $themes_longer{$theme_lemma};
					
					# delete $themes_longer{$to_join{$1." ".$2}->lemma};
					# delete $to_join{$1." ".$2};
					# $to_join{$2." ".$3}=$newtheme;
					# $themes_longer{$newtheme->lemma}=$newtheme;
					
					
					
					# $cont = 1;
				# }
			# }
		# }
	# }
	# my @res=(map {new Theme(form=>$word_counts->{$_}{back}, lemma=>$_, importance=>$importance{$_})} (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..100]);
 # die "dan";
	 # my @sorted = (sort {$themes_longer{$b}->importance <=> $themes_longer{$a}->importance} keys %themes_longer);
	
	# for my $lemma (@sorted) {
		# if (exists $themes_longer{$lemma}) {
			# for my $subgroup (get_all_subgroups($lemma)) {
				# delete $themes_longer{$subgroup};
			# }
		# }
	# }
	
	# my @res = (sort {$b->importance <=> $a->importance} values %themes_longer);

	# $s->themes(\@res);
}

__PACKAGE__->meta->make_immutable;


1;
# 
# package Main;
# 
# my $r = Article->new(url=>"http://www.blesk.cz/clanek/134067/topolanek-dostane-pet-platu-co-s-nim-dal.html");
