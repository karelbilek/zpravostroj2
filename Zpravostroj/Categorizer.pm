package Zpravostroj::Categorizer;
use 5.008;
use strict;
use warnings;

use Zpravostroj::AllDates;


my %superthemes = map {($_=>undef)} qw(ods čssd soud volba procento strana blesk * nečas . inzerce nehoda cz policie top vláda muž firma miliarda`1000000000 paroubek řidič poslanec sněmovna kraj zpráva policista dítě ministr leden ministerstvo sníh klaus škola prezident milión`1000000 koalice silnice česko hasič fischer volební stupeň nemocnice koruna žena návrh březen listopad prosinec voda usa ruský zápas sobotka rusko topolánek teplota srpen banka červenec září auto únor john dálnice haiti sociální vv duben vancouver plat cena veřejný smlouva říjen státní film květen červen povodeň volič vlak zelený průzkum hlas čech město projekt útok evropa ostrava čína euro komise pražský rada letiště kalousek americký letadlo požár olympijský zákon kampaň vražda : brno novela předseda senát primátor lékař slovenský dům starosta rozpočet dívka slovensko demokrat schwarzenberg zastupitelstvo koaliční voják řeka sněhový evropský odbor závod vůz stávka zakázka řecko bém zemětřesení kamión bouřka povodňový soudce praha mandát dopravní trest zemřít student čez já mirek daň déšť pacient lídr kč kandidát chlapec polský premiér kdu morava německo obec obrana afghánistán vlček jan hora kandidátka radnice senátor hladina čsl celsius klub zastupitel jaderný eu dolar liška text doprava podnik funkce mladík trh svoboda náměstek zaměstnanec výbor ksčm program pecina brusel moskva ústavní duka záchranář duškův chřipka medveděv odborář meteorolog komunální);


sub find_possible_superthemes {
	my $a = shift;
	
	my @res;
	for my $theme (@{$a->themes}) {
		if (exists $superthemes{$theme->lemma}) {
			push @res, $theme;
		}
	}
	return @res;
}

