package Zpravostroj::Globals;
use base 'Exporter';
#pomocny modulik na vsechny funkce, co chci, aby byly videt vsude, ale nejsou samy o sobe prilis "chytre"
#plus pres to sdilim vsechny konstanty, co chci videt vsude


mkdir "tmp";
if (!-d "tmp") {
	die "tmp/ cannot be created";
}

our @EXPORT = qw(%FORKER_SIZES $MINIMAL_USABLE_BZ2_SIZE $FREQUENCY_THEMES_SIZE $STOP_THEMES_SIZE $TRIAL_COUNT $TF_IDF_THEMES_SIZE cleanup_lemma undump_bz2 dump_bz2 say get_last_folder @banned_phrases );


use utf8;
our @banned_phrases = ("Publikování nebo jakékoliv jiné formy dalšího šíření obsahu serveru Blesk.cz jsou bez písemného souhlasu Ringier Axel Springer CZ a.s., zakázány.", "Blesk.cz využívá zpravodajství z databází ČTK, jejichž obsah je chráněn autorským zákonem. Přepis, šíření či další zpřístupňování tohoto obsahu či jeho části veřejnosti, a to jakýmkoliv způsobem, je bez předchozího souhlasu ČTK výslovně zakázáno.", "Připomínky a tipy pište na", "© 2001 - 2010 Copyright  Ringier Axel Springer CZ a.s. a dodavatelé obsahu. ISSN 1213-8991", "Publikování nebo jakékoliv jiné formy dalšího šíření obsahu serveru Blesk.cz jsou bez písemného souhlasu Ringier ČR, a. s., zakázány.");

our %FORKER_SIZES;
$FORKER_SIZES{TECTOSERVER}=10;
$FORKER_SIZES{ARTICLE_CREATION}=10;
$FORKER_SIZES{IDF_UPDATE_DAYS}=2;
$FORKER_SIZES{IDF_UPDATE_ARTICLES}=10;


$FORKER_SIZES{TF_IDF_DAYS}=2;
$FORKER_SIZES{TF_IDF_ARTICLES}=5;


$FORKER_SIZES{REAL_ARTICLE_NAMES}=15;

$FORKER_SIZES{LEMMAS_ARTICLES}=15;
$FORKER_SIZES{LEMMAS_DAYS}=3;

$FORKER_SIZES{F_THEMES_ARTICLES}=15;
$FORKER_SIZES{F_THEMES_DAYS}=3;


$FORKER_SIZES{STOP_THEMES_DAYS}=3;
$FORKER_SIZES{STOP_THEMES_ARTICLES}=30;

$FORKER_SIZES{NEWS_SOURCE_DAYS}=3;
$FORKER_SIZES{NEWS_SOURCE_ARTICLES}=15;

our $TRIAL_COUNT = 10;
our $MINIMAL_USABLE_BZ2_SIZE = 3000;
our $FREQUENCY_THEMES_SIZE = 10;
our $STOP_THEMES_SIZE = 10;
our $TF_IDF_THEMES_SIZE = 20;

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

my $shutup=0;
sub _shut_up {
	$shutup=1;
}

sub say(@) {
	my @w = @_;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	my $stmp = sprintf "%02d. %02d. %4d %02d:%02d:%02d", $mday, $mon+1, $year+1900,$hour,$min,$sec;
	
	
	my $d = join ("", threads->tid(), " - ", $stmp, " - ", @w, "\n");
	print $d unless $shutup;
}

sub cleanup_lemma {
	my $w = shift;
	$w=~s/^([^\-\.,_;\/\\\^\?:\(\)!"]*).*$/$1/;
	$w=~s/^([\-\.,_;\/\\\^\?:\(\)!"]*)$//;
	$w=~s/ +$//;
	$w = lc($w);
	
	return $w;
}

#vrátí název posledního adresáře v celé adrese (tj. vše od posledního / do konce)
sub get_last_folder {
	my $w = shift;
	$w=~/\/([^\/]*)$/;
	return $1;
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
#Pokud neco je jenom obycejny skalar/hash/..., ulozi ho pres Dump
#pokud je to trida, co je Moose a "with Storage", ulozi si to pres ->pack a zdumpuje

#je vtipne, ze se muze stat, ze kdyz jsou nektere argumenty "lazy" tak se ve skutecnosti spousta veci odehraje tady,
#protoze az ->pack opravdu vola vsechny atributy. Ale ono to nicemu nevadi. Ale je dobre to vedet.

#bzip se nejdriv otevre do noveho souboru v .bz2 a az POTOM se presune jinam. Usetri to dost zbytecnych failu.
sub dump_bz2 {
	my $path = shift;
	my $ref = shift;
	
	
	
	my $tmpath = "tmp/zstroj".threads->tid().".bz2";
	
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

sub most_frequent_lemmas {
	open my $f, "<:utf8", "data/most_frequent_lemmas" or die "No such file most_frequent_lemmas";
	my @arr = <$f>;
	chomp(@arr);
	my %res = map {($_=>undef)} @arr;
	return %res;
}

#Snazi se vzit soubor z dane cesty a neco s nim udelat.
#Pokud neexistuje -> undef.
#Pokud nejde cist bunzipem -> undef.
#Pokud existuje a je v nem neco, co nema __CLASS__ -> vrati to
#pokud existuje a je v nem neco, co ma __CLASS__ a ta trida existuje -> postavi ji pomoci Storage

sub undump_bz2 {
	my $path = shift;
	if (!-e $path) {
		return undef;
	}
	
	my $z; 
	$@=1;
	
	
	while($@) {
		eval {
			open $z, "bunzip2 -c $path |";
		};
		#umyslne neumiram, nejaka chyba se prihodi, pokud oteviram desitky tisic bzipu po sobe
		if ($@) {
			say "File chyba";
			say $@;
		}
	} 
	
	#do dumped se bude pridavat string
	my $dumped;
	$@=1;
	while($@) {
		eval {
			$dumped = "";
			while (<$z>) {
				$dumped = $dumped.$_;
			}
			
		};
		if ($@) {
			say "Nacitaci chyba";
			say $@;
		}
	}
	
	close($z);
	
	my $v;
	
	eval {$v = Load($dumped);};
	
	
	
	if ($@) {
		
		say "Chyba v Load v undump_bz2.";
		say $@;
		return undef;
	}
	
	
	
	if (reftype $v ne "HASH") {
		
		return $v;
	} else {
		
			#pokud se zda, ze je to trida
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

1;
