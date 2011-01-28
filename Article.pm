package AllDateArticles;
use Zpravostroj::Globals;
use strict;
use warnings;

use List::Util qw(min);
use forks;
use forks::shared;

use Zpravostroj::ThemeHash;
use Zpravostroj::Forker;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

my $THREADS_SIZE=20;

use Date;

has 'date' => (
	is=>'ro',
	required=>1,
	weak_ref => 1,
	isa=>'Date'
);




sub pathname {
	my $s = shift;
	mkdir "data";
	mkdir "data/articles";
	my $year = int($s->date->year);
	my $month = int($s->date->month);
	my $day = int($s->date->day);
	mkdir "data/articles/".$year;
	mkdir "data/articles/".$year."/".$month;	
	mkdir "data/articles/".$year."/".$month."/".$day;
	return "data/articles/".$year."/".$month."/".$day;
}


sub article_names {
	my $s=shift;
	my $ds = $s->pathname;
	my @s = <$ds/*>;
	@s = grep {/\/[0-9]*\.bz2$/} @s;
	return (@s);
}



sub save_article {
	my $s = shift;
	my $n = shift;
	my $article = shift;
	if (defined $article) {
		dump_bz2($n, $article, "Article");
	}
}

sub remove_article {
	my $s = shift;
	my $n = shift;
	
	say "Mazu $n.";
	system ("rm $n");
}


sub load_article {
	my $s = shift;
	my $n = shift;
	
	return undump_bz2($n, "Article");
}


sub get_and_save_themes {
	my $s = shift;
		
	my $count = shift;
	my $total = shift;
	
	my $themhash:shared;
	$themhash = shared_clone(new Zpravostroj::ThemeHash());
	
	my %urls:shared;
	
	$s->do_for_all(sub {
		my $a = shift;
		if (defined $a) {
			{
				lock(%urls);
				if (exists $urls{$a->url}) {
					return (-1);
				}
				
				$urls{$a->url} = 1;
			}
		
			$a->count_themes($total, $count);
			
		
			
		
			my $themes = $a->themes;
		
				
			for (@$themes) {
				{
					lock($themhash);
					$themhash->add_theme($_);
				}
			}
		
			return(1);
		} else {
			return(0);
		}
	},1
	);	
	return $themhash;
}

sub do_for_all {
	my $s=shift;
	my $subr = shift;
	my $do_thread = shift;
	
	my $start = if_undef(shift,0);
	
	my @art_names = $s->article_names;
		
	my $c = $#art_names;
	
	my $end = if_undef(shift, ($c-1));
	$|=1;
	
	my $forker = new Forker(size=>$THREADS_SIZE);
	
	for my $art_name (@art_names[$start..$end]) {
	
		my $subref = sub {
			
			
			
			my $a = $s->load_article($art_name);
			
			
			if (defined $a) {
				my ($art_changed, $res_a) = $subr->($a, $c);
				
				if ($art_changed>=1) {
					if ($art_changed==2) {
						$a = $res_a;
					}
					
					$s->save_article($art_name, $a);
				} elsif ($art_changed==-1) {
					
					$s->remove_article($art_name);
				}
			}
			say $art_name;
		};
		
		if ($do_thread) {
			
			$forker->run($subref);
			
		} else {
			$subref->();
		}
	} 
	$forker->wait();
}

1;


__PACKAGE__->meta->make_immutable;




package Article;
use 5.008;
use strict;
use warnings;

use Moose;
use Zpravostroj::Globals;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Zpravostroj::MooseTypes;
use Zpravostroj::WebReader;
use ReadabilityExtractor;
use Zpravostroj::TectoClient;
use Zpravostroj::Word;

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
	default=>sub{Zpravostroj::WebReader::wread($_[0]->url)}
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
	isa=>'ArrayRef[Zpravostroj::Word]',
	lazy=>1,
	default=>sub{my $t = ($_[0]->title)." ".($_[0]->article_contents); say ("pred tectoclientem"); my $r= [ Zpravostroj::TectoClient::lemmatize($t) ]; say "za tectoclientem";$r}
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



sub count_themes {
	my $s = shift;
	$s->last_themes_count(new Date());
	my $all_count = shift;
	my $count_hashref = shift;
	
	my $document_size = scalar $s->words;
	
	my %importance;
	
	
	#!!!!!!tohle pak smazat, proboha
	$s->clear_counts();
	
	
	my $word_counts = $s->counts;
	
	
	
	#http://en.wikipedia.org/wiki/Tf%E2%80%93idf
	
	
	
	for my $wordgroup (keys %{$word_counts}) {
		
			
			my $d = 1 + ($count_hashref->{$wordgroup}||0);
			if ($wordgroup =~ /\ /) {
				my @a = split(/ /, $wordgroup);
				for my $word (@a) {
					$d += ($count_hashref->{$word}||0)/(4*@a);
				}
			}
			
			
			$importance{$wordgroup} = ($word_counts->{$wordgroup}{counts} / $document_size) * log($all_count / ($d**1.3))if defined $wordgroup;
			
			
	}
	
	
	
	my @sorted = (sort {$importance{$b}<=>$importance{$a}} keys %importance)[0..39];
	
	
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
			delete $importance{$key};
		}
	}
	
	
	
	my @newthemes_keys = (sort {$importance{$b}<=>$importance{$a}} keys %importance);
	if (@newthemes_keys > 20) {
		@newthemes_keys = @newthemes_keys[0..19];
	}
	
	
	my @newthemes=(map {new Theme(form=>$word_counts->{$_}{back}, lemma=>$_, importance=>$importance{$_})} @newthemes_keys);
	$s->themes(\@newthemes);
	return;
	

}

__PACKAGE__->meta->make_immutable;


1;