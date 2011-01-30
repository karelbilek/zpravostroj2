package Zpravostroj::Traversable;


use Moose:Role;

use Zpravostroj::Forker;

requires '_get_traversed_array';
requires '_get_object_from_string';
requires '_after_traverse';

sub traverse(&$) {
	my $s = shift;
	my $subref = shift;
	my $size = shift;
	
	my $forker = new Zpravostroj::Forker(size=>$THREADS_SIZE);

	my @array = $s->_get_traversed_array();
	
	for my $str (@array) {
		my $subref = sub {
			
			my $obj = $s->_get_object_from_string($str);
			
			if (defined $obj) {

			
				my $changed;
				@res = $subr->($obj);
				
				$s->_after_traverse(@res);
			
			} 
		};
	}
}
