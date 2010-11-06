package Zpravostroj::Extractor;

use HTML::DOM;
use strict;
use warnings;
use utf8;

use Zpravostroj::Other;

use base 'Exporter';
our @EXPORT = qw(extract_texts);


my %not_wanted;
my %wanted;
{
	my $read = read_information("HTML_tags");
		
	@wanted{@{$read->{wanted}}} = ();
	@not_wanted{@{$read->{not_wanted}}} = ();	
}
	#again, its global, but it is needed all the time, but I have to read it just once

my $not_beginning = join ("|", @{read_option("extractor_not_wanted_at_beginning")});
	#also global... what are you gonna do


sub is_wanted {
	my $who = shift;

    return ((exists $wanted{$who->tagName}) or (exists $wanted{$who->getAttribute('id')}) or (exists $wanted{$who->getAttribute('class')}) or (exists $wanted{$who->getAttribute('name')}));
}

sub is_not_wanted{
    my $who=shift;

    return ((exists $not_wanted{$who->tagName}) or (exists $not_wanted{$who->getAttribute('id')}) or (exists $not_wanted{$who->getAttribute('class')}) or (exists $not_wanted{$who->getAttribute('name')}));

}

sub is_paragraph{
	my $text = shift;
	if ($text =~ /^[^\.\?!]+[\.\?!][^\.\?!]+[\.\?!]/) {
		return 1;
	} else {
		if ($text =~ /^[^\.\?!]{90,}[\.\?!]/) {
			return 1;
		} else {
			return 0;
		}
	}
}

sub check_unknown {
	my $element = shift;
	my $result = "";
	
	foreach my $node ($element->childNodes) {
		next unless ((ref $node) =~ /^HTML::DOM::Element/);
							#we are ignoring "free laying" text, because it's not in wanted div
						
		next if is_not_wanted($node);
							#we are ignoring unwanted divs
							
		if (is_wanted($node)) {
			$result .= check_wanted ($node);
				#we know its wanted 
		} else {
			$result .= check_unknown ($node, $result);
				#we know nothing	
		}
	}
	return $result;
}

sub check_wanted{
    my $element = shift;
	my $result="";	
	
    foreach my $node ($element->childNodes) {
        if ((ref $node) =~ /^HTML::DOM::Element/) {
			$result .= check_wanted($node) unless (is_not_wanted($node));
				#EVEN within wanted, we can have unwanted part!
				
        } else {
			my $addition="";
			$addition = ($node->data) if (($node->data) and (is_paragraph($node->data)));
			$addition =~ s/([^.]*)($not_beginning) -/$1/;
			
			$result .= $addition;
				#if its a text, write it.
				
				#Praha as a first word/ word before - (as in "Praha -") = not a "regular" word
        }
    }    
	return $result;
}

sub extract_text {   
	my $article_ref = shift;
	my %article = %$article_ref;
	
	
	if (!exists $article{html}) {
		return \%article;
	}
	
    my $text = $article{html};
	
	
	while ($text =~ s/<!--([^-]*|-[^-]*)*-->//) {};
	#stripping all the comments, baby
	

	my $dom_tree = new HTML::DOM;
	
	$dom_tree->write($text);
	$dom_tree->close();
    
	my $extracted = check_unknown($dom_tree);
	
	my @sentences = split(" *[\.\"\'] *", $extracted);
	foreach (@sentences) {s/\n//g};
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
				my $end_sentence = join (" ", @words[$#words-9..$#words]);
				if (!exists $ends_written{$end_sentence}) {
					$result.=$sentence.". ";
					$ends_written{$end_sentence} = 1;
				}
			}
		}
	}
	
	$article{extracted} = $result;
	$article{title} = "";
	eval{$article{title} = $dom_tree->getElementsByTagName('title')->[0]->text()};
		#sometimes, article does not have title. it happens.
		
    return \%article;
}

sub extract_texts {   
	my @articles = @_;
	my_log("Extractor", "Let's go! [this usually works OK so I wont log too much]");
	my @results;
	my $i=0;
	
	for my $article (@articles) {
		my_log("Extractor", "article $i-----");
		my $result={};
	
		eval{$result = extract_text($article)};
		
		if ($@) {
			my_warning("Extractor", "extract_texts - weird error $@");
			my_log("Extractor", "-----didnt work. check out the warnings.");
		} else {
			if ($result->{extracted} eq "") {
				my_log("Extractor", "-----didnt work. check out the warnings.");
				my_warning("Extractor", "extract_texts - empty result!!!§§§§");
			} else {
				my_log("Extractor", "-----did work. thumbs up!");
			}
		}
		
		push(@results, $result);
		$i++;
	}
	my_log("Extractor", "Dan.  kthxbai");
	return @results;
}