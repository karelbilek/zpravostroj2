package Zpravostroj::InfoBaden;


use Zpravostroj::AllDates;
use Zpravostroj::Globals;
use Zpravostroj::OutCounter;

use warnings;
use strict;


use utf8;

use Text::Unaccent;

binmode STDOUT, ":utf8";

sub split_na_alphanum {
	my $what = shift;
	
	my @res;
	while ($what=~/\P{IsAlnum}/) {
		$what=~/^(\p{IsAlnum}*)(\P{IsAlnum}+)(.*)$/;
		if ($1) {
			push @res, $1;
		}
		push @res, $2;
		$what = $3;
	}
	push (@res, $what) if $what;
	return @res;
	
}

sub word_to_hash {
	my ($word, $hash) = @_;
	
	my @words = split(/\s+/, $word);
	
	@words = map {split_na_alphanum($_)} @words;
	
	@words = ("ZACATEK_STRINGU", @words, "KONEC_STRINGU");
	
	
	my $previous = undef;

	for my $word (@words) {
		if ($previous and $word) {
			my $joined = $previous."_ODDELOVAC_".$word;
			$hash->{$joined}++;
		}
		
		$previous = $word;
	}

}

sub serad_znova {
	my $titlesy =new Zpravostroj::OutCounter(name=>"titlesy", delete_on_start=>0);
	$titlesy->count_and_sort_it;
	my $obsahyf = new Zpravostroj::OutCounter(name=>"obsahyf", delete_on_start=>0);
	$obsahyf->count_and_sort_it;
	
}

sub traverzuj {
	

	
	my $ad=new Zpravostroj::AllDates();
	say "tuto";
	
	my $titlesy = new Zpravostroj::OutCounter(name=>"titlesy");
	
#	my $obsahyf = new Zpravostroj::OutCounter(name=>"obsahyf");

	$ad->traverse(sub {
		say "wtf";
		my $d = shift;
		
		my %titles;
#		my %obsahy;
		
		$d->traverse(sub{
			my $a = shift;
			my $title = $a->title_without_bullshit();
			if ($title =~ /\|/) {
				my @titly = split(/\s*\|\s*/, $title);
				if ($titly[0]!~/\.cz/) {
					$title = $titly[0];
				} else {
					$title = $titly[1];
				}
			}
			
			word_to_hash($title, \%titles);
			word_to_hash($a->article_contents, \%obsahy);
			
		}, 0);
		
		$titlesy->add_hash(\%titles);
		
		$obsahyf->add_hash(\%obsahy);
		
	},6);
	
	$titlesy->count_and_sort_it;
	$obsahyf->count_and_sort_it;


}

1;
