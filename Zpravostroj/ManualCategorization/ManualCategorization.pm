package Zpravostroj::ManualCategorization::ManualCategorization;
#Modul "nadrazeny" ::Unlimited a ::NewsTopics
#(neni to nadrazena trida, protoze ::Unlimited a ::NewsTopics nejsou tridy)

use 5.008;
use strict;
use warnings;
use utf8;

use Zpravostroj::Globals;

#Označí jeden článek více kategoriemi
sub add_article_to_categories {
	
	#ID toho článku
	my $article_id = shift;

	#všechny kategorie pohromadě
	my $categories = shift;
	
	#je povolena pouze 1 kategorie?
	my $just_one_category = shift;
	
	#Adresář.
	my $dir = shift;
	
	#Co udělat potom.
	my $subroutine = shift;

	#rozseká je na jednotlivá slova, vyřadí prázdné nesmysly
	my @categories_array = split(/(\r|\n)+/,$categories);
	@categories_array = grep {!/^\s*$/} @categories_array;
	
	if ( $just_one_category and (scalar @categories_array > 1)) {
		die "Size of topic categories shouldn't be >1";
	}
	
	#Do souboru data/user_categories/ID článku dá prostě přímo ty kategorie, 1 na řádek
	{
		my $address = $dir.$article_id;
		open my $of, ">>:utf8", $address or die $!." - chyba pri otevirani $address";
		
		print $of (join ("\n", @categories_array))."\n";
		close $of;
	}
	
	if ($subroutine) {
		$subroutine->(@categories_array);
	}
	
}

#Vrátí kategorie k danému článku
sub get_article_categories {
	
	#ID článku (datum-číslo)
	my $article_id = shift;
	
	my $dir = shift;
	
	my $filename = $dir.$article_id;
	
	if (!-e $filename) {
		return undef;
	}
	open my $if, "<:utf8", $filename or die $!." - chyba pri otevirani ".$filename;
		#padat by to nemělo, na existenci to testuju
		
	
	my @categories;
	while (<$if>) {
		my $line = $_;
		
		#tohle PERSON je tam kvůli tomu, že v předchozí verzi jsem ještě označoval, kdo přesně článek zatřídil
		#nakonec jsem to vyřadil, ale v souborech to zůstalo
		if ($line !~ /PERSON/) {
			chomp($line);
			push(@categories, $line);
		}
	}
	
	return @categories;
}

sub get_articles {
	
	my $dir = shift;
	
	my @res;
	
	
	for my $filename (<$dir/*>) {
		
		#Bere to podle názvů souborů...
		my $id = $filename;
		$id =~ s/$dir\///;
		
		#...které pak načte přes AllDates (takže je k nim "správně" přidán i date a číslo)
		my $article = Zpravostroj::AllDates::get_from_article_id($id);
		
		if (defined $article) {
			say "Definovany ".$id;
		} else {
			say "undefinovany ".$id;
		}
		
		push @res, $article;
	}
	
	
	return @res;
}

1;