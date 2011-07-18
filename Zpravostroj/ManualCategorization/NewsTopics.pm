package Zpravostroj::ManualCategorization::NewsTopics;
#Modul, co "pomáhá" s manuální kategorizací.
#(::Unlimited má "na starosti" neomezené kategorie, ::NewsTopics kategorie omezené na několik málo témat)

use 5.008;
use strict;
use warnings;
use utf8;


use Zpravostroj::Globals;
use Zpravostroj::ManualCategorization::ManualCategorization;

use Encode;

use YAML::XS qw(Load Dump);

my @categories = qw(Politika_domácí
Politika_svět
Ekonomie_domácí
Ekonomie_svět
Krimi_domácí
Krimi_svět
Bulvár_domácí
Bulvár_svět
Kultura_domácí
Kultura_svět
Studium_domácí
Studium_svět
Věda_d
Věda_s
Technika-d
Technika_s
Další_d
Další_s
Války_s 
Počasí_s
Počasí_d
sport_d
sport_s);

#Vrací všechny kategorie
sub get_possible_categories {
	return @categories;
}



#Vezme náhodný článek
#...tohle je trochu nezvyklé a zaslouží si vysvětlení.
#Nejdříve jsem totiž zatřizoval "neomezeným" způsobem - a až poté jsem v rámci experimentu zkusil tento přístup (omezená témata).

#Jelikož jsem ale chtěl mít množinu článků stejnou, udělal jsem to tak, že místo náhodného výběru článků se tady vybírá
#ze článků, které byly zatřízeny do "neomezených" kategorií, ale ještě nebyly zatřízeny do "omezených"

#(tj. ano, předpokládá se, že nejdříve se vyberou "neomezené" kategorie, a až potom se bude zatřizovat tady)

sub get_random_article {
	
	#drive @arr
	my @unlimited_done = (<data/user_categories/*>);
	
	my @newstopics_done = (<data/user_categories_topics/*>);
	
	#hash jenom s ID clanku
	my %newstopics_done_hash = map {/data\/user_categories_topics\/(.*)$/; ($1=>undef)} @newstopics_done;
	
	
	#vyberu ty, co jsou v unlimited_done, co nejsou v newstopics_done
	#tj. ty, ktere uz jsou ohodnocene unlimited, ale nejsou newstopic
	my @articles_to_select = grep { 
		/data\/user_categories\/(.*)$/;
		my $article_id = $1; 
		!exists $newstopics_done_hash{$article_id}
	} @unlimited_done;
	
	if (!scalar @articles_to_select) {
		die "Nemam uz dalsi.";
	}
	
	#nahodne vyberu z pole
	my $rand = $articles_to_select[int(rand(scalar @articles_to_select))];
	
	#Z pole osekam zacatky
	$rand =~ s/data\/user_categories\///;

	#a vratim article
	return  Zpravostroj::AllDates::get_from_article_id($rand);
}



#Přidá článek do 1 kategorie
#(pokud by mu jich přišlo víc, tak zemře)
sub add_article_to_categories {
	my $article_id = shift;
	my $categories = shift;
	
	Zpravostroj::ManualCategorization::ManualCategorization($article_id, $categories, 1, "data/user_categories_topics/" );
}



#vratim kategorie na clanek

sub get_article_categories {
	
	#ID článku (datum-číslo)
	my $article_id = shift;
	
	return Zpravostroj::ManualCategorization::ManualCategorization::get_article_categories
		($article_id, "data/user_categories_topics/");
}


#vratim vsechny clanky
sub get_articles {
		
	return Zpravostroj::ManualCategorization::ManualCategorization::get_articles("data/user_categories_topics");
}




1;