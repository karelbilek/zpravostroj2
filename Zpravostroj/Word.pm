package Zpravostroj::Word;
#Objekt, co představuje obecné slovo

#má lemma, form a flag, co říká, jestli je nebo není named entity
#	tím trochu posunuji význam "named entity" - named entity můžou být i víceslovné názvy, ale já chápu
#	named entity jako binární příznak na úrovni slova - slovo buď je, nebo není pojm. entita

use Zpravostroj::MooseTypes;
use Moose;
use MooseX::StrictConstructor;


use MooseX::Storage;

with Storage;

#lemma se koercuje na základě pravidel z Zpravostroj::MooseTypes
#tam se z něj odstraní všechny "bordely" (resp.... snažím se o to, ale ne vždy se to povede)
has 'lemma' => (
	is => 'ro',
	predicate => 'has_lemma',
	isa => 'Lemma',
	coerce => 1
);

has 'form' => (
	is => 'ro',
	required => 1,
	isa => 'Str'
);

has 'named_entity' => (
	is => 'ro',
	isa => 'Bool',
	default => 0
);

#kontroluje, jestli má smyslplné lemma
sub is_meaningful {
	my $s = shift;
	if ($s->lemma ne '') {
		return 1;
	} else {
		return 0;
	}
}




#"konstruktor" (around je Moose pseudo-klicove slovo)
#lze mu zadat i all_named misto named_entity
#lze zadat i pouze "form" jako skalár
around BUILDARGS => sub {
	#$class->$orig volá defaultní Moose konstruktor
	
	my $orig  = shift;
    my $class = shift;
	my %hash;
	
	
	if (@_==0) {
				#pokud nedávám nic->default
		return $class->$orig(@_);
	} elsif (ref $_[0]) {
				#pokud je reference na hash, vemu ho
		%hash = %{$_[0]};
	} elsif (@_==1) {
				#pokud je tam jenom jeden skalar a neni to hashref, je to form
		return $class->$orig(form=>$_[0]);
	} else {
				#je tam ten hash normalne, vemu ho
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
		return $class->$orig(\%hash);
	}
	
	#vsechny cesty volaji defaultni konstruktor, aby se koercovalo lemma a kontrolovaly typy
};

__PACKAGE__->meta->make_immutable;


1;

