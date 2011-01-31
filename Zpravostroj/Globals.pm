package Zpravostroj::Globals;
use base 'Exporter';
#pomocny modulik na vsechny funkce, co chci, aby byly videt vsude, ale nejsou samy o sobe prilis "chytre"
#plus pres to sdilim vsechny konstanty, co chci videt vsude

our @EXPORT = qw($SIMULTANEOUS_THREADS_TECTOSERVER $MIN_ARTICLES_PER_DAY_FOR_ALLWORDCOUNTS_INCLUSION $MINIMAL_USABLE_BZ2_SIZE undump_bz2 dump_bz2 say if_undef get_last_folder);

our $MIN_ARTICLES_PER_DAY_FOR_ALLWORDCOUNTS_INCLUSION = 8;

our $SIMULTANEOUS_THREADS_TECTOSERVER=10;

our $MINIMAL_USABLE_BZ2_SIZE = 3000;

use IO::Uncompress::Bunzip2;
use IO::Compress::Bzip2;

use Scalar::Util qw(blessed reftype);
use YAML::XS;

use forks;

use 5.008;

#v perlu 5.010 je vestavena funkce say, co automaticky prida \n na konec
#tak jsem si na ni zvyknul, ze kdyz jsem prechazel /kvuli ufallabu/ zpatky na 5.008, musel jsem si ji nadefinovat
#nakonec se mi to hodi, protoze jsem si k ni (aby se vubec daly thready hlidat) pridal na zacatek radku cislo threadu

use forks;
sub say(@) {
	my @w = @_;
	my $d = join ("", threads->tid(), " - ", @w, "\n");
	print $d;
}

#vrátí název posledního adresáře v celé adrese (tj. vše od posledního / do konce)
sub get_last_folder {
	my $w = shift;
	$w=~/\/([^\/]*)$/;
	return $1;
}

#tohle je zase nahrada operatoru // z perlu 5.010
#kdyz je prvni undef, vrati druhy, jinak prvni
sub if_undef {
	my $what = shift;
	my $ifnull = shift;
	if (defined $what) {
		return $what;
	} else {
		return $ifnull;
	}
}

#zjisti, jestli je nejaky string trida
sub isa_classname {
	my $what = shift;
	my $res;
	eval {$res = $what->isa("UNIVERSAL");};
	
	if ($@) {
		return 0;
	} else {
		return $res;
	}
}


#Vezme cestu a referenci na neco.
#Pokud neco je jenom blby skalar/hash/..., ulozi ho pres Dump
#pokud je to trida, co je Moose a "with Storage", ulozi si to pres ->pack a zdumpuje

#je vtipne, ze se muze stat, ze kdyz jsou nektere argumenty "lazy" tak se ve skutecnosti spousta veci odehraje tady,
#protoze az ->pack opravdu vola vsechny atributy. Ale ono to nicemu nevadi. Ale je dobre to vedet.

#bzip se nejdriv otevre do noveho souboru v .bz2 a az POTOM se presune jinam. Usetri to dost zbytecnych failu.
sub dump_bz2 {
	my $path = shift;
	my $ref = shift;
	
	my $exp_class = shift || "";
	
	my $tmpath = "/tmp/zstroj".threads->tid().".bz2";
	
	open my $z, "|bzip2 > $tmpath";
	if (!$z) {
		say "Cannot create BZ2 with path $path!";
		return;
	}
	
	my $to_dump;
	if (blessed $ref and $ref->can("pack")) {
		$to_dump = $ref->pack; #může trvat
	} else {
		
		$to_dump = $ref;
		
	}
	
	my $w = Dump($to_dump);
	print $z $w;
	
	close($z);
	system("mv $tmpath $path");
}



#Snazi se vzit soubor z dane cesty a neco s nim udelat.
#Pokud neexistuje -> undef.
#Pokud nejde cist bunzipem -> undef.
#Pokud existuje a je v nem neco, co nema __CLASS__ -> vrati to
#pokud existuje a je v nem neco, co ma __CLASS__ a ta trida existuje -> postavi ji pomoci Storage
#pokud existuje a je v nem neco, co ma __CLASS__ a ta trida neexistuje -> zkusi Zpravostroj::(ten nazev), protoze jsem 
	#dost trid takhle prejmenovaval

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
			say " WTF chyba";
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
			say "2 WTF chyba";
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
		
		deep_renamer($v);
		
		if (exists $v->{"__CLASS__"}) {
			
			my $class = $v->{"__CLASS__"};
			
			
			if (isa_classname($class)) {
				my $r = $class->unpack($v); 

				return $r;
			} else {
				return $v;
			}
			
		} else {
			return $v;
		} 
	}
	
	
}

#Mam tu 2 "prejmenovavaci" procedury
#MooseX::Storage nebo pres co to vlastne loaduju potrebuje __CLASS__ jako nazev tridy
#Já jsem ale svoje třídy všechny přejmenovával, abych se v nich vyznal
#jmenují se všechny Zpravostroj::něco

#tahle procedura projde celý hash a zjistí, jestli náhodou někde není blbý název, jestli je, tak ho předělá

sub deep_renamer {
	my $what = shift;
	if (exists $what->{"__CLASS__"}) {
		my $c = $what->{"__CLASS__"};
		if (!isa_classname($c) and isa_classname("Zpravostroj::$c")) {
			$what->{"__CLASS__"} = "Zpravostroj::$c";
		}
	} 
	for my $k (keys %$what) {
		if ($k ne "__CLASS__") {
			my $r = $what->{$k};
			if (reftype($r) eq 'HASH') {
				deep_renamer($r);
			}
			if (reftype($r) eq 'ARRAY') {
				deep_renamer_array($r);
			}
		}
	}
}

sub deep_renamer_array {
	my $what = shift;
	for my $r (@$what) {
		if (reftype($r) eq 'HASH') {
			deep_renamer($r);
		}
		
		if (reftype($r) eq 'ARRAY') {
			deep_renamer_array($r);
		}
		
	}
}

1;
