package Globals;

use base 'Exporter';

our @EXPORT = qw(@todelete $not_beginning $min_article_count_per_day compare_dates get_date_from_file undump_bz2 dump_bz2 say if_undef);

our @todelete = qw(strong b span a);
our $not_beginning="[Pp][Rr][aA][hH][aA]";
our $min_article_count_per_day = 8;

use IO::Uncompress::Bunzip2;
use IO::Compress::Bzip2;

use Scalar::Util qw(blessed reftype);
use YAML::XS;

use 5.008;


use forks;
sub say(@) {
	my @w = @_;
	my $d = join ("", threads->tid(), " - ", @w, "\n");
	print $d;
}

sub if_undef {
	my $what = shift;
	my $ifnull = shift;
	if (defined $what) {
		return $what;
	} else {
		return $ifnull;
	}
}

sub dump_bz2 {
	my $path = shift;
	my $ref = shift;
	
	my $exp_class = shift || "";
	
	
	#my $z = IO::Compress::Bzip2->new ($path);
	open my $z, "|bzip2 > $path";
	if (!$z) {
		say "Cannot create BZ2 with path $path!";
		return;
	}
	
	my $to_dump;
	if (blessed $ref and $ref->can("pack")) {
		$to_dump = $ref->pack;
	} else {
		
		$to_dump = $ref;
		
	}
	
	my $w = Dump($to_dump);
	print $z $w;
	
	close($z);
}


sub undump_bz2 {
	my $path = shift;
	if (!-e $path) {
		return undef;
	}
	my $exp_class = shift || "";
	my $z;
	$@=1;
	
	
	while($@) {
		eval {
			#$z = IO::Uncompress::Bunzip2->new($path);
			open $z, "bunzip2 -c $path |";
		};
		if ($@) {
			say "KURVA WTF chyba";
			say $@;
		}
	} 
	
	
	my $dumped;
	$@=1;
	while($@) {
		eval {
			$dumped = "";
			while (<$z>) {
				$dumped = $dumped.$_;
			}
			use Devel::Size qw(size);
			my $size = size($dumped);
		};
		if ($@) {
			say "2 KURVA WTF chyba";
			say $@;
		}
	}
	
	close($z);
	
	my $v;
	
	eval {$v = Load($dumped);};
	
	
	
	if ($@) {
		
		say "Chyba v undump_bz2.";
		say $@;
		return undef;
	}
	
	
	
	if (reftype $v ne "HASH") {
		
		return $v;
	} else {
		
		if (exists $v->{"__CLASS__"}) {
			
			my $class = $v->{"__CLASS__"};
			
			my $r = $class->unpack($v); 
			
			
			
			return $r;
		} else {
			
			
			return $v;
		}
	}
	
	
}


1;
