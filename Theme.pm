package ThemeHash;
use strict;
use warnings;

use forks;
use forks::shared;

use Globals;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage;

has 'themes' => (
	is => 'rw',
	isa => 'HashRef[Theme]',
	default => sub { {} }
);

sub add_theme {
	my $s = shift;
	my $what = shift;
	
	my $themes = $s->themes;
	
	if (exists $themes -> { $what->lemma }) {
		my $p = $themes -> { $what->lemma } -> add_1;
		$themes -> {$what->lemma} = shared_clone($p);
	} else {
		my $p = $what->same_with_1;
		$themes -> {$what->lemma} = shared_clone($p);
	}
}

sub all_themes_lemmas {
	my $s = shift;
	
	return keys %{$s->themes}
}

sub get_theme {
	my $s = shift;
	my $lm = shift;
	return $s->themes->{$lm};
}

sub all_themes {
	my $s = shift;
	
	return values %{$s->themes}
}

sub all_themes_sorted {
	my $s = shift;
	my @all = $s->all_themes;
	return sort{$b->importance <=> $a->importance} @all;
}

sub top_themes {
	my $s = shift;
	my $n = shift;
	my @top = $s->all_themes_sorted;
	if (@top < $n) {
		return @top;
	} else {
		return @top[0..$n-1];
	}
}

__PACKAGE__->meta->make_immutable;

package Theme;

use strict;
use warnings;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;

with Storage;

has 'lemma' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'form' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'importance' => (
	is => 'ro',
	isa => 'Num',
	required => 1
);

sub to_string{
	my $s = shift;
	return $s->lemma."|".$s->form."|".$s->importance;
}

sub from_string {
	my $st = shift;
	$st=~/^(.*)\|(.*)\|(.*)$/;
	return new Theme(lemma=>$1, form=>$2, importance=>$3);
}


sub add_1{
	my $this = shift;
	return (new Theme(lemma=>$this->lemma, form=>$this->form, importance=>$this->importance+1));

}

sub add_another {
	my $this = shift;
	my $that = shift;
	return (new Theme(lemma=>$this->lemma, form=>$this->form, importance=>$this->importance+$that->importance));
	
}

sub same_with_1 {
	my $this = shift;
	
	return (new Theme(lemma=>$this->lemma, form=>$this->form, importance=>1));
	
}

sub join {
	my $this = shift;
	my $that = shift;
	$that->lemma =~ /^([^ ]*) ([^ ]*) (.*)$/;
	my $addlemma = $3;
	$that->form =~ /^([^ ]*) ([^ ]*) (.*)$/;
	my $addform = $3;
	
	return new Theme(lemma=>$this->lemma." ".$addlemma, form=>$this->form." ".$addform, importance=>(($this->importance + $that->importance)/2));
}

__PACKAGE__->meta->make_immutable;

1;
