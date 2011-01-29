package Zpravostroj::TectoServer;
#package, co spusti TectoMT a funguje jako server, kteremu se posilaji texty,
#on je zpracuje a posle zpatky

#"Opacny" modul je TectoClient 

#Je to delane tak, ze POCITAM s tim, ze to pobezi v samostatnem threadu (resp. forku)
#tj. mam tu napr. globalni promenne, co ale inicializuji az kdyz je potrebuji
#inicializuji se az v extra threadu, co potom zabiju (ja totiz vubec neverim perlimu garbage collectoru a resim uvolnovani
#	pameti - mozna hloupe - pres forky a zabijeni, pamet se tak uvolni hned, jak ji nechci)
#forky == modul forks

#vypada to tak, ze fork se pusti, spusti se run(), ta si jeste pomoci forkeru pusti na kazdy prijmuty socket
#vlastni fork, v kazdem z nich bezi tectomt zvlast a vraci vysledky, necha se to vsechno dobehnout,
#pak prijde SIGUSR1, coz je "signal" pro to, aby fronta dobehla a thread sam sebe zabil.

#------
#Proc to delat pres server?
#No, to je otazka. :)

#Jednak jde o zjednoduseni - ze "hlavni" thread nemusi resit veci ohledne TectoMT a je to hezky "zapouzdrene" tady. Paklize uz TectoMT nepotrebuju, thread, kde mi tohle bezi, zabiju a vsechny TectoMT zdroje se uvolni

#Druha vec je - v hlavnim programu mi bezi vic threadu na kazdy clanek, tady mi zas muze bezet vic threadu na kazdy zpracovavany clanek.

#Mozna by to slo i jinak. Ale priznam se, nejvic se mi libi, ze po zabiti forku se uvolni IHNED vsechny TectoMT zdroje.

use 5.008;
use Zpravostroj::Globals;
use strict;
use warnings;
use encoding 'utf8';
use Encode;
use IO::Socket;
use TectoMT::Scenario;
use TectoMT::Document;

use forks;

use Zpravostroj::Forker;

#TectoMT strasne rado pise hrozne moc blbosti ven. Muzu mu to zakazat nebo povolit.
#Pokud je SHUT_UP 1, zakazu to, pokud 0, povolim
my $SHUT_UP=0;

$|=1;

#jak jsem psal vyse, tyto 3 promenne inicializuji az v initialize, az bude potreba
my $scenario;
my $sock;
my $forker;

#Pomocna procedura na utiseni TectoMT
#Dostanu referenci na proceduru a bud ji jenom spustim, nebo ji spustim "tise", podle globalni $SHUT_UP
#(na tohle byly nejake uz hotove moduly v CPANu, ale vsechny nejak rozbijely utf8)
sub shut_up(&) {
	
	my $subre = shift;
	if ($SHUT_UP){
		
		#zkopiruju si STDOUT a STDERR
		open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
		open my $olderr, ">&", \*STDERR or die "Can't dup STDERR: $!";

		#a otevru /dev/null (neni to prenosne na MS Windows, ale who cares)
		open STDOUT, ">/dev/null";
		open STDERR, ">/dev/null";
		
		$subre->();
		
		#zase zavru
		open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
		open STDERR, ">&", $olderr or die "Can't dup \$olderr: $!";
		
	} else {
		$subre->();
	}
	
}


#pokud neni scenario vytvorene, vytvori ho
#stejne tak socket a forker
#(chvili trva a je to "ukecana" procedura, proto shut_up)
sub initialize {
	if (!defined $scenario) {
		shut_up {
			 
			$scenario = TectoMT::Scenario->new({'blocks'=> [ qw(
				SCzechW_to_SCzechM::Sentence_segmentation 
				SCzechW_to_SCzechM::Tokenize 
				SCzechW_to_SCzechM::TagHajic 
				SCzechM_to_SCzechN::Find_geo_named_ent 
				SCzechM_to_SCzechN::Geo_ne_recognizer 
				SCzechM_to_SCzechN::SVM_ne_recognizer 
				SCzechM_to_SCzechN::Embed_instances) ]});
				#nejlepsi posloupnost k nalezeni pojmenovanych instanci, myslim.
				#sam vsem tem modulum uplne nerozumim, popravde, ale je to black box :)
		};
		
		$sock = new IO::Socket::INET (
			LocalPort => '7070',
			Proto => 'tcp',
			Listen => 50,
			Reuse => 1,
			Timeout=>1 #Timeout MUSI byt, aby se nekdy spustil $forker->check_waiting()
		);
		
		$forker = new Zpravostroj::Forker(size=>10);
	}
}


#vezme TectoMT node a do pole nacpe vsechna lemata z nej a deti
#pushuje tam dvojici lemma - form
sub push_lemmatized_words {
	my $node = shift;
	my $array_ref=shift;
	if (my $lemma = ($node->get_attr('lemma'))) {
		
		my $form =  $node->get_attr('form');
		
		push @$array_ref, ($lemma, $form);
		
	}
	foreach my $child ($node->get_children) {
		push_lemmatized_words($child, $array_ref);
	}
}

