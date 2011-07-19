package Zpravostroj::Categorizer::Categorizer;
#Obecný kategorizér (abstraktní třída)

#Pro jednoduchou ukázku, jak třída funguje, viz Zpravostroj::Categorizer::TotallyRetarded - triviální kategorizér

use warnings;
use strict;

use Zpravostroj::Globals;

use Moose::Role;



#jakoby konstruktor

#dostane jako první argument pole hashů s článkem a tagy
#další argumenty můžou být cokoliv

#vrací hash, který je potom použit ke konstrukci Moose objektu

#tj v průbehu _create ještě ten objekt neexistuje
requires '_create';



#dostane SEZNAM clanku, vrati podobne pole, jako dostava _create
requires 'categorize';


around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;
	
	my @arr = @_;
	
	my %h = %{$class->_create(@arr)};
	return $class->$orig(%h);
};

1;