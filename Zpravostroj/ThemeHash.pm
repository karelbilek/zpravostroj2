package Zpravostroj::ThemeHash;
#Nijak extra chytry objekt, co reprezentuje hash temat - tj. objektu Zpravostroj::Theme
#je to extra objekt kvuli tomu, ze se da dobre sharovat, lockovat na nem atd
#pak proto, ze se da dobre ukladat do souboru pomoci Storage

#oboji by asi slo jako normalni hash, ale ten nekontroluje typy pres Moose
# a hlavne - ono je to potom vsechno mnohem prehlednejsi


use strict;
use warnings;

#forks kvuli tomu, ze tema muze byt sharovano (a ve skutecnosti je snad sharovano vzdy)
use forks;
use forks::shared;

use Zpravostroj::Globals;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage;

#key hashe je lemma, values jsou Zpravostroj::Theme
has 'themes' => (
	is => 'rw',
	isa => 'HashRef[Theme]',
	default => sub { {} }
);


#Prida tema do hashe
#pokud tam je, zvetsi jeho ohodnoceni o 1
#pokud neni, prida ho tam, ale s ohodnocenim 1
#(tj. puvodni ohodnoceni se VZDY ztrati!)
sub add_theme {
	my $s = shift;
	my $what = shift;
	my $share = shift;
	
	my $themes = $s->themes;
	
	#co bude v $themes->{$what->lemma}?
	my $p = (exists $themes -> { $what->lemma }) ?
		(
			$themes -> { $what->lemma } -> add_1 #bud totez, co tam je, ale o 1 vetsi
		) : (
			$what->same_with_1					#nebo to, co mam pridat, se skore 1
		);
	
	$themes -> {$what->lemma} = $share ? shared_clone($p) : $p;
				#bud to sharuju, nebo ne (ve skutecnosti vzdy ano, mam pocit, ale radsi to takhle necham)
				#(pri ukladani do souboru se "shared" vlastnost nezachovava, mozna samozrejme)
}

#vrati vsechny lemmatka
sub all_themes_lemmas {
	my $s = shift;
	
	return keys %{$s->themes}
}

#vrati theme z danneho lemmatka
sub get_theme {
	my $s = shift;
	my $lm = shift;
	return $s->themes->{$lm};
}

#vrati vsechna temata
sub all_themes {
	my $s = shift;
	
	return values %{$s->themes}
}

#vrati vsechna temata, serazena podle dulezitosti
sub all_themes_sorted {
	my $s = shift;
	my @all = $s->all_themes;
	return sort{$b->importance <=> $a->importance} @all;
}

#vraci N serazenych nejlepsich temat
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