package Zpravostroj::RSS;
#RSS ctecka

#Bohuzel neexistuje nejaka pricetna RSS ctecka, co by splnovala moje pozadavky
#vsechno je to hrozne slozite a chaoticke

#Jedna se tedy o objekt, co ma URL hlavniho feedu plus hash, co ma jako keys URL clanku,
#a jako values ma datumy, kdy byl dany clanek stahnut (tj ne vydan, ale opravdu stahnut)
#datum je myslim YYYY-MM-DD, kazdopadne je to tentyz format, co dava Zpravostroj::Date::get_to_string()

#Pouzivam takovy trik na zjisteni, co uz jsem precetl a co ne: pri refreshovani RSS 
	#vytvarim dvojice URL->DEN, pokud tam uz URL ale neni
#Pri cteni clanku vezmu vsechny clanky, ktere maji DEN dnes nebo vcera a u nich za DEN dopisu "_read"
#a priste pri cteni uz je neberu

#pri dalsim refreshi smazu vsechny, co maji DEN starsi, nez 2 dny, at uz s _read nebo bez _read

#Cely ten objekt je Moose a pomoci Storage ho ukladam komplet

use 5.008;

use warnings;
use strict;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;
with Storage;


use Zpravostroj::Globals;
use Zpravostroj::Date;
use Zpravostroj::WebReader;
use Zpravostroj::MooseTypes;

use Data::Validate::URI qw(is_http_uri);


#URL feedu
has 'url' => (
	is=>'ro',
	required=>1,
	isa=>'URL'
);

#hash URL->datum
has 'article_urls' => (
	is=>'rw',
	isa=>'HashRef[Str]',
	default=>sub { {} }
);

#Smaze z RSS vse predvcerejsi a starsi
#z daneho URL vezme vse a da to do hashe
#(pokud to tam uz je, tak to tam neda)
sub refresh_urls {
	my $s = shift;
	my $today = new Zpravostroj::Date() -> get_to_string;
	my $yesterday = Zpravostroj::Date::get_days_before_today(1);
	
	say "RSS ".$s->url;
	
	#smaze predvcerejsi
	for (keys %{$s->article_urls}) {
		
		my $datestr = $s->article_urls->{$_};
		if ($datestr =~ /^(.*)_read$/) {
			$datestr = $1;
		}
		
		if (Zpravostroj::Date::get_from_string($datestr)->is_older_than($yesterday)) {
			delete $s->article_urls->{$_};
		}
	}
	
	
	#stahne nove
	my $html = Zpravostroj::WebReader::wread($s->url);

	#je to dirty, ale bohuzel, zadny pricetny RSS parser pro perl neexistuje
	#vsechno je to SILENE KOMPLIKOVANE a pada to na kazdem nevalidnim XML /jsou vyjimky, ale nepouzitelne/
	while ($html=~/<link>([^<]*)<\/link>/g) {
		my $link = $1;
		
		#nechci odkazy, co vedou na domovni stranku, nechci odkazy, co nejsou odkazy
		if ($link!~/^http:\/\/[^\/]*\/?$/ and is_http_uri($link) and !defined $s->article_urls->{$link}) {
			
			$s->article_urls->{$link} = $today;
		}
		
	}
}


#viz popis nahore
sub get_urls{
	my $s = shift;
	my $today = new Zpravostroj::Date() -> get_to_string;
	my $yesterday = Zpravostroj::Date::get_days_before_today(1)-> get_to_string;
	

	my @res;
	for (keys %{$s->article_urls}) {
		if ($s->article_urls->{$_} eq $today or $s->article_urls->{$_} eq $yesterday) {
			push (@res, $_);
			$s->article_urls->{$_}.="_read";
		}
	}
	return @res;
	
}

__PACKAGE__->meta->make_immutable;

1;