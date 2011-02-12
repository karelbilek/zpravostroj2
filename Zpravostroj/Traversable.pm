package Zpravostroj::Traversable;


use Moose::Role;

use Zpravostroj::Forker;
use Zpravostroj::Globals;

requires '_get_traversed_array';
requires '_get_object_from_string';
requires '_after_traverse';

has '_last_accessed' => (
	is => 'rw',
	isa=> 'Str'
);

sub traverse(&$) {
	my $s = shift;
	my $subref = shift;
	my $size = shift;
	
	my %opts = @_;
	
	my $forker = $size? new Zpravostroj::Forker(size=>$size, shut_up=>1) : undef;

	say "pred get traversed array" unless $opts{shut_up};
	my @array = $s->_get_traversed_array();
	
	say "array je velky ",scalar @array unless $opts{shut_up};
	for my $str (@array) {
		say "str $str" unless $opts{shut_up};
		
		my $big_subref = sub {
			
			my $obj = $s->_get_object_from_string($str);
			
			if (defined $obj) {
				say "trversable - Pred subr. $str" unless $opts{shut_up};
				my @res = $subref->($obj, $str);
				
				say "trversable - po subr." unless $opts{shut_up};

				$s->_after_traverse($str,$obj, @res);
			
				say "trversable - po after traverse" unless $opts{shut_up};

			} 
			
			say "trversable - KONCIM SUBRUTINU!!!!" unless $opts{shut_up};
		};
		if ($size) {
			$forker->run($big_subref);
		} else {
			$big_subref->();
		}
	}
	if (scalar @array) {
		$s->_last_accessed($array[-1]);
	}
	if ($size) {
		say "cekam na forker..." unless $opts{shut_up};
		$forker->wait();
		say "done" unless $opts{shut_up};
	}
}

1;