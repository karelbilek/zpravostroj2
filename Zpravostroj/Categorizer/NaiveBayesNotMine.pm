package Zpravostroj::Categorizer::NaiveBayesNotMine;

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

has 'learner'=> (
	is=>'ro',
	isa=>'AI::Categorizer::Learner::NaiveBayes',
	required=>1
);

sub _create_training_object {
	shift;
	my $options = shift;
	
	my $k = new AI::Categorizer::KnowledgeSet(verbose=>1);
	
	
	return {knowledgeset=>$k};
}

sub _train_on_article {
	shift;
	
	say "Trenuji na dalsim clanku.";
	my $touple = shift;
	my $hashref = shift;
	my $options = shift;
	
	my @categories;
	
	for my $tag (@{$touple->{tags}}) {
		my $category = AI::Categorizer::Category->by_name(name => $tag);
		
		push (@categories, $category);
	}
	
	my $document = new AI::Categorizer::Document(name => $touple->{article}->url(), content => ($touple-> {article}-> article_contents()), categories => \@categories);
	

	
	$hashref->{knowledgeset}->add_document($document);
	
}


sub _finish_training {
	shift;
	my $hashref = shift;
	my $options = shift;
	
	my $learner = new AI::Categorizer::Learner::NaiveBayes();
	
	$learner->train(knowledge_set => $hashref->{knowledgeset});
	
	return {learner=>$learner};
	
}

sub get_article_tags {
	my $self = shift;
	my $article = shift;
	
	
	my $document = new AI::Categorizer::Document(name => $article->url(), content => ($article -> article_contents()));

	
	my $hypothesis = $self->learner()->categorize($document);
	
	
	my @categories = $hypothesis->categories();
	
	return @categories;
}
1;