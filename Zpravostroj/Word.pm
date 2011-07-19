package Zpravostroj::Word;
#Objekt, co představuje obecné slovo, které má ještě přidané skóre

#má lemma, form a flag, co říká, jestli je nebo není named entity
#	tím trochu posunuji význam "named entity" - named entity můžou být i víceslovné názvy, ale já chápu
#	named entity jako binární příznak na úrovni slova - slovo buď je, nebo není pojm. entita

#Skóre je k tomu, abych stejný typ mohl používat i na vyhledávání témat

#skóre může znamenat různé věci v různém kontextu

use Zpravostroj::MooseTypes;
use Moose;
use MooseX::StrictConstructor;
use Zpravostroj::Globals;

use MooseX::Storage;

with Storage;

#lemma se koercuje na základě pravidel z Zpravostroj::MooseTypes
#tam se z něj odstraní všechno, co není součást lemmatu v nejužším významu slova
has 'lemma' => (
	is => 'ro',
	predicate => 'has_lemma',
	isa => 'Lemma',
	coerce => 1
);


#Forma
#(je možné, že formu slova si ukládám úplně zbytečně a nikde jí nepoužívám, ale radši jí tu nechám)
has 'form' => (
	is => 'ro',
	required => 1,
	isa => 'Str'
);


#Je to pojmenovaná entita?
has 'named_entity' => (
	is => 'ro',
	isa => 'Bool',
	default => 0
);

has 'score' => (
	is => 'rw',
	isa => 'Num'
);

#kontroluje, jestli má neprázdné lemma
sub is_meaningful {
	my $s = shift;
	if ($s->lemma ne '') {
		return 1;
	} else {
		return 0;
	}
}

#Totéž s vyčištěným lemmatem (nevím, jestli to vůbec někde používám)
sub cleanup {
	my $s = shift;
	return new Zpravostroj::Word(lemma=>cleanup_lemma($s->lemma), form=>$s->form, named_entity=>$s->named_entity);
	
}


#"konstruktor" (around je Moose pseudo-klicove slovo)

#lze mu zadat i all_named misto named_entity - tj. nedostanu flag "je entita", ale hash všech pojmenovaných entit

#lze zadat i pouze "form" jako skalár
around BUILDARGS => sub {
	#$class->$orig volá defaultní Moose konstruktor
	
	my $orig  = shift;
    my $class = shift;
	my %hash;
	
	if (@_==0) {
				#pokud nedávám nic->defaultní new
		return $class->$orig(@_);
		
		
	} elsif (ref $_[0]) {
		
				#pokud je reference na hash, vemu ho jako options
		%hash = %{$_[0]};
		
		
	} elsif (@_==1) {
				#pokud je tam jenom jeden skalar a neni to hashref, je to form, tj. vytvořím slovo rovnou
		return $class->$orig(form=>$_[0]);
	} else {
		
				#je tam ten hash jako list, vemu ho jako options
		%hash = @_;
	}
	
	
	
	if (!exists $hash{'lemma'} or !exists $hash{'all_named'}) {
				#all_named neni->neni duvod neco resit -> default
		return $class->$orig(@_);
	
	} else {
				#z all_named vezmu, jestli tam lemma je, a podle toho urcim named_entity
		my $is = exists $hash{'all_named'}{$hash{'lemma'}};
		delete $hash{'all_named'};
		$hash{'named_entity'}=$is;
		return $class->$orig(\%hash); #....a spustím dál defaultní new
	}
	
	#vsechny cesty volaji defaultni konstruktor, aby se koercovalo lemma a kontrolovaly Moose typy
};


#Přidá SOBĚ skóre
sub add_score{
	my $this = shift;
	my $what = shift;
	$this->score(($this->score)+$what);
}

#Udělá kopii sebe sama, s jiným skóre
sub copy_with_score {
	my $this = shift;
	my $score = shift;
	return (new Zpravostroj::Word(lemma=>$this->lemma, form=>$this->form, score=>$score));

}

__PACKAGE__->meta->make_immutable;


1;

