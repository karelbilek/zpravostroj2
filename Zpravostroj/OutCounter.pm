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

sub resname {
	my $s = shift;
	return $s->name."_counted";
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
	
	open my $if, "<:utf8", $s->resname;
	
	for (<$if>) {
		/(.*)\t(.*)\n/;
		
		$res{$1} = $2;
	}
		
	close $if;
	return \%res;
}

sub add_hash {
	my $s = shift;
	
	my $hash = shift;
	
	while (!mkdir $s->lockname) {usleep(10000)}
	
	open my $of, ">>:utf8", $s->tempname;
	
	while (my ($word, $value) = each %$hash) {
		print $of $word."\t".$value."\n";
	}
	
	close $of;
	
	$s->counted(0);
	
	system("rm -r ".$s->lockname);
}

sub add_another {
	my $s = shift;
	my $another = shift;
	
	my $if;
	
	if ($another->counted) {
		open $if, "<:utf8", $another->resname;
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

sub count_it {
	my $s = shift;
	
	if (!$s->counted) {
		system("sort +0 -1 ".$s->tempname." > ".$s->sortname);
		
		open my $if, "<:utf8", $s->sortname;
		open my $of, ">:utf8", $s->resname;

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