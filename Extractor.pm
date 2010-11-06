package Extractor;


use 5.010;
use Globals;

use HTML::HeadParser;
use HTML::DOM;
use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw(extract_title extract_text);

sub is_paragraph {
	my $text = shift;
	
	if ($text =~ /^[^\.\?!<_{\[]{8,}[\.\?!] [^\.\?!<_{\[]{8,}[\.\?!]/) {
		return 1;
	} else {
		if ($text =~ /^[^\.\?!<_{\[]{75,}[\.\?!]/) {
			return 1;
		} else {
			if ($text!~/^\s*$/) {
				say "Vyrazuji:";
				say "_".$text."_";
			}
			return 0;
		}
	}
}

sub check_wanted {
    my $element = shift;
	my $result="";	
	
    foreach my $node ($element->childNodes) {
        if ((ref $node) =~ /^HTML::DOM::Element/) {
			#rekurzivne vnitrek
			$result .= check_wanted($node);
				#EVEN within wanted, we can have unwanted part!
				
        } else {
	
			if (($node->data) and (is_paragraph($node->data))) {
				my $addition = ($node->data);
				$addition =~ s/([^.]*)($not_beginning) -/$1/;
				$result .= $addition." -|- ";
				
			}
        }
    }    
	return $result;
}

sub extract_title {
	my $text=shift;
	my $p = HTML::HeadParser->new;
	$p->parse($text);
	return $p->header('Title') ;
}

sub extract_text {   

    my $text = shift;
	
	$text =~ s/<!--([^-]*|-[^-]*)*-->//g;
	my $change=1;
	while ($change) {
		$change=0;
		for (@todelete) {
			while ($text =~ s/<$_[^>]*>([^<]*)<\/$_[^>]*>/ $1 /gi) {$change=1;}
			# tohle je dobre - obcas je <span><span><span>BLBOST</spam></span></span>, z me neznameho duvodu, a tohle to nechytne na 1 pokus vse
			# ano, sel by ten regex postavit i bez toho while, ale kaslu na to
		}
	}
	

	my $dom_tree = new HTML::DOM;
	
	$dom_tree->write($text);
	$dom_tree->close();
    
	my $extracted = check_wanted($dom_tree);
	
	my @sentences = split(" *[\.\"\'] *", $extracted);
	# foreach (@sentences) {s/\n//g};
	my %written;
	my $result="";
	my %ends_written;
	
	for my $sentence (@sentences) {
		if (!exists $written{$sentence}) {
			my @words = split (/ /, $sentence);
			
			$written{$sentence}=1;
			
			if (@words < 10) {
				$result.=$sentence.". ";
			} else {
				#odstraneni duplikatnich vet
				my $end_sentence = join (" ", @words[$#words-9..$#words]);
				if (!exists $ends_written{$end_sentence}) {
					$result.=$sentence.". ";
					$ends_written{$end_sentence} = undef;
				}
			}
		}
	}
	
	say "Vysledek:";
	say  $result;
	
	return $result;
}

1;