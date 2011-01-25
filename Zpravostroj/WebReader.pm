package Zpravostroj::WebReader;
#Pomocny modulek na cteni z webu
#co mu dam jenom URL a on vyda HTML

#(v CPANu je na to spooousta modulu, ale vzdycky delaji bud moc, nebo malo)

use strict;
use warnings;

use 5.008;
use Globals;

use Encode;
use HTML::Encoding 'encoding_from_http_message';
use LWP::UserAgent;

#UserAgent je globalni, protoze proc ne.
my $ua = LWP::UserAgent->new;

sub wread {
	my $try_count;
	my $address = shift;
	
	my $resp;
	
	do {
		$resp = $ua->get( $address );
		$try_count++;
	} while ($try_count<=5 and $resp->code != 200);
		#try to download it 5 times, if server is not responsive
	
	if ($resp->code != 200) {
		return "";
	}
	
	#s timhle byl myslim nekdy problem, ale uz nevim kdy :)
	my $enco = encoding_from_http_message($resp);

	return decode($enco => ($resp->content));
	
}

1;