package Zpravostroj::Tagger;
 
use 5.008;
use strict;
use warnings;
 
 
use Encode;
use utf8;
 
use TectoMT::Scenario;
use TectoMT::Document;
use IO::CaptureOutput qw(capture);
use Zpravostroj::Other;
 
use base 'Exporter';
our @EXPORT = qw( tag_texts);
 
my @wanted_named = @{read_option("tagger_wanted_named")};
			#which types of named I do want
my $min_word_length = read_option("min_word_length");

 
sub create_new_document{
	my $text = shift;
	
	my $document = TectoMT::Document->new();
	$document->set_attr("czech_source_text", $text);
 
	return $document;
}
 
sub save_words {
	my $words_ref = shift;	
	my $node = shift;
 	
	eval {
		if (my $lemma = ($node->get_attr('lemma'))) {
			if (my $lemma_better = (make_normal_word($lemma))) {
			
				my $form = $node->get_attr('form');
				push (@{$words_ref},{lemma=>$lemma_better, form=>$form});
			
					#THE LEMMA DOESN'T HAVE TO BE 100% CORRECT!
					#why? because Tagger doesn't read corrections.yaml
					#because corrections can change, but I want to run this module as little as possible
			
			}
		}
		foreach my $child ($node->get_children) {
			save_words($words_ref, $child);
		}
	};
	if ($@) {
		my_warning("Tagger", "save_words - unidentified error - $@");
	}
}

 
sub save_named {
	my $named_ref = shift;
	my $node = shift;
	
	eval {
		if ($node->get_deref_attr('m.rf')) {
			#it is a named entity.
			my $type;
			if (($type=($node->get_attr('ne_type'))) and (length(my $name = $node->get_attr('normalized_name'))>=$min_word_length) and ($type =~ "/^".join("|", @wanted_named)."/")) {
				if (my $normal = make_normal_word($name)) {
					$named_ref->{$normal} = 1;
				}
			}
		}
 
		foreach my $child ($node->get_children) {
			save_named( $named_ref, $child);
		}
	};
	if ($@) {
		my_warning("Tagger", "save_named - unidentified error - $@");
	}
}
 
sub doc_to_hash {
	
	my $article = shift;
	
	my $document = shift;
	my @words;
	my %named;
	
	foreach my $bundle ( $document->get_bundles() ) {
		eval {save_words(\@words, $bundle->get_tree('SCzechM'))};
		if ($@) {my_warning("Tagger", "doc_to_hash - cannot get SCzechM tree - $@")};
	}
	
	foreach my $bundle ( $document->get_bundles() ) {
		eval {save_named( \%named, $bundle->get_tree('SCzechN'))};
		if ($@) {my_warning("Tagger", "doc_to_hash - cannot get SCzechN tree - $@")};
	}
	
	
	my @arnamed = keys %named;
	
	$article->{all_words}=\@words;
	$article->{all_named}=\@arnamed;
}

# my $save_err;
# 
# sub shut_up {
# 	my $ref = shift;
# 	open $save_err, ">&STDERR";
# 	open STDERR, '>', \$ref;
# }
# sub open_up {
# 	open STDERR, ">&", $save_err;
# }


 
my $scenario_initialized = 0;
my $scenario;
 
sub tag_texts {
	my_log("Tagger", "===============================================PAIN BEGINS");
	
	my @articles = @_;
	
	if (!@articles) {
		return ();
	}
	
	
	unless ($scenario_initialized) {
		
		my_log("Tagger", "===============================================INITIALISING SCENARIO");
		my $errbuf;
		capture {
			my $err;
			my $errcount;
			do {
				eval {$scenario = TectoMT::Scenario->new({'blocks'=> [ qw(SCzechW_to_SCzechM::Sentence_segmentation SCzechW_to_SCzechM::Tokenize  SCzechW_to_SCzechM::TagHajic SCzechM_to_SCzechN::SVM_ne_recognizer) ]})};
					#redirecting STDERR doesn't stop eval from working
				$err=$@;
				$errcount++;
			} while ($err and ($errcount < 5)); 
		
			if ($err) {
				die $err;
			}
		} \$errbuf, \$errbuf;
		my_log("Tagger", "===============================================DONE, now errbuf...");
		my_log("Tagger",$errbuf);
		$scenario_initialized = 1;
	}
	
 
	
	my %documents_hash;
	
	
	map ($documents_hash{$_}=create_new_document($_->{extracted}), @articles);
	
	my_log("Tagger", "===============================================MAIN TAGGING");
	
	my $errbuf;
	capture {
		eval {$scenario->apply_on_tmt_documents(@documents_hash{@articles})};
		if ($@) {
			my_log("Tagger", "======================================FIRST TIME NOT OK");
			eval {$scenario->apply_on_tmt_documents(@documents_hash{@articles})};
			if ($@) {
				my_log("Tagger", "======================================2ND TIME NOT OK");
				my_warning("Tagger", "tag_texts - shi'it :-/ $@");
			} else {
					my_log("Tagger", "======================================2ND TIME OK");
			}
		} else {
			my_log("Tagger", "======================================FIRST TIME OK");
		}
	} \$errbuf, \$errbuf;
	
	my_log("Tagger", "===============================================DONE, now errbuf...");
	my_log("Tagger",$errbuf);
	
	map (doc_to_hash($_, $documents_hash{$_}), @articles);
	
	my_log("Tagger", "===============================================DONEALL");
	
	return @articles;
}
 
1;