package Theme;

use forks;


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

1;
