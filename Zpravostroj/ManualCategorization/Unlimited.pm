package Zpravostroj::ManualCategorization::Unlimited;
#Modul, co "pomáhá" s manuální kategorizací.
#(::Unlimited má "na starosti" neomezené kategorie, ::NewsTopics kategorie omezené na několik málo témat)

use 5.008;
use strict;
use warnings;
use utf8;


use Zpravostroj::Globals;

use Encode;

use YAML::XS qw(Load Dump);


#Vrací všechny kategorie, seřazeny podle používanosti
sub get_possible_categories {
	
	#Jsou uloženy v YAMLu.
	my $path =  "data/user_possible_categories/all_categories.yaml";

	if (!-e  $path) {
		#na začátek
		return ("prázdný článek");
	} else {
		
		#Načte z YAMLu
		#(díky "bugu" YAMLu není ve skutečnosti nic uloženo v UTF-8, ale v něčem podivném.
		#Na mém serveru to funguje, ale na jiném serveru vůbec nemusí.
		#Kontaktoval jsem autora YAML::XS modulu, nevím, jestli vůbec odpoví.)
		open my $if, "<:utf8", $path;
		my $input_string = join ("", <$if>);
		close($if);
		my $categories = YAML::XS::Load( $input_string);
		
		
		#Ještě seřadí podle používanosti.
		my @all = sort {$categories->{$b} <=>$categories->{$a}} keys %$categories;
		
		
		return @all;
	}
	
}

#Přidá kategorie do možných (resp. zvýší počty)
sub _add_possible_categories {
	
	#co pridavam?
	my @categories_to_add = @_;
	
	#ten hash v tom souboru
	my %allcategories;

	my $path =  "data/user_possible_categories/all_categories.yaml";
	if (-e $path) {
		
		#Nacte hash ze souboru
		
		#(o YAMLu totéž, co o kus výše)
		
		open my $if, "<:utf8", $path;
		
		my $input_string = join ("", <$if>);
		close($if);
		
		my $input_hash = YAML::XS::Load( $input_string);
		%allcategories = %$input_hash;
	}
	
	#Pro každý, co mám přidat, ho tam přidám
	for (@categories_to_add) {
		$allcategories{$_}++;
	}
	
	#A zase to dumpnu do souboru
	my $s = YAML::XS::Dump(\%allcategories);
	
	open my $of, ">:utf8", $path;
	print $of $s;
	
	close $of;
}

#Označí jeden článek více kategoriemi
sub add_article_to_categories {
	
	my $article_id = shift;
	my $categories = shift;
	
	Zpravostroj::ManualCategorization::ManualCategorization::add_article_to_categories
		($article_id, $categories, 0, "data/user_categories/", \&_add_possible_categories);
	
	
}

#Vrátí kategorie k danému článku
#(tato metoda je volána hlavně zevnitř objektu Article v Article->unlimited_manual_tags())
sub get_article_categories {
	
	#ID článku (datum-číslo)
	my $article_id = shift;
	
	return Zpravostroj::ManualCategorization::ManualCategorization::get_article_categories
		($article_id, "data/user_categories/");
}

#Vrátí všechny články, co jsou označené (jako objekty Article)

sub get_articles {
		
	return Zpravostroj::ManualCategorization::ManualCategorization::get_articles("data/user_categories");
}


#Vrátí náhodný článek
#(volá get_random_article v AllDates, která pro rychlejší přístup tahá náhodné články ze seznamu článků v data/all_article_names)
sub get_random_article {
	return (new Zpravostroj::AllDates)->get_random_article();
}






1;