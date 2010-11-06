package Experiment;

use Moose;
use Moose::Util::TypeConstraints;


subtype 'K'
	=> as 'Str';
	
coerce 'K'
	=> from 'Str'
	=> via {
		s/^([^_]*).*$/$1/;
		s/ +$//;
		lc;
	};
	
has 'k' => (
	is => 'ro',
	isa => 'K',
	coerce => 1
);

1;
package main;

my $exp = new Experiment(k=>"abcd_efgh");
print $exp->k."\n";