#vezme TectoMT node a do pole nacpe vsechny pojm. etnity z nej a deti
#pushuje tam dvojici entita - typ
sub push_entities {
	my $node = shift;
	my $array_ref=shift;
	if ($node->get_deref_attr('m.rf')) {
		my $type = $node->get_attr('ne_type');
		if ($type) {
			my $name = $node->get_attr('normalized_name');
			my $type =  $node->get_attr('ne_type');
			
			push @$array_ref, ($name, $type);
		}
	}

	foreach my $child ($node->get_children) {
		push_entities($child, $array_ref);
	}
}

#Procedura, ktere prijde cisty text
#a vrati uz to, co se ma "vytisknout" klientovi jako pole
sub tag {
	my $text = shift;
	
	say "Jdu na tagging.";
	
		
	my $document = TectoMT::Document->new();
	$document->set_attr("czech_source_text", $text);
	$|=1;
	my @lemres; #lemmata
	my @entres; #entity [oboji je uz tak, jak se bude tisknout]
	
	shut_up {
		$scenario->apply_on_tmt_documents($document);
	};
	
	
	foreach my $bundle ( $document->get_bundles() ) {
		
		if ($bundle->contains_tree('SCzechM')) { 
			
			my $lematree = $bundle->get_tree('SCzechM');
			push_lemmatized_words($lematree, \@lemres);
		}
	 
		if ($bundle->contains_tree('SCzechN')) { 
			
			my $entree = $bundle->get_tree('SCzechN');
			push_entities($entree, \@entres);
		}
	}
	
	push (@lemres, "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC");
	
	push (@entres, "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC");
	
	return (@lemres, @entres);
	
}


#Spusti samotny server. SIGUSR1 je znameni "uz neprijimej sockety a brzo zemri"
sub run {
	$|=1;
	
	my $should_run = 1;
	
	#nevim, jak je bezpecne delat veci jako say v signal handleru [say je pritom volano z Zpravostroj::Globals]
	#na druhou stranu, nejsme v C, ale v perlu...
	$SIG{'USR1'} = sub {say "prijimam usr1";$should_run = 0; };
	
	say "Jsem tu - run";
	
	
	initialize();
	while ($should_run) {
		
		say "Pred acceptuji spojeni.";
		my $newsock = $sock->accept();
		
		#newsock muze nevyjit kvuli timeoutu
		#(timeout tam naopak MUSI byt, aby se nekdy spustil $forker->check_waiting()!!)
		if ($should_run and $newsock) {
			say "Po akceptaci. Jdu do threadu.";
		
			my $sref = sub {
			
				say "v threadu.";
		
				#nejsem si jist, jestli je nutne, ale UTF8 strasne rado blbne
				binmode $newsock, ':utf8';
		
			
				my $text;
	
				while (<$newsock>) {
					chomp;
					if ($_ eq "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC") {
						say "Je to ZKZK, koncim!";
						last;
					} else {
				
						say "Neni to ZKZK, pripojuju.";
						unless ($SHUT_UP) {say "Pro uplnost, je to $_";}
							#tohle mam pro debugging - muze to byt velmi ukecane
				
						$text.=$_;
					}
	
				}
	
				#tohle uplne nevim, proc tu mam, ale nicemu to neskodi
				binmode STDOUT, ':utf8';
	
				for (tag($text)) {
					print $newsock $_;
					print $newsock "\n";
				}

				close $newsock;
			};
		
		
			say "Posilam thread forkeru.";
			$forker->run($sref);
			say "Poslano.";
		} else {
			if (!$should_run) {
				say "Cekani spravne vyruseno usr1"; #jenom debugovaci
			}
		}
		$forker->check_waiting();
	}
	
	say "Cekam...";
	$forker->wait();
	say "Docekal, koncim!";
	
	threads->exit();
}


#tecto_thread je globalni promenna, co pouzivam pouze v run_tectoserver a stop_tectoserver
#je v ni thread, kde bezi tectoserver
#tj. run_tectoserver a stop_tectoserver spoustim VZDY z hlavniho threadu! ne z threadu s tectomt
#(ackoliv mam pocit, ze stop_tectoserver by fungovalo. ale jist si nejsem. 
#	run_tectoserver by nefungovalo proto, ze ten thread jeste neexistuje :) ) 
my $tecto_thread;

sub run_tectoserver {
	$|=1;
	$tecto_thread = threads->new( sub {    
		
		
		
		Zpravostroj::TectoServer::run;
		
		
	} );
	
	$tecto_thread->detach()

}


sub stop_tectoserver {
	$|=1;
	say "Zastavuji tectoMT ve Stop_tectoserver";
	$tecto_thread->kill('SIGUSR1');
}


1;