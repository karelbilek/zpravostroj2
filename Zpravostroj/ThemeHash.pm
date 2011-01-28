package Zpravostroj::ThemeHash;
use strict;
use warnings;

use forks;
use forks::shared;

use Zpravostroj::Globals;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage;

has 'themes' => (
	is => 'rw',
	isa => 'HashRef[Theme]',
	default => sub { {} }
);

sub add_theme {
	my $s = shift;
	my $what = shift;
	
	my $themes = $s->themes;
	
	if (exists $themes -> { $what->lemma }) {
		my $p = $themes -> { $what->lemma } -> add_1;
		$themes -> {$what->lemma} = shared_clone($p);
	} else {
		my $p = $what->same_with_1;
		$themes -> {$what->lemma} = shared_clone($p);
	}
}

sub all_themes_lemmas {
	my $s = shift;
	
	return keys %{$s->themes}
}

sub get_theme {
	my $s = shift;
	my $lm = shift;
	return $s->themes->{$lm};
}

sub all_themes {
	my $s = shift;
	
	return values %{$s->themes}
}

sub all_themes_sorted {
	my $s = shift;
	my @all = $s->all_themes;
	return sort{$b->importance <=> $a->importance} @all;
}

sub top_themes {
	my $s = shift;
	my $n = shift;
	my @top = $s->all_themes_sorted;
	if (@top < $n) {
		return @top;
	} else {
		return @top[0..$n-1];
	}
}

__PACKAGE__->meta->make_immutable;