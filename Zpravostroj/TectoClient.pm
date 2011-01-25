package Zpravostroj::TectoClient;
#Klient k TectoServeru, co vytvari Zpravostroj::Word objekty z textu

use 5.008;
use Globals;
use Zpravostroj::Word;

use IO::Socket::INET;
use strict;
use warnings;

#Jenom cte ze socketu jednu varku
#neinterpretuje to nijak, jenom vraci jako pole
sub read_from_sock {
	my $sock = shift;
	
	my @res;
	while ((my $in =<$sock>) ne "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC") {
		
		if ($in eq "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC\n") {
			last;
		} else {
			chomp $in; push @res, $in;
		}
	}
	
	return @res;
}


#Dostane text, vraci Zpravostroj::Word objekty
sub lemmatize {
	my $text = shift;
	
	my $sock;
	
	#pokud TectoServer neco dela, zablokuje se to tady
	while (!$sock) {
		$sock = new IO::Socket::INET (
			PeerAddr => 'localhost',
			PeerPort => '7070',
		);
	}
	
	say "Lemmatize startuje!\n";
	
	
	binmode $sock, ':utf8';
	
	print $sock $text;
	print $sock "\n";
	print $sock "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC\n";
	
	
	say "Neco rekl do TectoMT, jdu na nej cekat";
	#Dokud TectoMt nezacne neco vracet, zablokuje se to uvnitr read_from_sock
	
	my @lemmas_all = read_from_sock($sock);
	my %named = read_from_sock($sock);
	
	say "Docekal.";
	
	
	my @res;
	while (@lemmas_all) {
		
		#Word uz si nejak v constructoru zaridi jestli je named
		my $w = Zpravostroj::Word->new(all_named=>\%named, lemma=>(shift @lemmas_all), form=>(shift @lemmas_all));
		
		#is_meaningful zkontroluje, jestli je lemma pekne
		#(ve skutecnosti konstruktor Word pres Zpravostroj::MooseTypes zkrati lemma a is_meaningful kontroluje, 
		#	jestli tam vubec neco je, ale to tady neni tak dulezite)
		
		push (@res, $w) if ($w->is_meaningful);
	}
	
	say "Lemmatize konci!";
	
	return @res;
}

1;