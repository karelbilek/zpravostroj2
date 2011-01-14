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

use MyTimer;


sub say(@) {
	my @w = @_;
	for (@w) {print $_}
	print "\n";
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
	
	MyTimer::start_timing("creating bz2 $exp_class");
	
	my $z = IO::Compress::Bzip2->new ($path);
	#open my $z, "|bzip2 > $path";
	if (!$z) {
		say "Cannot create BZ2 with path $path!";
		MyTimer::count_error("Cannot create");
		return;
	}
	
	my $to_dump;
	if (blessed $ref and $ref->can("pack")) {
		MyTimer::start_timing("pack $exp_class");
		$to_dump = $ref->pack;
	} else {
		
		$to_dump = $ref;
		
	}
	
	MyTimer::start_timing("dump $exp_class");
	my $w = Dump($to_dump);
	MyTimer::start_timing("print $exp_class");
	print $z $w;
	
	MyTimer::start_timing("close_out $exp_class");
	close($z);
	MyTimer::stop_timing();
}


sub undump_bz2 {
	my $path = shift;
	if (!-e $path) {
		return undef;
	}
	my $exp_class = shift || "";
	my $z;
	$@=1;
	
	MyTimer::start_timing("reading bz2 $exp_class");
	
	while($@) {
		eval {
			$z = IO::Uncompress::Bunzip2->new($path);
			#open $z, "bunzip2 -c $path |";
		};
		if ($@) {
			say "KURVA WTF chyba";
			say $@;
		}
	} 
	
	MyTimer::start_timing("join read $exp_class");
	
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
	
	MyTimer::start_timing("close_in $exp_class");
	close($z);
	
	my $v;
	MyTimer::start_timing("load $exp_class");
	
	eval {$v = Load($dumped);};
	
	MyTimer::start_timing("load_after_wtf1 $exp_class");
	
	
	if ($@) {
		if ($@ =~ /Invalid leading UTF-8 octet/) {
			
			MyTimer::count_error("Invalid leading UTF-8 octet");
		} else {
			MyTimer::count_error("Other YAML error");
		}
		say "Chyba v undump_bz2.";
		say $@;
		return undef;
	}
	MyTimer::start_timing("load_after_wtf2 $exp_class");
	
	
	
	if (reftype $v ne "HASH") {
		MyTimer::start_timing("load_after_wtf3 $exp_class");
		
		return $v;
	} else {
		MyTimer::start_timing("load_after_wtf4 $exp_class");
		
		if (exists $v->{"__CLASS__"}) {
			MyTimer::start_timing("load_after_wtf5 $exp_class");
			
			my $class = $v->{"__CLASS__"};
			
			MyTimer::start_timing("unpacking $exp_class");
			my $r = $class->unpack($v); 
			
			MyTimer::start_timing("load_after_wtf6 $exp_class");
			
			
			return $r;
		} else {
			MyTimer::start_timing("load_after_wtf7 $exp_class");
			
			
			return $v;
		}
	}
	
	
}


1;
