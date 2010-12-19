package Globals;

use base 'Exporter';

our @EXPORT = qw(@todelete $not_beginning $min_article_count_per_day compare_dates get_date_from_file undump_bz2 dump_bz2 say);

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

sub dump_bz2 {
	my $path = shift;
	my $ref = shift;
	
	my $z = IO::Compress::Bzip2->new ($path);
	if (!$z) {
		say "Cannot create BZ2 with path $path!";
		MyTimer::count_error("Cannot create");
		return;
	}
	
	my $to_dump;
	if (blessed $ref and $ref->can("pack")) {
		
		$to_dump = $ref->pack;
	} else {
		
		$to_dump = $ref;
		
	}
	
	MyTimer::start_timing("dump");
	my $w = Dump($to_dump);
	MyTimer::start_timing("print");
	print $z $w;
	
	MyTimer::start_timing("close_out");
	close($z);
	MyTimer::stop_timing();
}


sub undump_bz2 {
	my $path = shift;
	if (!-e $path) {
		return undef;
	}
	my $z = IO::Uncompress::Bunzip2->new($path);

	

	MyTimer::start_timing("join read");
	
	my $dumped = join ("", <$z>);
	
	MyTimer::start_timing("close_in");
	close($z);
	
	my $v;
	MyTimer::start_timing("load");
	
	eval {$v = Load($dumped);};
	
	MyTimer::start_timing("load_after");
	
	
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
	
	
	if (reftype $v ne "HASH") {
		return $v;
	} else {
		if (exists $v->{"__CLASS__"}) {
			my $class = $v->{"__CLASS__"};
			return $class->unpack($v); 
		} else {
			return $v;
		}
	}
	MyTimer::stop_timing();
	
	
}


1;