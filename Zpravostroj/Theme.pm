package Zpravostroj::Theme;
#"téma" je slovo, co má ještě nějaké ohodnocení
#Do ohodnocení jde pokaždé trochu něco jiného :)
#v případě článku tam jde vypočítané skóre pomocí Tf/dfi algoritmu (tj. velmi malé číslo, kolem 1x10-9)
#v případě dne je tam počet článků s danným tématem (přirozené číslo)

#Hlavní otázka. Jaký je rozdíl mezi Zpravostroj::Theme a Zpravostroj::Word?

#Téma je v podstatě Zpravostroj::Word  +  importance, ale kvůli tomu, jak jsem to historicky psal,
#existuje Zpravostroj::Word a Zpravostroj::Theme nezávisle na sobě

#Vzhledem k tomu, jak ukládám data, už to nejde tak jednoduše přepsat
#(původně byla idea, že Theme může být i z více slov, ale bohužel nedávaly bigramy a trigramy
#vůbec dobré výsledky)

#Takže teď má článek jak pole theme (témata), tak pole words (všechna slova).

use strict;
use warnings;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage;

has 'lemma' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'form' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'importance' => (
	is => 'ro',
	isa => 'Num',
	required => 1
);

#vytvori stejne Theme, ale se skorem o 1 zvetsenym
sub add_1{
	my $this = shift;
	return (new Theme(lemma=>$this->lemma, form=>$this->form, importance=>$this->importance+1));

}

#vytvori nove tema, co ma skore toto tema + dalsi tema
#nekontroluje se "stejnost" slov, vysledek ma tema objektu
sub add_another {
	my $this = shift;
	my $that = shift;
	return (new Theme(lemma=>$this->lemma, form=>$this->form, importance=>$this->importance+$that->importance));
	
}

#vytvori stejne Theme, ale se skorem 1 
sub same_with_1 {
	my $this = shift;
	
	return (new Theme(lemma=>$this->lemma, form=>$this->form, importance=>1));
}

__PACKAGE__->meta->make_immutable;

1;
