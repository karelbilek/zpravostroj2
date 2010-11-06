package TectoServer;

use base 'Exporter';
our @EXPORT = qw(run);

use 5.010;
use strict;
use warnings;
use encoding 'utf8';
use Encode;
use IO::Socket;
use TectoMT::Scenario;
use TectoMT::Document;


my $NOT_SHUT_UP=1;
my $MAXCONN=3;

use forks;
use forks::shared;
my $curconn : shared;

$curconn = 0;
$|=1;

sub shut_up(&) {
	
	my $subre = shift;
	if (!$NOT_SHUT_UP){
	
		open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";

		open my $olderr, ">&", \*STDERR or die "Can't dup STDERR: $!";

		open STDOUT, ">/dev/null";

		open STDERR, ">/dev/null";
		
		$subre->();
		

		open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
		open STDERR, ">&", $olderr or die "Can't dup \$olderr: $!";
		
	} else {
		$subre->();
	}
	
}

my $ent_scenario;
my $lemma_scenario;

shut_up {
	$ent_scenario = TectoMT::Scenario->new({'blocks'=> [ qw(SCzechW_to_SCzechM::Sentence_segmentation SCzechW_to_SCzechM::Tokenize SCzechW_to_SCzechM::TagHajic SCzechM_to_SCzechN::Find_geo_named_ent SCzechM_to_SCzechN::Geo_ne_recognizer SCzechM_to_SCzechN::SVM_ne_recognizer SCzechM_to_SCzechN::Embed_instances) ]});
	$lemma_scenario = TectoMT::Scenario->new({'blocks'=> [ qw(SCzechW_to_SCzechM::Sentence_segmentation SCzechW_to_SCzechM::Tokenize SCzechW_to_SCzechM::TagHajic) ]});
};

sub print_lemmatized_words {
	my $node = shift;
	my $res_ref=shift;
	if (my $lemma = ($node->get_attr('lemma'))) {
		
		my $form =  $node->get_attr('form');
		
		push @$res_ref, ($lemma, $form);
		
	}
	foreach my $child ($node->get_children) {
		print_lemmatized_words($child, $res_ref);
	}
}


sub print_entities {
	my $node = shift;
	my $res_ref=shift;
	if ($node->get_deref_attr('m.rf')) {
		my $type = $node->get_attr('ne_type');
		if ($type) {
			my $name = $node->get_attr('normalized_name');
			my $type =  $node->get_attr('ne_type');
			
			push @$res_ref, ($name, $type);
		}
	}

	foreach my $child ($node->get_children) {
		print_entities($child, $res_ref);
	}
}

sub tag {
	my $text = shift;
	
	say "Jdu na tagging SAMOTNY.";
	
	my $lemmas = shift;
	my $ent = shift;
	my $scenario = $ent ? $ent_scenario : $lemma_scenario;
	
		
	my $document = TectoMT::Document->new();
	$document->set_attr("czech_source_text", $text);
	$|=1;
	my @lemres; my @entres;
	
	shut_up {
		$scenario->apply_on_tmt_documents($document);
	};
	
	
	 foreach my $bundle ( $document->get_bundles() ) {
	 	
	 	
	 	if ($lemmas and $bundle->contains_tree('SCzechM')) { 
	 		
 			my $lematree = $bundle->get_tree('SCzechM');
	 		print_lemmatized_words($lematree, \@lemres);
	 		
	
	 	}
	 
	 	if ($ent and $bundle->contains_tree('SCzechN')) { 
	 		
	 		
	 		my $entree = $bundle->get_tree('SCzechN');
	 		print_entities($entree, \@entres);
	 		
	
	 	}
	 	
	 	
	 	
	 }
	if ($lemmas) {
		push (@lemres, "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC");
	}
	if ($ent) {
		push (@entres, "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC");
	}
	return (@lemres, @entres);
	
}

my $sock = new IO::Socket::INET (
	LocalPort => '7070',
	Proto => 'tcp',
	Listen => 50,
	Reuse => 1,
);



sub run {
	while (1) {
		{
			lock($curconn);
			if ($curconn>$MAXCONN) {
				cond_wait($curconn) until $curconn <= $MAXCONN;
			}
		}
		my $newsock = $sock->accept();
		{
			lock($curconn);
			$curconn++;
		}
		my $thread = threads->new(sub{
			binmode $newsock, ':utf8';
		
			my $what = <$newsock>;
			chomp($what);
			my $lemmas; my $named;
		
			if ($what eq "LEMMAS") {$lemmas=1; $named=0;};
			if ($what eq "ENTITIES") {$lemmas=0; $named=1;};
			if ($what eq "LEMMAS ENTITIES") {$lemmas=$named=1;};
		
			my $text;
		
			while (<$newsock>) {
				chomp;
				if ($_ eq "ZPRAVOSTROJ KONEC ZPRAVOSTROJ KONEC") {
					say "Je to ZKZK, koncim!";
					last;
				} else {
					
					say "Neni to ZKZK, pripojuju.";
					say "Pro uplnost, je to $_";
					$text.=$_;
				}
		
			}
		
			binmode STDOUT, ':utf8';
		
			for (tag($text, $lemmas, $named)) {
				say $newsock $_;
			}

			close $newsock;
			{lock($curconn);
			$curconn--;
			cond_signal($curconn);}
		});
		$thread->detach();
	}
}

1;