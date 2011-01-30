package Zpravostroj::Traversable;


use Moose::Role;

use Zpravostroj::Forker;
use Zpravostroj::Globals;

requires '_get_traversed_array';
requires '_get_object_from_string';
requires '_after_traverse';

sub traverse(&$) {
	my $s = shift;
	my $subref = shift;
	my $size = shift;
	
	my $forker = $size? new Zpravostroj::Forker(size=>$size) : undef;

	say "pred get traversed array";
	my @array = $s->_get_traversed_array();
	
	say "array je velky ",scalar @array;
	for my $str (@array) {
		say "str $str";
		my $big_subref = sub {
			
			my $obj = $s->_get_object_from_string($str);
			
			if (defined $obj) {

				my @res = $subref->($obj);
				
				$s->_after_traverse(@res);
			
			} 
		};
		if ($size) {
			$forker->run($big_subref);
		} else {
			$big_subref->();
		}
	}
	if ($size) {
		say "cekam na forker...";
		$forker->wait();
		say "done";
	}
}

1;