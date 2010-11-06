package Theme;


use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;


has 'words' => (
	is => 'ro',
	isa => 'ArrayRef[Word]',
	required => 1
);

sub length {scalar(@{$_[0]->words})}

1;
