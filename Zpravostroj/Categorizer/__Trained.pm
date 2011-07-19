package Zpravostroj::Categorizer::Trained;

use Moose::Role;;
with 'Zpravostroj::Categorizer::Categorizer';


requires '_create_training_object';
requires '_train_on_article';
requires '_finish_training';

requires 'get_article_tags';

sub _create {
	my $class = shift;
	
	my $array = shift;
	
	my $options = shift;
	my $hashref = $class->_create_training_object($options);
	
	for my $touple (@$array) {
		$class->_train_on_article($touple, $hashref, $options);
	}
	
	my $final_hashref = $class->_finish_training($hashref, $options);
	
	return $final_hashref;
}

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