package Zpravostroj::Categorizer::NaiveBayesMultiple;

use Zpravostroj::Globals;
use Moose;
with 'Zpravostroj::Categorizer::Trained';

use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Document;
use AI::Categorizer::FeatureVector;
use AI::Categorizer::Category;
use AI::Categorizer::Learner::NaiveBayes;

use AI::Categorizer::Learner::DecisionTree;
use AI::Categorizer::Learner::SVM;

has 'learners'=> (
	is=>'ro',
	isa=>'HashRef[AI::Categorizer::Learner::NaiveBayes]',
	required=>1
);

sub _create_training_object {
	# shift;
	# my $options = shift;
	
	return {categories=>{}, touples=>[]};
}

sub _train_on_article {
	shift;
	
	say "Trenuji na dalsim clanku.";
	my $touple = shift;
	my $hashref = shift;
	my $options = shift;
	
	
	
	my %tags_hash;
	for my $tag (@{$touple->{tags}}) {
		$hashref->{categories}->{$tag}=undef;
		
		$tags_hash{$tag}=undef;
	}
	push (@{$hashref->{touples}}, {article=>($touple->{article}), tags_hash=>\%tags_hash, features=>get_features_from_article( $touple -> {article})});
	
	
}

sub get_features_from_article {
	my $article = shift;
	
	my $source = $article->url();
	if ($source !~ /http:\/\/(?:\w+\.)?(\w+)\.\w+\/*/) {
		die "Article URL doesn't look like URL :(";
	}
	$source = $1;
	
	my %features;
	$features{"source_".$source}=1;
	
	for my $theme (@{$article->themes}) {
		my $feature_name = $theme->lemma;
		my $feature_value = 2;
		$features{$feature_name} = $feature_value;
		
	}
	
	return \%features;
	
}

sub _finish_training {
	shift;
	my $hashref = shift;
	my $options = shift;
	
	my %learners;
	
	for my $category (keys %{$hashref->{categories}}) {
		
		my $k = new AI::Categorizer::KnowledgeSet(verbose => 1);
		
		my $yes = AI::Categorizer::Category->by_name(name => "yes_".$category);
		my $not = AI::Categorizer::Category->by_name(name => "not_".$category);
		
		for my $touple (@{$hashref->{touples}}) {
			
			
			my $document;
			if (exists $touple->{tags_hash}->{$category}) {
				say "document yes";
				$document = new AI::Categorizer::Document(name => $touple->{article}->url(), categories=>[$yes]);
			} else {
				say "document not";
				$document = new AI::Categorizer::Document(name => $touple->{article}->url(), categories=>[$not]);
			}
			
			my $features = $touple->{features};
			
			my $feature_vector = new AI::Categorizer::FeatureVector(features => $features);
			
			$document->features($feature_vector);
			
			$k->add_document($document);
		}
		
		my $learner = new AI::Categorizer::Learner::NaiveBayes();
		
		$learner->train(knowledge_set => $k);
		
		$learners{$category} = $learner;
	}
	
	
	return {learners=>\%learners};
	
}

sub get_article_tags {
	my $self = shift;
	my $article = shift;
	
	my $features = get_features_from_article($article);
	
	my $document = new AI::Categorizer::Document(name => $article->url());
	my $feature_vector = new AI::Categorizer::FeatureVector(features => $features);
	$document->features($feature_vector);
	
	my @tags;
	
	for my $category (keys %{$self->learners()}) {
		my $learner = $self->learners->{$category};
		
		my $hypothesis = $learner->categorize($document);
		
		my $category = $hypothesis->best_category;
		
		if ($category=~/^yes_(.*)$/) {
			push(@tags, $1);
		}
	}
	
	return @tags;
}
1;