package Zpravostroj::Categorizer::Categorizer;

use warnings;
use strict;

use Zpravostroj::Globals;

use Moose::Role;

#dostane pole, kde jsou hashe, kde je article odkaz na Article a tags vsechny jeho tagy
requires '_create';

#dostane SEZNAM clanku, vyhodi podobne pole, jako dostava _create
requires 'categorize';


around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;
	
	my @arr = @_;
	
	my %h = %{$class->_create(@arr)};
	return $class->$orig(%h);
};

1;