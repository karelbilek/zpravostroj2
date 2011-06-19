package Zpravostroj::Categorizer::TotallyRetarded;

use Moose;
with 'Zpravostroj::Categorizer::Categorizer';

has 'tag'=> (
	is=>'ro',
	isa=>'Str',
	required=>1
);

sub _create {
	shift;
	
	my $array = shift;
	my $tag = shift;
	
	return {tag=>$tag};
}

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