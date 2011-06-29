package Zpravostroj::Traversable;
#Představuje objekt, přes který se dá iterovat
#Tím myslím, že ten objekt má nějaké podobjekty a na každý z nich se spustí stejná subroutina

#Subroutina se může spustit buď "klasicky", nebo ve forku na pozadí;
#pokud se spustí na pozadí, tak se čeká, než se všechny dokončí, a díky Forkeru se jich spouští pouze určitý počet najednou

#Traversable objekt musí umět dát pole stringů, přes které se iteruje a potom musí umět z každého tohoto stringu udělat objekt
#(je to rozděleno na dvě části proto, protože načítání článku je náročná operace a je lepší jí TAKY dát do forku, co spouští subroutinu)


use Moose::Role;

use Zpravostroj::Forker;
use Zpravostroj::Globals;

#neco, co vrati pole, ktere predstavuje to, pres co se bude iterovat
#nejsou to objekty, ale retezce (napr. retezce, predstavujici dny)
requires '_get_traversed_array';

#tohle naopak z retezce, co vraci ta vec nahore, vrati objekt
requires '_get_object_from_string';

#tohle je neco, co se spusti na kazdy objekt po subrutine
#preda se mu to, co vratila ta subroutine
#(prakticky - ukladani souboru)
#((pozor na vraceni veci z forku. obcas to dela neplechu, kdyz se predava objekt, co se odalokuje smrti forku))
requires '_after_subroutine';

#Vezme vsechny veci z _get_traversed_array, rozbali je pres _get_object_from_string a spusti na ne _after_subroutine
sub traverse(&$) {
	#samotny objekt
	my $s = shift;
	
	#ukazatel na subroutinu, co budu spoustet na kazdy "podobjekt"
	my $subref = shift;
	
	#kolik se muze spustit forku najednou (0 nebo 1 = nespousti se nic)
	my $size = shift;
	
	#Jestli nema byt potichu (undef == mluv normalne, 1==shut up)
	my $shut_up = shift;
	
	#jestli se ma vubec forkovat (1 nebo 0 = neforkuje)
	my $should_fork = ($size > 1);
	
	#Vytvoreni noveho "forkeru"
	my $forker = $should_fork ? new Zpravostroj::Forker(size=>$size, shut_up=>1) : undef;

	#Zazadam si o to samotne pole
	say "pred get traversed array" unless $shut_up;
	my @array = $s->_get_traversed_array();
	#@array=@array[0..0];
	say "array je velky ",scalar @array unless $shut_up;
	
	#Vezmi kazdy string z toho pole.
	for my $string (@array) {
		say "string $string" unless $shut_up;
		
		#Tady se vytvori jeste JEDNA subroutina, do ktere se "zavre" ta subroutina, kterou jsem dostal
		#a az TA se preda forkeru ke spusteni
		#(aby se i otevirani a pripadne ukladani pustilo v separatnim forku)
		my $big_subref = sub {
			
			#nacte objekt
			my $object = $s->_get_object_from_string($string);
			
			#Muze se stat, ze se nenacte, proto test na defined
			if (defined $object) {
				
				#Spusti to tu subrutinu a vysledek nacte do @res
				say "trversable - Pred subr. $string" unless $shut_up;
				my @res = $subref->($object, $string);
				
				#....a nakonec spusti _after_subroutine (tj. ukladani)
				say "trversable - po subr." unless $shut_up;
				$s->_after_subroutine($string,$object, @res);
				
				say "trversable - po after traverse" unless $shut_up;

			} 
			
			say "trversable - KONCIM SUBRUTINU!!!!" unless $shut_up;
			return 1;
		};
		
		#Podle toho, jestli je nebo neni >1 tak bud spusti ve forkeru
		if ($should_fork) {
			$forker->run($big_subref);
		} else {
			say "Pred SPUSTENIM big_subroutiny.";
			my $res = $big_subref->();
			if ($res!=1) {
				die "WTF. vykricnik je ".$!;
			}
			say "Po SPUSTENI big_subroutiny.";
		}
		say "Next v []array";
	}
	
	say "Po [] array.";
	
	#Pokud je to forker, tak na nej musim pockat.
	if ($should_fork) {
		say "cekam na forker..." unless $shut_up;
		$forker->wait();
		say "done" unless $shut_up;
	}
	
	say "VYPADAVAM Z TRAVERSE u objektu ".$s;
}

1;