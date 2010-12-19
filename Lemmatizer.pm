package Lemmatizer;

use 5.008;
use Globals;
use Word;
use Data::Dumper;

use base 'Exporter';
our @EXPORT = qw(lemmatize);

use IO::Socket::INET;
use strict;
use warnings;

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

sub lemmatize {
	my $text = shift;
	
	my $sock;
	
	while (!$sock) {
		$sock = new IO::Socket::INET (
			PeerAddr => 'localhost',
			PeerPort => '7070',
		);
	}
	
	
	
	say "LEMMATIZE START!\n";


	binmode $sock, ':utf8';
	
	print $sock "LEMMAS ENTITIES\n";
	print $sock $text;
	print $sock "\n";
	print $sock "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC\n";
	
	say "Neco rekl do TectoMT, jdu na nej cekat";
	my @lemmas_all = read_from_sock($sock);
	my %named = read_from_sock($sock);
	
	say "Docekal.";
	
	
	my @res;
	while (@lemmas_all) {
		my $w = Word->new(all_named=>\%named, lemma=>(shift @lemmas_all), form=>(shift @lemmas_all));
		
		push (@res, $w) if ($w->is_meaningful);
	}
	
	say "LEMMATIZE END!";
	
	return \@res;
}

1;