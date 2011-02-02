package Article;
use 5.008;
use strict;
use warnings;


use Zpravostroj::DateArticles;
use Zpravostroj::Globals;
use Zpravostroj::MooseTypes;
use Zpravostroj::WebReader;
use Zpravostroj::Readability;
use Zpravostroj::TectoClient;
use Zpravostroj::Word;
use Zpravostroj::Date;

use Zpravostroj::Theme;


use Moose;
use MooseX::StrictConstructor;


use Moose::Util::TypeConstraints;

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
	default=>sub{Zpravostroj::Readability::extract_text($_[0]->html_contents)}
);

has 'title' => (
	is=>'ro',
	lazy=>1,
	default=>sub{Zpravostroj::Readability::extract_title($_[0]->html_contents)}
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
	isa=> 'ArrayRef[Zpravostroj::Theme]',
	predicate => 'has_themes'
);

has 'last_themes_count' => (
	is=>'rw',
	isa=>'Zpravostroj::Date'	
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
	$s->last_themes_count(new Zpravostroj::Date());
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
	
	#tohle je nejaka cypovina
	for my $lemma (@sorted) {
		if (exists $importance{if_undef($lemma)}) {
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
	
	
	my @newthemes=(map {new Zpravostroj::Theme(form=>$word_counts->{$_}{back}, lemma=>$_, importance=>$importance{$_})} @newthemes_keys);
	$s->themes(\@newthemes);
	return;
	

}

__PACKAGE__->meta->make_immutable;


1;