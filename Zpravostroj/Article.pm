#Objekt, co představuje článek sám o sobě.
#Přímo v něm jsou uložené věci, jako url, počty slov a tf-idf témata

#velká část věcí se "sama" tahá pomocí Moose pomocí default
package Zpravostroj::Article;
use 5.008;
use strict;
use warnings;
use utf8;

use Zpravostroj::Globals;
use Zpravostroj::MooseTypes;
use Zpravostroj::WebReader;
use Zpravostroj::Readability;
use Zpravostroj::TectoClient;
use Zpravostroj::Word;
use Zpravostroj::Date;

use Zpravostroj::ManualCategorization::Unlimited;
use Zpravostroj::ManualCategorization::NewsTopics;


use Moose;
use MooseX::StrictConstructor;


use Moose::Util::TypeConstraints;

use MooseX::Storage;

with Storage;


#url
has 'url' => (
	is=>'ro',
	required=>1,
	isa=>'URL'
);

#html kód, neupravený
has 'html_contents' => (
	is=>'ro',
	lazy => 1,
	default=>sub{Zpravostroj::WebReader::wread($_[0]->url)}
);

#vytažený obsah článku pomocí Readability
has 'article_contents' => (
	is=>'ro',
	clearer   => 'clear_article_contents',
	lazy=>1,
	default=>sub{Zpravostroj::Readability::extract_text($_[0]->html_contents)}
);

#Vytažený titulek
has 'title' => (
	is=>'ro',
	lazy=>1,
	default=>sub{Zpravostroj::Readability::extract_title($_[0]->html_contents)}
);


#Jednotlivá slova
has 'words' => (
	is=>'rw',
	clearer   => 'clear_words',
	isa=>'ArrayRef[Zpravostroj::Word]',
	lazy=>1,
	default=>sub{my $t = ($_[0]->title)." ".($_[0]->article_contents); my $r = [ Zpravostroj::TectoClient::lemmatize($t) ]; $r}
);

#Datum (to se ale neukládá do souboru, když to serializuju, viz DateArticles.pm)
has 'date' => (
	is=>'rw',
	clearer => 'clear_date',
	isa=>'Zpravostroj::Date'
);

#Číslo článku (totéž, co výše)
has 'article_number' => (
	is=>'rw',
	clearer => 'clear_article_number',
	isa=>'Int'
);

#počty jednotlicých slov
has 'counts' => (
	is=>'ro',
	isa=>'HashRef[Zpravostroj::Word]',
	clearer => 'clear_counts',
	lazy => 1,
	predicate => 'has_counts',
	default=>sub{
		my $s = shift;

		my %this_counts;

		my @words = grep {$_->lemma ne ''} @{$s->words};
				
		for my $word (@words) {
			my $lemma = $word->lemma;
			
			my $prirustek = ($word->named_entity)?2:1;
			if ($lemma=~/^[0-9 ]*$/) {
				$prirustek = 0.33;
			}
			
			if (exists $this_counts{$lemma}) {
				$this_counts{$lemma}->add_score($prirustek);
			} else {
				$this_counts{$lemma}=$word->copy_with_score($prirustek);
			}
		}
		return \%this_counts;
	}
);

#tf_idf témata
has 'tf_idf_themes' => (
	is => 'rw',
	isa=> 'ArrayRef[Zpravostroj::Word]',
	predicate => 'has_tf_idf_themes'
);

#Zjistím zpravodajský zdroj z URL pomocí regexpů

#řeším extra centrum, protože většina webů z centra má adresu stylu www.aktualne.centrum.cz a já nechci centrum.cz
sub news_source {
	my $s = shift;
	my $u = $s->url;
	
	$u = lc($u);
	
	if ($u !~ /^http:\/\/([^\.]*)\.?([^\.]*)\.cz/) {
		
		$u =~ /^http:\/\/([^\.]*)\.[^\.]*\.([^\.]*)\.cz/;
		if ($2 ne "centrum") {
			say "Podezrele - $u";
		}
		
		return $1;
				
	} else {
		say "1 je $1, 2 je $2";
		
		if ($2 ne "centrum") {
			return $2;
		} else {
			return $1;
		}
	}
}

