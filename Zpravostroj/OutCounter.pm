package Zpravostroj::OutCounter;
#Jednoduchý modul/objekt, který mi pomáhá s "externím sčítáním" - sčítání velkého množství dat klíč-hodnota pomocí 
#vnějšího třídění

#protože se mi ta data nevejdou do paměti PLUS k nim přistupuji z více procesů - a řešit to přes externí soubor je rychlejší,
#než ta data sdílet mezi více forky


#Pracuje se s ním tak, že se "do něj" přidávají hashe, co mají dvojice string-hodnota [ty se tedy vypisují do souboru tak, jak jdou]
#A on potom tyto hodnoty sečte pomocí vnějšího třídění, volitelně seřadí podle velikosti posčítaných hodnot
# a jednak buď vrátí opět jako hash
#nebo jenom nechá v daných souborech (tak to používám častěji)

#Pokud chce víc forků přidávat do stejného OutCounteru, tak musí jeden počkat, než druhý dopíše
#(jako lock používám adresář)

use 5.008;

use warnings;
use strict;
use Time::HiRes qw( usleep);

use Moose;
use Zpravostroj::Globals;

mkdir "tmp";

#Jméno/adresa souborů
has 'name' => (
	is=>'ro',
	required=>'1',
	isa=>'Str'
);

#Jestli je ve "spočítaném" stavu
#(pokud OutCounter spočítám, je ve spočítaném stavu,
#	jakmile do něj ale přidám další data, tak už ve spočítaném stavu není)
has 'counted' => (
	is => 'rw',
	isa => 'Bool',
	default=> '0'
);


#Jestli mám nebo nemám při vytváření objektu mazat původní soubory
#(užitečné jsou obě varianty)
has 'delete_on_start' => (
	is => 'rw',
	isa => 'Bool',
	default=> '1'
);


#Adresa přechodného souboru, kam zapisuji přidávané hashe
sub tempname {
	my $s = shift;
	return $s->name."_temp";
}

#Adresa adresáře, který používám jako lock, aby mi různé thready nezapisovaly naráz
sub lockname {
	my $s = shift;
	return $s->name."_lock";
}

#Adresa souboru se seřazenými, ale neposčítanými daty (prakticky jen _temp, prohnaný sortem)
sub sortname {
	my $s = shift;
	return $s->name."_sorted";
}

#Adresa souboru s posčítanými daty (ale neseřazenými podle velikosti)
sub countedname {
	my $s = shift;
	return $s->name."_counted";
}

#Adresa souboru s daty posčítanými A seřazenými podle velikosti
sub sorted_by_frequencyname {
	my $s = shift;
	return $s->name."_counted_sorted_by_frequency";
}

#Moose "konstruktor"
sub BUILD {
	my $s = shift;
	
	system("rm ".$s->tempname) if ((-e $s->tempname) and $s->delete_on_start);

}

#Načte a vrátí sečtené počty v hashi
#(pokud je potřeba, tak seřadí)
sub return_counted {
	my $s = shift;
	
	$s->count_it();
	
	my %res;
	
	open my $if, "<:utf8", $s->countedname;
	
	for (<$if>) {
		/(.*)\t(.*)\n/;
		
		$res{$1} = $2;
	}
	
	close $if;
	return \%res;
}

#Přidá hash do souboru.
sub add_hash {
	my $s = shift;
	
	my $hash = shift;
	
	say "Jdu se pokouset o vytvoreni locku";
	
	while (!mkdir $s->lockname) {
		say "Zakladam neuspesne, spim.";
		usleep(10000);
	}
	
	say "Zalozeno.";
	
	open my $of, ">>:utf8", $s->tempname;
	
	
	#vypisuje dvojice naprosto jak ho napadne
	while (my ($word, $value) = each %$hash) {
		print $of $word."\t".$value."\n";
	}
	
	
	close $of;
	

	$s->counted(0);
	
	system("rm -r ".$s->lockname);
	say "Smazan lock, hotovo.";
}


#posčítá a vytvoří soubor, kde to seřadí podle druhého sloupečku, sortem
sub count_and_sort_it {
	my $s = shift;
	$s->count_it;
	
	system("sort -n -r -T tmp/ -k 2 ".$s->countedname." > ".$s->sorted_by_frequencyname);
	
}

#samotné sortění
sub count_it {
	my $s = shift;
	
	$s->counted(1);
	
	
	if (!$s->counted) {
		
		
		if (-e $s->countedname) {
			my $countedname = $s->countedname;
			my $tempname = $s->tempname;
			
			#Pokud je spočítaný i přes $s->counted==0 mladší, než tempname, tak stejně nepočítám
			# a budu se tvářit, že jsem spočítal
			#(může se stát proto, že defaultně je counted==0)
			my $should_count = int(`if [ $countedname -ot $tempname ]; then echo "1"; else echo "0";fi;`);
			
			if (!$should_count) {
				return;
			}
		}
		
		
		#adresář je tmp/, protože na ufallab2 jsem neměl přístup do /tmp/
		
		system("sort -T tmp/ -k 1 ".$s->tempname." > ".$s->sortname);
		
		open my $if, "<:utf8", $s->sortname;
		open my $of, ">:utf8", $s->countedname;

		#jednoprůchodový součet, protože je to seřazeno podle prvního sloupečku
		my $last="";
		my $sofar = 0;
		for (<$if>) {
			/(.*)\t(.*)\n/;
			if ($1 eq $last) {
				$sofar += $2;
			} else {
				print $of $last."\t".$sofar."\n" if ($last ne "");
				$sofar = $2;
			}
			$last = $1;
		}
		
		close $if;
		close $of;
		
	}
}

1;