package Zpravostroj::Categorizer::TfIdfThemes;
#Zatřídí do kategorií, odpovídajícím tf-idf tématům

use strict;
use warnings;


use Moose;
with 'Zpravostroj::Categorizer::Categorizer';

#Kolik vzít témat
has 'count'=> (
	is=>'ro',
	isa=>'Int',
	required=>1
);

#Odignoruje pole, nastaví count
sub _create {
	shift;
	
	my $array = shift;
	my $c = shift;
	
	return {count=>$c};
}

#Pro každý článek vezme count nejdůležitějších TF-IDF témat
sub categorize {
	my $self = shift;
	my @articles = @_;
	
	my @tagged;
	
	for my $article (@articles) {
		
		my @t = sort {$b->score <=> $a->score} @{$article->tf_idf_themes};
		if (scalar @t > $self->count) {
			@t=@t[0..$self->count-1];
		}
		
		push (@tagged, {article=>$article, tags=>[map {$_->{lemma}} @t]});
	}
	return @tagged;
}
1;

