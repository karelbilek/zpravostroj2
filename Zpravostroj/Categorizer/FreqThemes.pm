package Zpravostroj::Categorizer::FreqThemes;

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
		push (@tagged, {article=>$article, tags=>[$article->frequency_themes]});
	}
	return @tagged;
}
1;