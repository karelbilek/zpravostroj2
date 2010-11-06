package Word;

use Types;
use Moose;
use MooseX::StrictConstructor;




has 'lemma' => (
	is => 'ro',
	predicate => 'has_lemma',
	isa => 'Lemma',
	coerce => 1
);

has 'form' => (
	is => 'ro',
	required => 1,
	isa => 'Str'
);

has 'named_entity' => (
	is => 'ro',
	isa => 'Bool',
	default => 0
);

sub is_meaningful {
	my $s = shift;
	if ($s->lemma ne '') {
		return 1;
	} else {
		return 0;
	}
}

#lze zadat i all_named misto named_entity
#lze zadat i pouze "form"
around BUILDARGS => sub {
	my $orig  = shift;
    my $class = shift;
	my %hash;
	if (@_==0) {
		return $class->$orig(@_);
	} elsif (ref $_[0]) {
		%hash = %{$_[0]};
	} elsif (@_==1) {
		return $class->$orig(form=>$_[0]);
	} else {
		%hash = @_;
	}
	if (!exists $hash{'lemma'} or !exists $hash{'all_named'}) {
		return $class->$orig(@_);
	} else {
		my $is = exists $hash{'all_named'}{$hash{'lemma'}};
		delete $hash{'all_named'};
		$hash{'named_entity'}=$is;
		return $class->$orig(\%hash);
	}
};
1;

