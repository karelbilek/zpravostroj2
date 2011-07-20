package Zpravostroj::Categorizer::FreqThemes;
#zařazuje do "frekvenčních témat" (tj. nejčastější slova)

use strict;
use warnings;

use Moose;
with 'Zpravostroj::Categorizer::Categorizer';

#nic netvoří
sub _create {
	
	return {};
}

#každému dá jeho frekvenční témata
sub categorize {
	my $self = shift;
	my @articles = @_;
	
	my @tagged;
	
	for my $article (@articles) {
		push (@tagged, {article=>$article, tags=>[map {$_->lemma} $article->frequency_themes]});
	}
	return @tagged;
}
1;