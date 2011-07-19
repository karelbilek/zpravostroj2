package Zpravostroj::Categorizer::StopThemes;
#Zařazuje do stop-témat - tj. nejčastější témata bez stop-slov
#viz BP

use Moose;
with 'Zpravostroj::Categorizer::Categorizer';

#nic netvoří
sub _create {
	
	return {};
}

#Dá každému všechny stop-témata všem
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