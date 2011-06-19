package Zpravostroj::Categorizer::AICategorizer;

use Zpravostroj::Globals;
use Moose;
with 'Zpravostroj::Categorizer::Trained';

use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Document;
use AI::Categorizer::FeatureVector;
use AI::Categorizer::Category;
use AI::Categorizer::Learner;

has 'learner'=> (
	is=>'ro',
	isa=>'AI::Categorizer::Learner',
	required=>1
);

has 'all_themes_as_features'=> (
	is=>'ro',
	isa=>'Bool',
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
	
	my $document = new AI::Categorizer::Document(name => $touple->{article}->url(), categories=>\@categories);
	
	
	say "WTF0.";
	
	my $features=get_features_from_article( $touple->{article}, $options->{all_themes_as_features});
	
	say "WTF1.";
	my $feature_vector = new AI::Categorizer::FeatureVector(features => $features);

	say "Vytvareni featureVectoru hotovo.";
	$document->features($feature_vector);
	
	say "Features uspesne spusteno.";
	
	
	$hashref->{knowledgeset}->add_document($document);
	
}

sub get_features_from_article {
	my $article = shift;
	
	my $all_themes_as_features = shift;
	my $source = $article->url();
	if ($source !~ /http:\/\/(?:\w+\.)?(\w+)\.\w+\/*/) {
		die "Article URL doesn't look like URL :(";
	}
	$source = $1;
	
	my %features;
	$features{"source_".$source}=1;
	
	say "Pridavam feature source_$source=1";
	
	if ($all_themes_as_features) {
		for my $theme (@{$article->complete_tf_idf}) {
			my $feature_name = $theme->{lemma};
			
			my $feature_value = $theme->{importance};
			$features{$feature_name} = $feature_value;
			say "Pridavam feature $feature_name=$feature_value";
		
		
		}
	} else {
		for my $theme (@{$article->themes}) {
			my $feature_name = $theme->{lemma};
			my $feature_value = 1;
			$features{$feature_name} = $feature_value;
			say "Pridavam feature $feature_name=$feature_value";
		
		}
	}
	say "WTF-1";
	return \%features;
	
}

sub _finish_training {
	shift;
	my $hashref = shift;
	my $options = shift;
	
	my $name;
	if (defined $options and defined $options->{name}) {
		$name = $options->{name}
	} else {
		die "no name";
	}
	
	say "Pred vytvorenim learneru.";
	my $learner = $name->new();
	
	say "Po vytvoreni learneru.";
	
	$learner->train(knowledge_set => $hashref->{knowledgeset});
	
	
	return {learner=>$learner, all_themes_as_features=>($options->{all_themes_as_features})};
	
}

sub get_article_tags {
	my $self = shift;
	my $article = shift;
	
	my $features = get_features_from_article($article, $self->all_themes_as_features);
	
	my $document = new AI::Categorizer::Document(name => $article->url());
	
	
	my $feature_vector = new AI::Categorizer::FeatureVector(features => $features);
	$document->features($feature_vector);
	
	my $hypothesis = $self->learner()->categorize($document);
	
	
	my @categories = ($hypothesis->best_category()); #hypothesis->categories(); #
	
	return @categories;
}
1;