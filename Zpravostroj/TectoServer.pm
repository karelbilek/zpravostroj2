package Zpravostroj::TectoServer;
#package, co spusti TectoMT a funguje jako server, kteremu se posilaji texty,
#on je zpracuje a posle zpatky

#"Opacny" modul je TectoClient 

#Proc to delat pres server?
#No, to je otazka. :)

#Jednak jde o zjednoduseni - ze "hlavni" thread nemusi resit veci ohledne TectoMT a je to hezky "zapouzdrene" tady. Paklize uz TectoMT nepotrebuju, thread, kde mi tohle bezi, zabiju a vsechny TectoMT zdroje se uvolni

#Druha vec je - v hlavnim programu mi bezi vic threadu na kazdy clanek. Thread se zablokuje, dokud ceka na socket od serveru, TectoServer ma frontu pozadavku, co postupne zpracovava.

#Treti vec - server muze, diky Forkeru, zpracovavat vic pozadavku najednou.

use 5.008;
use Globals;
use strict;
use warnings;
use encoding 'utf8';
use Encode;
use IO::Socket;
use TectoMT::Scenario;
use TectoMT::Document;

use forks;
use forks::shared;
use Zpravostroj::Forker;

#TectoMT strasne rado pise hrozne moc blbosti ven. Muzu mu to zakazat nebo povolit.
#Pokud je SHUT_UP 1, zakazu to, pokud 0, povolim
my $SHUT_UP=0;

$|=1;

#TectoMT scenario je globalni promenna. Proc ne.
my $scenario;

#Serverovy socket je globalni
my $sock = new IO::Socket::INET (
	LocalPort => '7070',
	Proto => 'tcp',
	Listen => 50,
	Reuse => 1,
);

my $forker = shared_clone(new Zpravostroj::Forker(size=>5, name=>"TectoServer"));

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
#(chvili trva a je to "ukecana" procedura, proto shut_up)
sub initialize_scenario {
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

#Spusti samotny server. Je nekonecna -> nekdo to musi zvenku zabit
sub run {
	$|=1;
	print "Jsem tu - run\n";
	
	
	initialize_scenario();
	while (1) {
		
		say "Acceptuji spojeni.";
		my $newsock = $sock->accept();
		
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
		{
			say "LOCK NU 1";
			lock($forker);
			$forker->run($sref);
			say "END LOCK NU 1";
			
		}
	}
}

sub wait_before_killing {
	{
					say "LOCK NU 2";
		lock($forker);
		$forker->wait();
		say "END LOCK NU 2";
		
	}
}
1;