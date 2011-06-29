package Zpravostroj::OutCounter;

use 5.008;

use warnings;
use strict;
use Time::HiRes qw( usleep);

use Moose;
use Zpravostroj::Globals;

has 'name' => (
	is=>'ro',
	required=>'1',
	isa=>'Str'
);


has 'counted' => (
	is => 'rw',
	isa => 'Bool',
	default=> '0'
);

has 'delete_on_start' => (
	is => 'rw',
	isa => 'Bool',
	default=> '1'
);

sub tempname {
	my $s = shift;
	return $s->name."_temp";
}

sub lockname {
	my $s = shift;
	return $s->name."_lock";
}

sub sortname {
	my $s = shift;
	return $s->name."_sorted";
}

sub countedname {
	my $s = shift;
	return $s->name."_counted";
}

sub sorted_by_frequencyname {
	my $s = shift;
	return $s->name."_counted_sorted_by_frequency";
}

sub BUILD {
	my $s = shift;
	
	system("rm ".$s->tempname) if ((-e $s->tempname) and $s->delete_on_start);

}

sub return_counted {
	my $s = shift;
	
	my $should_count = int(`if [ data/idf/idf_counted -ot data/idf/idf_temp ]; then echo "1"; else echo "0";fi;`);
	
	if ((!$s->counted) and ($should_count)) {
		$s->count_it();
	}
		
	my %res;
	
	open my $if, "<:utf8", $s->countedname;
	
	for (<$if>) {
		/(.*)\t(.*)\n/;
		
		$res{$1} = $2;
	}
		
	close $if;
	return \%res;
}

sub add_hash {
	say "Na zacatku.";
	my $s = shift;
	
	my $hash = shift;
	
	say "Shiftnul jsem hash. Jdu se pokouset o zalozeni.";
	
	while (!mkdir $s->lockname) {
		say "Zakladam neuspesne, spim.";
		usleep(10000);
	}
	
	say "Zalozeno.";
	
	open my $of, ">>:utf8", $s->tempname;
	
	say "Otevreno. Jdu vypisovat. Velikost je ".scalar (keys %$hash);
	
	while (my ($word, $value) = each %$hash) {
		print $of $word."\t".$value."\n";
	}
	
	
	close $of;
	
	say "Dopsano, zavreno.";
	
	$s->counted(0);
	
	system("rm -r ".$s->lockname);
	say "Smazano, hotovo.";
}

sub add_another {
	my $s = shift;
	my $another = shift;
	
	my $if;
	
	if ($another->counted) {
		open $if, "<:utf8", $another->countedname;
	} else {
		open $if, "<:utf8", $another->tempname;
	}
	
	while (!mkdir $s->lockname) {usleep(10000)}
	
	open my $of, ">>:utf8", $s->tempname;
	
	while (<$if>) {
		print $of $_;
	}
	close $of;
	close $if;
	
	system("rm -r ".$s->lockname);
	
}

sub count_and_sort_it {
	my $s = shift;
	$s->count_it;
	
	system("sort -n -r -T tmp/ +1 -2 ".$s->countedname." > ".$s->sorted_by_frequencyname);
	
}

sub count_it {
	my $s = shift;
	
	if (!$s->counted) {
		system("sort -T tmp/ +0 -1 ".$s->tempname." > ".$s->sortname);
		
		open my $if, "<:utf8", $s->sortname;
		open my $of, ">:utf8", $s->countedname;

		my $last="";
		my $sofar = 0;
		for (<$if>) {
			/(.*)\t(.*)\n/;
			if ($1 eq $last) {
				$sofar += $2;
			} else {
				print $of $last."\t".$sofar."\n" if ($last ne "");
				$sofar = $2;
			}
			$last = $1;
		}
		
		close $if;
		close $of;
		
	}
	$s->counted(1);
}

1;