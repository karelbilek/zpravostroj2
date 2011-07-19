package Zpravostroj::WebReader;
#Pomocný modulek na čtení z webu
#co mu dám jenom URL a on vydá HTML v utf-8

#(v CPANu je na to spousta už udělaných modulů, ale vždycky delají buď moc, nebo málo)

use strict;
use warnings;

use 5.008;
use Zpravostroj::Globals;

use Encode;
use HTML::Encoding 'encoding_from_http_message';
use LWP::UserAgent;

#UserAgent je globálni, protože není důvod ho pokaždé vytvářet znova.
my $user_agent = LWP::UserAgent->new;


#Samotné načtení (zkusí to 5x)
sub wread {
	
	my $address = shift;

	#Kolikrát jsem to zkoušel načíst
	my $try_count;
	
	my $response;
	
	do {
		$response = $user_agent->get( $address );
		$try_count++;
	} while ($try_count<=5 and $response->code != 200);
	
	#po 5 pokusech vzdávám
	if ($response->code != 200) {
		return "";
	}
	


	#s tímhle encodingem jsou někdy problémy.... ale myslím, že takhle je to OK
	my $enco = encoding_from_http_message($response);
	return decode($enco => ($response->content));
	
}

1;