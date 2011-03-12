package Zpravostroj::UserTagged;

use 5.008;
use strict;
use warnings;
use utf8;
use encoding 'utf8';


use Zpravostroj::Tasks;
use Zpravostroj::Globals;

use Encode;

use YAML::XS qw(Load Dump);


sub get_possible_marks {
	my $path =  "data/user_allmarks/allmarks.yaml";

	if (!-e  $path) {
		return ();
	} else {
		open my $if, "<:utf8", $path;
		my $istring = join ("", <$if>);
		close($if);
		my $hash = YAML::XS::Load( $istring);
		delete $hash->{"prázdný článek"};
		my @all = sort {$hash->{$b} <=>$hash->{$a}} keys %$hash;
		return @all;
	}
}

sub add_possible_marks {
	my @list = @_;
	my %hash;
	my $path =  "data/user_allmarks/allmarks.yaml";
	if (-e $path) {
		open my $if, "<:utf8", $path;
		my $istring = join ("", <$if>);
		close($if);
		my $loadhash = YAML::XS::Load( $istring);
		%hash = %$loadhash;
	}
	
	for (@list) {
		$hash{$_}++;
	}
	my $s = YAML::XS::Dump(\%hash);
	
	open my $of, ">:utf8", $path;
	print $of $s;
	
	close $of;
}

sub get_user_done {
	my $person = shift;
	if (!-e "data/user_done/".$person) {
		return 0;
	} else {
		open my $if, "<:utf8", "data/user_done/".$person or die $!;
	
		my $num = <$if>;
		chomp($num);
		close $if;
		return $num;
	}
}

sub set_user_done {
	my $person = shift;
	my $how = shift;
	
	open my $of, ">:utf8", "data/user_done/".$person or die $!;
	print $of $how;
	close $of;
	
}

sub mark_article {
	my $article = shift;
	my $person = shift;
	my $themes = shift;

	my @themes_array = split(/(\r|\n)+/,$themes);
	@themes_array = grep {!/^\s*$/} @themes_array;
	
		
	{
		open my $of, ">>:utf8", "data/usermarks/".$article or die $!;
	
		print $of "PERSON:".$person."\n".(join ("\n", @themes_array))."\n";
		close $of;
	}
	add_possible_marks(@themes_array);
	
	my $num = get_user_done($person);
	set_user_done($person, $num + 1);
	
}


sub get_tuples {
	for my $filename (<data/usermarks/*>) {
		my $articlename = $filename;
		$articlename =~ s/data\/usermarks\///;
		
		
	}
}

1;