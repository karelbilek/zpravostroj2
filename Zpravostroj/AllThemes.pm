package Zpravostroj::AllThemes;
use warnings;
use strict;

use Zpravostroj::Globals;
use Zpravostroj::AllDates;

sub save {
	my $ad = new Zpravostroj::AllDates;
	my %w = $ad->get_all_themes;
	mkdir("data/");
	mkdir("data/allthemes/");
	
	dump_bz2("data/allthemes/top_themes.bz2", \%w);
}

sub get_all {
	return undump_bz2("data/allthemes/top_themes.bz2");
}

sub get_sorted {
	my $top = undump_bz2("data/allthemes/top_themes.bz2");
	my $c = shift;
		
	my @r_themes = values %$top;
	
	@r_themes = sort {$b->importance <=> $a->importance} @r_themes;
	
	if (! defined $c) {
		return @r_themes;
	} else {
		return @r_themes[0..$c];
	}
}

1;