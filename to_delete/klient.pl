use 5.010;
use IO::Socket;
use strict;
use Encode;
use encoding 'utf8';

binmode STDOUT, ':utf8';



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

sub print_lemmas {
	my @all = @_;
	while (scalar @all) {
		my $form = shift @all;
		my $lemma = shift @all;
		say "Form: $form, lemma: $lemma";
	}
}

sub print_named {
	my @all = @_;
	while (scalar @all) {
		my $named = shift @all;
		my $type = shift @all;
		say "Named: $named, type: $type";
	}
}


sub doitall {

	my $sock = new IO::Socket::INET (
		PeerAddr => 'localhost',
		PeerPort => '7070',
	);


	binmode $sock, ':utf8';



	die "Could not create socket: $!\n" unless $sock;

	my $text='Svitky od Mrtvého moře (někdy Kumránské svitky) jsou nálezy starověkých svitků a jejích zlomků nalezených poblíž Mrtvého moře, zejména v Kumránu. Svitky obsahují biblické a další náboženské texty.
	Okolnosti nálezu nejsou příliš jasné. Svitky byly objeveny roku 1947 (někdy se uvádí rok 1946) třemi beduíny – pašeráky, kteří chtěli svůj nález dobře zpeněžit.[1] Svitky byly zveřejněny v roce 1948. Metropolita Samuel, který část svitků odkoupil (druhou část koupil krátce nato Eleazar Sukenik), je v roce 1949 nechal prozkoumat a odvezl je do USA. Roku 1954 se zásluhou jeruzalémského docenta Jigaela Jadina navrátily do Izraele a byly umístěny do Svatyně knihy.[2] Druhá důležitá sbírka spisů existuje v Rockefellerově muzeu – archeologickém muzeu v Jeruzalémě. Muzeum bylo v roce 1966 zestátněno Jordánskem a po Šestidenní válce je získal Izrael.';

	my $lemmas = 1;
	my $entities = 1;

	if ($lemmas) {
		if ($entities) {
			say $sock "LEMMAS ENTITIES";
		} else {
			say $sock "LEMMAS";
		}
	} else {
		if ($entities) {
			say $sock "ENTITIES";
		} else {
			die "NO FUN ALLOWED\n";
		}
	}

	say $sock $text;
	say $sock "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC";

	if ($lemmas) {
		say "LEMMAAAAAAAAS";
		print_lemmas(read_from_sock($sock));
	}
	if ($entities) {
		say "ENTITIEEEEEES";
		print_named(read_from_sock($sock));
	}

	close($sock);
}

use forks;

for (1..1){
	threads->new(sub{
		doitall();
	});
}

$_->join foreach threads->list;