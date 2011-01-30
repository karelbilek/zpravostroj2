package Zpravostroj::AllDates;

use Zpravostroj::Globals;
use Moose;
use Date;

with 'Zpravostroj::Traversable';

sub _get_traversed_array {
	shift;
	
	if (!-d "data" or !-d "data/articles") {
		say "Tak nic, no.";
		return ();
	} else {
		my @res;
		for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/*>) {
			my $year = get_last_folder($_);
			
			for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/$year/*>) {
				my $month = get_last_folder($_);
				for (sort {get_last_folder($a)<=>get_last_folder($b)} <data/articles/$year/$month/*>) {
					my $day = get_last_folder($_);
					push(@res, $year."-".$month."-".$day);
				}
			}
		}
		return @res;
	}
}

sub _get_object_from_string {
	shift;
	return Date::get_from_string(shift);
}

sub _after_traverse{}


__PACKAGE__->meta->make_immutable;


1;