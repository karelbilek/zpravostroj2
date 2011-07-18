package Zpravostroj::Categorizer::TfIdfThemes;

use Moose;
with 'Zpravostroj::Categorizer::Categorizer';

has 'count'=> (
	is=>'ro',
	isa=>'Int',
	required=>1
);

sub _create {
	shift;
	
	my $array = shift;
	my $c = shift;
	
	return {count=>$c};
}

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

