package Zpravostroj::Categorizer::TotallyRetarded;
#Triviální kategorizér, co všechno zatřídí do kategorie, která mu přijde

use strict;
use warnings;


use Moose;
with 'Zpravostroj::Categorizer::Categorizer';

has 'tag'=> (
	is=>'ro',
	isa=>'Str',
	required=>1
);

#Odignoruje se pole, nastaví se tag
sub _create {
	shift;
	
	my $array = shift;
	my $tag = shift;
	
	return {tag=>$tag};
}

#Nastaví tag u článku
sub categorize {
	my $self = shift;
	my @articles = @_;
	
	my @tagged;
	
	for my $article (@articles) {
		push (@tagged, {article=>$article, tags=>[$self->tag()]});
	}
	return @tagged;
}
1;