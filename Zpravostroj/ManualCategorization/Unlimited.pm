package Zpravostroj::ManualCategorization::Unlimited;

use 5.008;
use strict;
use warnings;
use utf8;
use encoding 'utf8';


use Zpravostroj::Globals;

use Encode;

use YAML::XS qw(Load Dump);

#Vrací všechny kategorie, seřazeny podle používanosti
sub get_possible_categories {
	my $path =  "data/user_possible_categories/all_categories.yaml";

	if (!-e  $path) {
		return ();
	} else {
		open my $if, "<:utf8", $path;
		my $istring = join ("", <$if>);
		close($if);
		my $hash = YAML::XS::Load( $istring);
		my @all = sort {$hash->{$b} <=>$hash->{$a}} keys %$hash;
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
		#Nejsem si jisty, jak jde dohromady Yaml a Unicode, tak to mam takhle
		
		#Nacte hash ze souboru
		
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
	my $s = YAML::XS::Dump(\%hash);
	
	open my $of, ">:utf8", $path;
	print $of $s;
	
	close $of;
}

#mark_article -> add_article_to_categories
#Označí jeden článek jednou kategorií
sub add_article_to_categories {
	
	#ID toho článku
	my $article_id = shift;

	#všechny kategorie pohromadě
	my $categories = shift;

	#rozseká je na jednotlivá slova, vyřadí prázdné nesmysly
	my @categories_array = split(/(\r|\n)+/,$categories);
	@categories_array = grep {!/^\s*$/} @categories_array;
	
	#Do souboru data/user_categories/
	{
		open my $of, ">>:utf8", "data/user_categories/".$article_id or die $!." - chyba pri otevirani data/user_categories/".$article_id;
		
		print $of (join ("\n", @categories_array))."\n";
		close $of;
	}
	
	#
	_add_possible_categories(@categories_array);
	
}



sub get_random_article {
	return ((new Zpravostroj::AllDates)->get_random_article());
}

sub get_article_categories {
	my $article_id = shift;
	
	my $filename = "data/user_categories/".$article_id;
	
	if (!-e $filename) {
		return undef;
	}
	open my $if, "<:utf8", $filename or die $!." - chyba pri otevirani ".$filename;
	
	my @categories;
	while (<$if>) {
		my $line = $_;
		
		if ($line !~ /PERSON/) {
			chomp($line);
			push(@tags, $line);
		}
	}
	
	return @categories;
}


sub get_articles {
	
	
	my $dir = "data/user_categories";
	
	
	my @res;
	
	for my $filename (<$dir/*>) {
		my $id = $filename;
		$id =~ s/$dir\///;
		
		my $article = (new Zpravostroj::AllDates)->get_from_article_id($id);
		
		push @res, $article;
	}
	
	
	return @res;
}

1;