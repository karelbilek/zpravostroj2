package Zpravostroj::Categorizer::TotallyRetardedTrained;

use Zpravostroj::Globals;
use Moose;
with 'Zpravostroj::Categorizer::Trained';

has 'tag'=> (
	is=>'ro',
	isa=>'Str',
	required=>1
);

sub _create_training_object {
	shift;
	my $options = shift;
	
	
	
	return {counter=>{}};
}

sub _train_on_article {
	shift;
	
	say "Trenuji na dalsim clanku.";
	my $touple = shift;
	my $hashref = shift;
	my $options = shift;
	
	for my $tag (@{$touple->{tags}}) {
		if ($tag eq $options->{first} or $tag eq $options->{second}) {
			$hashref->{counter}->{$tag}++;
			say "Pricitam $tag, je ted ",$hashref->{counter}->{$tag};
			
		}
	}
	
	
}

sub _finish_training {
	shift;
	my $hashref = shift;
	my $options = shift;
	
	if ($hashref->{counter}->{$options->{first}} > $hashref->{counter}->{$options->{second}}) {
		say "Var 1 - vracim - ",$options->{first};
		return {tag=> $options->{first}};
	} else {
		say "Var 2 - vracim - ",$options->{first};
		
		return {tag=> $options->{second}};
	}
	
}

sub get_article_tags {
	my $self = shift;
	
	return ($self->tag);
}
1;