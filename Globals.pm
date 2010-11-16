package Globals;

use base 'Exporter';

our @EXPORT = qw(@todelete $not_beginning $min_article_count_per_day compare_dates get_date_from_file undump_bz2 dump_bz2 undump_bz2_new dump_bz2_new);

our @todelete = qw(strong b span a);
our $not_beginning="[Pp][Rr][aA][hH][aA]";
our $min_article_count_per_day = 8;


use Data::Dumper;
use IO::Uncompress::Bunzip2;
use IO::Compress::Bzip2;

use Scalar::Util qw(blessed reftype);
use YAML::XS;

use 5.010;

sub dump_bz2 {
	my $path = shift;
	my $ref = shift;
	
	my $z = IO::Compress::Bzip2->new ($path);
	
	print $z Dumper($ref);
	
	close($z);
}

sub undump_bz2 {
	my $path = shift;
	if (!-e $path) {
		say "AAAAAA";
		return undef;
	}
	my $z = IO::Uncompress::Bunzip2->new($path);

	

	
	my $dumped = join ("", <$z>);
	close($z);
	my $VAR1;
	
	
	eval($dumped);
	
	
	return $VAR1;
}


sub dump_bz2_new {
	my $path = shift;
	my $ref = shift;
	
	my $z = IO::Compress::Bzip2->new ($path);
	if (!$z) {
		die "Cannot create BZ2, dying!";
	}
	
	my $to_dump;
	if (blessed $ref and $ref->can("pack")) {
		
		$to_dump = $ref->pack;
	} else {
		
		$to_dump = $ref;
		
	}
	
	
	print $z Dump($to_dump);
	
	close($z);
}

sub undump_bz2_new {
	my $path = shift;
	if (!-e $path) {
		return undef;
	}
	my $z = IO::Uncompress::Bunzip2->new($path);

	

	
	my $dumped = join ("", <$z>);
	close($z);
	
	my $v = Load($dumped);
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
	
}


1;