package Zpravostroj::ManualCategorization::NewsTopics;

use 5.008;
use strict;
use warnings;
use utf8;
use encoding 'utf8';


use Zpravostroj::Globals;

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


sub add_article_to_categories {
	my $article = shift;
	my $person = shift;
	my $themes = shift;

	my @themes_array = split(/(\r|\n)+/,$themes);
	@themes_array = grep {!/^\s*$/} @themes_array;
	
	if (scalar @themes_array > 1) {
		die "Size of topic categories shouldn't be >1";
	}
		
	{
		open my $of, ">>:utf8", "data/user_categories_topics/".$article 
			or die $!."- chyba pri otevirani data/user_categories_topics/".$article;
	
		print $of ($themes_array[0])."\n";
		close $of;
	}
	
}



sub get_random_article {
	my @arr = (<data/user_categories/*>);
	
	my @oneword = (<data/user_categories_topics/*>);
	@oneword = map {/data\/user_categories_topics\/(.*)$/; $1} @oneword;
	my %oneword_hash = map {($_=>undef)} @oneword;
	
	@arr = grep {
		my $n=$_; 
		if (!/data\/user_categories\/(.*)$/) {
			die "not one user_category";
		}; 
		my $w = $1; 
		!exists $oneword_hash{$w}
	} @arr;
	
	if (!scalar @arr) {
		die "Nemam uz dalsi.";
	}
	my $rand = $arr[int(rand(scalar @arr))];
	
	$rand =~ s/data\/user_categories\///;

	return ( (new Zpravostroj::AllDates)->get_from_article_id($rand) , $rand );
}



sub get_article_categories {
	my $article_id = shift;
	
	my $filename = "data/user_categories_topics/".$article_id;
	
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
	
	
	my $dir = "data/user_categories_topics";
	
	
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