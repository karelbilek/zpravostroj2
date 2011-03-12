package Zpravostroj::Categorizer::Evaluator;

use warnings;
use strict;

use Zpravostroj::Globals;

use List::Util qw(shuffle);

sub chose_random_disjunct_subsets {
	my $first_portion = shift;
	
	my @arr = @_;
	
	my $size_of_first = int((scalar @arr) * $first_portion);
	
	@arr = shuffle(@arr);
	my @first = @arr[0..$size_of_first-1];
	my @second = @arr[$size_of_first..$#arr];
	
	return (\@first, \@second);
}

sub unique_size {
	my @arr = @_;
	my %w; @w{@arr}=();
	return scalar keys %w;
}

sub sets_complement_size {
	my $base = shift;
	my $subtracted = shift;
	
	my $res;
	
	my %complement = map {$_->undef} @$base;
	
	for my $subtracted_element (@$subtracted) {
		delete %complement{$subtracted_element};
	}
	
	return (scalar keys %complement);
}


sub evaluate {
	my $class = shift;
	
	my @arr = @_;
	
	my ($train, $eval) = chose_random_disjunct_subsets(0.9);
	
	my $categorizer = $class->new(@$train);
	
	my @to_tag = map {$_->{article}} @$eval;
	
	my @tagged = $categorizer->categorize(@to_tag);
	
	if (scalar @tagged != scalar @$eval) {
		die "Tagged and eval doesn't have the same size! :(";
	}
	
	my $original_tags_sum=0;
	my $categorizer_tags_sum = 0;
	
	my $wrong_tags_by_categorizer=0;
	my $missing_tags = 0;
	
	for my $i (0..$#tagged) {
		my $tagged_article = $tagged[$i];
		my $original_article = $eval->[$i];
		
		my @categorizer_tags = $tagged_article->{tags};
		my @original_tags = $original_article->{tags};
		
		$original_tags_sum += unique_size(@original_tags);
		$categorizer_tags_sum += unique_size(@categorizer_tags);
		
		$wrong_tags_by_categorizer += sets_complement_size(\@categorizer_tags, \@original_tags);
		$missing_tags += sets_complement_size(\@original_tags, \@categorizer_tags);
	}
	
	return ($wrong_tags_by_categorizer/ $categorizer_tags_sum, $categorizer_tags_sum/$original_tags_sum);
}