#Zjistím to, čemu v bakalářské práci říkám "frekvenční témata"
sub frequency_themes {
	my $s = shift;
	my $c = $s->counts;
	my @res = sort {$c->{$b}->score() <=> $c->{$a}->score()} keys %$c;
	
	my $max = $FREQUENCY_THEMES_SIZE; 
	

	if (scalar @res > $max) {
		@res = @res[0..$max-1];
	}

	return @{$c}{@res};
}


#stop-slova
my %most_frequent_lemmas = Zpravostroj::Globals::most_frequent_lemmas;

#stop-témata (viz BP)
sub stop_themes {
	my $s = shift;
	my $c = $s->counts;
	
	my @without_stopwords = grep {!(exists $most_frequent_lemmas{$_})} keys %$c;
	
	my @res = sort {$c->{$b}->score() <=> $c->{$a}->score()} @without_stopwords;
	
	my $max = $STOP_THEMES_SIZE; 
	
	if (scalar @res > $max) {
		@res = @res[0..$max-1];
	}
	
	return @{$c}{@res};

}



sub BUILD {
	my $s = shift;
	$s->counts; #donutím, aby se kaskádovitě spustilo budování těch default parametrů
}

#spočítá a uloží tf-idf témata
sub count_tf_idf_themes {
	my $s = shift;
	my $idf = shift;
	my $article_count = shift;
	
	my $themes = $s->tf_idf($idf, $article_count, $TF_IDF_THEMES_SIZE);
	$s->tf_idf_themes($themes);
}

#spočítá VŠECHNA tf-idf témata
sub tf_idf {
	my $s = shift;
	my $idf_hash = shift;
	
	if (!defined $idf_hash) {
		$idf_hash = Zpravostroj::InverseDocumentFrequencies::get_frequencies();
	}
	
	my $article_count = shift;
	
	if (!$article_count) {
		$article_count = Zpravostroj::AllDates::get_saved_article_count();
	}
	
	my $count = shift; 
		#kolik jich mám vrátit
	
	
	
	my $document_size = scalar @{$s->words};
	
	my %importance;
	
	my $word_counts = $s->counts;
	
	
	#http://en.wikipedia.org/wiki/Tf%E2%80%93idf
	
	
	for my $word (values %{$word_counts}) {
		
		my $lemma = $word->lemma;
		
		my $d = ($idf_hash->{$lemma}||0);
		$d = 1 if ($d==0); #nemělo by se stávat, ale pro jistotu
		
		if (defined $lemma) {
			my $tf = $word->score() / $document_size;
				#term frequency
				
			my $idf = log($article_count / $d);
				#inverse document frequency
				
			$importance{$lemma} = $tf * $idf;
		}
		
	}
	
	
	
	my @sorted_lemmas = (sort {$importance{$b}<=>$importance{$a}} keys %importance);
	
	if (defined $count) {
		@sorted_lemmas = @sorted_lemmas[0..$count-1] if (scalar(@sorted_lemmas) > $count);
	}
	
	#vracím seřazené podle důležitosti a useklé podle $count
	my @res=(map {new Zpravostroj::Word(form=>$word_counts->{$_}->form, lemma=>$_, score=>$importance{$_})} @sorted_lemmas);
	return \@res;
}

#jednoznačně identifikující ID článku
sub ID {
	my $s = shift;
	return $s->date->year."-".$s->date->month."-".$s->date->day."-".$s->article_number;
}


#Manuální tagy (jenom zavolá Zpravostroj::ManualCategorization)
sub unlimited_manual_tags {
	my $s = shift;
	
	my $id = $s->ID;
	
	return Zpravostroj::ManualCategorization::Unlimited::get_article_categories($id);
}

sub news_topics_manual_tags {
	my $s = shift;
	
	my $id = $s->ID;
	
	return Zpravostroj::ManualCategorization::NewsTopics::get_article_categories($id);
}

__PACKAGE__->meta->make_immutable;


1;
