package Zpravostroj::Categorizer::StopThemes;

use Moose;
with 'Zpravostroj::Categorizer::Categorizer';


sub _create {
	
	return {};
}

sub categorize {
	my $self = shift;
	my @articles = @_;
	
	my @tagged;
	
	for my $article (@articles) {
		push (@tagged, {article=>$article, tags=>[map {$_->form} $article->stop_themes]});
	}
	return @tagged;
}
1;