package Zpravostroj::Categorizer::AICategorizer;
#AICategorizer používá modul AI:.Categorizer
#(ten implementuje NaiveBayes, SVM a Decision Trees)

use strict;
use warnings;

use Zpravostroj::Globals;
use Moose;
use MooseX::StrictConstructor;

with 'Zpravostroj::Categorizer::Categorizer';

use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Document;
use AI::Categorizer::FeatureVector;
use AI::Categorizer::Category;
use AI::Categorizer::Learner;

#Objekt, co se učí a co potom zatřizuje
has 'learner'=> (
	is=>'ro',
	isa=>'AI::Categorizer::Learner',
	required=>1
);

#Jestli brát jako featury všechna slova z článku s jejich tf-idf vahami
#1=ano
#0=ne, ber jenom prvních 20 s vahou featury 1
has 'all_themes_as_features'=> (
	is=>'ro',
	isa=>'Bool',
	required=>1
);

#Vrací jednu, nebo více kategorií?
has 'one_category'=>(
	is=>'ro',
	isa=>'Bool',
	required=>1
);

#Vytvoří knowledgeset, learner a na článcích natrénuje learner
sub _create {
	my $class = shift;
	
	my $array = shift;
	
	my $options = shift;
	
	my $all_themes_as_features = $options->{all_themes_as_features};
	
	my $AI_categorizer_classname = $options->{name};
	
	my $knowledgeset = new AI::Categorizer::KnowledgeSet(verbose=>1);
	
	for my $touple (@$array) {
		_add_to_knowledgeset($touple, $knowledgeset, $all_themes_as_features);
	}
	
	my $learner = _train($knowledgeset, $AI_categorizer_classname);
	
	
	return {learner=>$learner, all_themes_as_features=>$all_themes_as_features, one_category=>$options->{one_category}};
}


#Do Knowledgesetu prida clanky, reprezentovane jako jejich featury, a zaradi je tam do kategorii
sub _add_to_knowledgeset {
	
	say "Pridavam dalsi clanek.";
	my $touple = shift;
	my $knowledgeset = shift;
	my $all_themes_as_features = shift;
	
	my @categories;
	
	for my $tag (@{$touple->{tags}}) {
		my $category = AI::Categorizer::Category->by_name(name => $tag);
		
		push (@categories, $category);
		
		
	}
	
	my $document = new AI::Categorizer::Document(name => $touple->{article}->url(), categories=>\@categories);
	
	
	
	my $features=get_features_from_article( $touple->{article}, $all_themes_as_features);
	
	my $feature_vector = new AI::Categorizer::FeatureVector(features => $features);

	$document->features($feature_vector);
	
	say "Hotovo.";
	
	
	$knowledgeset->add_document($document);
	
}

#Ze clanku dostane featury jako hash
sub get_features_from_article {
	my $article = shift;
	
	my $all_themes_as_features = shift;
	my $source = $article->url();
	if ($source !~ /http:\/\/(?:\w+\.)?(\w+)\.\w+\/*/) {
		die "Article URL doesn't look like URL :(";
	}
	$source = $1;
	
	#zdroj je taky featura
	my %features;
	$features{"source_".$source}=1;
	
	say "Pridavam feature source_$source=1";
	
	my $idf_hash = Zpravostroj::InverseDocumentFrequencies::get_frequencies();

	if ($all_themes_as_features) {
		for my $theme (@{$article->tf_idf($idf_hash)}) {
			my $feature_name = $theme->lemma;
			
			my $feature_value = $theme->score;
			$features{$feature_name} = $feature_value;
			say "Pridavam feature $feature_name=$feature_value";
		
		
		}
	} else {
		for my $theme (@{$article->tf_idf_themes}) {
			my $feature_name = $theme->lemma;
			my $feature_value = 1;
			$features{$feature_name} = $feature_value;
			say "Pridavam feature $feature_name=$feature_value";
		
		}
	}
	return \%features;
	
}

#vytvoří AI::Categorizer (musí tedy být už třída načtená pomocí use!)
#a spustí train
sub _train {
	my $knowledgeset = shift;
	my $AI_categorizer_classname = shift;
	
	my $learner = $AI_categorizer_classname->new();
		
	$learner->train(knowledge_set => $knowledgeset);
	
	
	return $learner;
	
}

#Řekne si o kategorii
sub get_article_tags {
	my $self = shift;
	my $article = shift;
	
	
	my $features = get_features_from_article($article, $self->all_themes_as_features);
	
	my $document = new AI::Categorizer::Document(name => $article->url());
	
	
	my $feature_vector = new AI::Categorizer::FeatureVector(features => $features);
	$document->features($feature_vector);
	
	my $hypothesis = $self->learner()->categorize($document);
	
	print "Assigned categories: ", join ', ', $hypothesis->categories, "\n";
 print "Best category: ", $hypothesis->best_category, "\n";
 print "Assigned scores: ", join ', ', $h->scores( $hypothesis->categories ), "\n";
	
	
	my @categories = ($self->one_category)?($hypothesis->best_category()) : ($hypothesis->categories()); #
	
	
	return @categories;
}

#Vrací vše zkategorizované
sub categorize {
	my $self = shift;
	my @articles = @_;
	
	my @tagged;
	

	for my $article (@articles) {
		push (@tagged, {article=>$article, tags=>[ $self->get_article_tags($article) ]});
	}
	return @tagged;
}
1;
