package Zpravostroj::Readability;
#Modul, co dostane HTML a vyplivne to, co si mysli, ze je clanek

#je to delane pomerne chytre na zaklade pomeru odkazu/textu (to, co chci, ma minimalni pomer odkazu, to, co nechci, je samy odkaz)
#a ruzne to traverzuje HTML::DOM


#Package je temer PRIMYM portem JavaScriptoveho bookmarkletu Readability do perlu
#(ano, opakuji, je to portovano z JavaScriptu do perlu... byl to zazitek)
#hlavni nevyhoda - zatimco DOM v prohlizecich je RYCHLY (je v nat. kodu), HTML::DOM je radove pomalejsi (je cely v perlu)
#je tu take obri nekonzistence se zbytkem kodu zpravostroje (napr. nazvy procedur jsou obcas CamelCase, obcas_nejsou; odsazeni je divne; apod.)

#Kod je tedy, priznavam, trochu necitelny

#na druhou stranu, funguje to vyborne, az na tu rychlost, resp. pomalost

#stranka projektu - http://code.google.com/p/arc90labs-readability/
#Readability (c) 2010 Arc90 Inc

#Nebudu ho prilis komentovat - tj vubec, protoze sam ne uplne vim, co kdy presne dela, byl jsem rad, ze jsem to rozbehal

use 5.008;
use Zpravostroj::Globals;

use Switch;

use File::Slurp;
use HTML::HeadParser;
use HTML::DOM;
use warnings;
use strict;

sub extract_title {
	my $text=shift;
	my $p = HTML::HeadParser->new;
	$p->parse($text);
	return $p->header('Title') ;
}

my $stripUnlikelyCandidates=1;
my $unlikely = "combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter|equ-img|ad|time|time-date|datum|authors|description|related|shareWin|shareLink|shareBox|photos|prep|hlavicka|menu|pata|reklam|lista|author|autor|bookmark|akce|equip-tv|tag|desc|social-bookmark|not4bbtext|det-txt|tools|form_email|social-bookmarking|chatbox|baner|coment|comment|background_inside|sidebordercontent|sideborderblock|casopis|impuls|pravy-sloupec|casopis_side|jeden_tyden|lista_top|partHeader|reklama|artTime|artAuthors|textovytip|related|cb|reklama|sklik|ads|related|date|wallpaper|tip-col|ad-col|adfox|tv-program|etarget|r-head|r-body|moot|hlavniz|neprehlednete|b-box|promo|eyes|akce|acomware|aukce|forum|features|pata|patka";

my $likely = "article|body|column|main|content|entry|shadow|articleBody|perex|clanek|opener|bbtext|d-perex|d-text|b_s_news_article_content|box_article_text|boxContent|content|post|text|clanek|obsah";

my $divToPElements = "a|blockquote|dl|div|img|ol|p|pre|table|ul";

sub getTextContent {
	my $e = shift;
	my $res="";
	for my $childNode ($e->childNodes) {
		
		if ($childNode->nodeType == 3) {
			$res.=$childNode->nodeValue." ";
		} else {
			$res.=getTextContent($childNode);
		}
	}
	return $res;
}

sub getCharCount {
	my ($e, $s) = @_;
	$s = $s || ",";
	
	my @parts = split(/$s/, getInnerText($e));
    return scalar @parts;
}

sub getInnerText {
	my $e = shift;
	my $textContent = getTextContent($e);
	
	if(!($textContent)) {
        return "";
    }
	$textContent=~s/^\s+|\s+//g;
	$textContent=~s/\s{2,}/ /g;
	return $textContent;
}


sub initializeNode {
	my $scores_ref = shift;
	my $node = shift;
	switch($node->tagName) {
        case 'DIV'
            {$scores_ref->{$node}+= 5;}
            

        case 'PRE' {next;}
        case 'TD' {next;}
        case 'BLOCKQUOTE' 
			{$scores_ref->{$node}+= 3;}
            
        case 'ADDRESS'{next;}
        case 'OL'{next;}
        case 'UL'{next;}
        case 'DL'{next;}
        case 'DD'{next;}
        case 'DT'{next;}
        case 'LI'{next;}
        case 'FORM'
			{$scores_ref->{$node}-= 3;}

        case 'H1'{next;}
        case 'H2'{next;}
        case 'H3'{next;}
        case 'H4'{next;}
        case 'H5'{next;}
        case 'H6'{next;}
        case 'TH'{next;}
			{$scores_ref->{$node}-= 5;}
    }
   
}

sub max {
	my ($a, $b) = @_;
	return ($a>$b)?$a:$b;
}

sub min {
	my ($a, $b) = @_;
	return ($a<$b)?$a:$b;
}


 
sub getLinkDensity {
	my $e = shift;
	my $links      = $e->getElementsByTagName("a");
    	my $textLength = length(getInnerText($e));
    	my $linkLength = 0;
    	for(@$links) {
		$linkLength+=length(getInnerText($_));
	}       
	if ($textLength==0) {
		return 1;
	}
	
	return $linkLength / $textLength;
}

sub get_elements_by_tagnames {
	my $what = shift;
	my @tnames = @_;
	my @res;
	for (@tnames) {
		my @new = $what->getElementsByTagName($_);
		push (@res, @new);
	}
	return @res;
}

sub getClassWeight {
	my $e = shift;
	my $weight = 0;

	if ($e->className or $e->id) {
		my $searchable = ($e->className||"").($e->className||"");
		
		
		
		if ($searchable=~/$unlikely/i) {
			$weight -= 25; 
		}
		
		if($searchable=~/$likely/i) {
			$weight += 25; 
		}
	}
	
	return $weight;
}

sub cleanStyles{
	my $e = shift;
	my $cur = $e->firstChild;

	if(!$e) {return; }
	
	eval {$e->removeAttribute('style');};
	
	while ($cur) {
		if ($cur->nodeType==1) {
			eval {$cur->removeAttribute('style');};
			cleanStyles($cur);
		}
		$cur = $cur->nextSibling;
	}
}

sub getTagCount {
	my ($e, $s) = @_;
	
	my @els = $e->getElementsByTagName($s);
	return scalar @els;
}



sub cleanConditionally {
	my ($scores_ref, $e, $tag) = @_;
	my @tagsList = $e->getElementsByTagName($tag);

	
	for my $element (reverse(@tagsList)) {
		
		
		my $weight = getClassWeight($element);
		my $contentScore = ($scores_ref->{$element}) ? $scores_ref->{$element} : 0;
		
		my $wwwwwwww = getTextContent($element);
		
		if($weight+$contentScore < 0) {
			
			$element->parentNode->removeChild($element);
			
		} elsif ( getCharCount($element,',') < 10) {
			
			my $p      = getTagCount($element, "p");
			my $img    = getTagCount($element, "img");
			my $li = getTagCount($element, "li")-100;
			my $input = getTagCount($element, "input");
			
			my $embedCount = 0;
			my @embeds     = $element->getElementsByTagName("embed");
			
			
			for my $embed (@embeds) {
				$embedCount++;
				
			}
			
			
			my $linkDensity   = getLinkDensity($element);
			my $contentLength = length(getInnerText($element));
			my $toRemove      = 0;
			

			if ( $img > $p ) {
				$toRemove = 1;
			} elsif ($li > $p and $tag ne "ul" and $tag ne "ol") {
				$toRemove = 1;
			} elsif ( $input > int($p/3) ) {
				$toRemove = 1; 
			} elsif ($contentLength < 25 and ($img == 0 or $img > 2) ) {
				$toRemove = 1;
			} elsif ($weight < 25 and $linkDensity > 0.2) {
				$toRemove = 1;
			} elsif ($weight >= 25 and $linkDensity > 0.5) {
				$toRemove = 1;
			} elsif (($embedCount == 1 and $contentLength < 75) || $embedCount > 1) {
				$toRemove = 1;
			}
			
			
			if($toRemove) {
				my $prnt = $element->parentNode;
				
				
				$element->parentNode->removeChild($element);
				
			}
		}
	}
	
	
}

sub cleanTag {
	my ($e, $tag) = @_;
	my @targetList = $e->getElementsByTagName( $tag );
	for my $y (reverse(0..$#targetList)) {
		$targetList[$y]->parentNode->removeChild($targetList[$y]);
	}
}

sub node_info {
	my$node = shift;
	my $s;
	eval {$s = "classname ".($node->className())." - IDname ".($node->id())." - tagname ".$node->tagName();};
#	return "LOLDONGS";
	return $s;
}

sub extract_text {   
	$|=1;
	
	say "ETExt begin!";

	my %scores;
	
	my $res;
	
	my $html = shift;
	
	
	
	my $dom_tree = new HTML::DOM;
	
	$dom_tree->write($html);
	$dom_tree->close();
	
	
	#=====PREPARE
	
	for my $script ($dom_tree->getElementsByTagName('script')) {
		$script->parentNode->removeChild($script);
	}
	
	for my $styleSheet ($dom_tree->styleSheets) {
		$styleSheet->disabled(1);
	}
	
	for my $styleTag ($dom_tree->getElementsByTagName('style')) {
		$styleTag->parentNode->removeChild($styleTag);
	}
	
	
	#=====GRAB
	
	my $page = $dom_tree->getElementsByTagName('body')->[0];
	
	my $pageCacheHtml = $page->innerHTML;
 	my @allElements = $page->getElementsByTagName('*');
 	
	
	# say "AE je ", (scalar @allElements);
	my $node;
	my @nodesToScore;
	
	my $counter;
    	
	for my $nodeIndex (0..$#allElements) {
		
		
		my $node = $allElements[$nodeIndex];


		
		if ($stripUnlikelyCandidates) {

			my $unlikelyMatchString = ($node->className()||"") . ($node->id()||"");
			if ($unlikelyMatchString=~/$unlikely/i and $unlikelyMatchString!~/$likely/i and $node->tagName() ne "BODY") {
				
				
				
				$node->parentNode->removeChild($node);
				
				
			} else {
				if ($node->tagName eq "P" || $node->tagName eq "TD" || $node->tagName eq "PRE" ) {
					
					push @nodesToScore, $node;
				}
				
				if ($node->tagName eq "DIV") {
					
					
					
					my @childs = get_elements_by_tagnames($node, qw(a blockquote dl div img ol p pre table ul));
					
					
					
					if (!(scalar @childs)) {
						
						my $newNode = $dom_tree->createElement('p');
						
						$newNode->innerHTML($node->innerHTML);
						
						$node->parentNode->replaceChild($newNode, $node);
						push @nodesToScore, $node;
					} else {
						
						# EXPERIMENTAL
						for my $childNode ($node->childNodes) {
							
							if ($childNode->nodeType == 3) {
								my $p = $dom_tree->createElement('p');
								$p->innerHTML($childNode->nodeValue);
								$childNode->parentNode->replaceChild($p, $childNode);
								push @nodesToScore, $p;
							}
						}
					}
		        }
			}               
		}


	}
	# say "Done";
	my @candidates;
	for my $pt (0..$#nodesToScore){
		# say "Dalsi NodeToScore";
		
		

		
		
		my $parentNode = $nodesToScore[$pt]->parentNode;
		my $grandParentNode = $parentNode ? $parentNode->parentNode : undef;
		my $innerText       = getInnerText($nodesToScore[$pt]);

		if (!$parentNode or !($parentNode->tagName)) {
			next;
		}

		if(length($innerText) < 25) {
			next; 
		}

		if(!exists $scores{$parentNode}) {
			initializeNode(\%scores, $parentNode);
			push (@candidates, $parentNode);
		}

		if($grandParentNode and !exists $scores{$grandParentNode} and $grandParentNode->tagName()) {
			initializeNode(\%scores, $grandParentNode);
			push (@candidates, $grandParentNode);
		}

		my $contentScore = 0;

		$contentScore++;

		my @splitted = split(/,/, $innerText);
		$contentScore += scalar(@splitted);

		$contentScore += min(int(length($innerText) / 100), 3);

		$scores{$parentNode} += $contentScore;

		if($grandParentNode) {
			$scores{$grandParentNode} += $contentScore/2;
			
		}
		
		
	}
	
	my $topCandidate;
	
	for my $c (0..$#candidates) {
		

		
		$scores{$candidates[$c]} *= (1-getLinkDensity($candidates[$c]));
		
		
		
		
		if(!$topCandidate or $scores{$candidates[$c]} > $scores{$topCandidate}) {
			$topCandidate = $candidates[$c];
		}
	}
	
	if (!defined $topCandidate or $topCandidate->tagName eq "BODY") {
		$topCandidate = $dom_tree->createElement("DIV");
		$topCandidate->innerHTML($dom_tree->body->innerHTML);
		$dom_tree->body->innerHTML("");
		$dom_tree->body->appendChild($topCandidate);
		initializeNode(\%scores, $topCandidate);
		
	}
	

	
	
	my $siblingScoreThreshold = max(10, $scores{$topCandidate} * 0.2);
	my @siblingNodes = (defined $topCandidate->parentNode) ? $topCandidate->parentNode->childNodes : ($topCandidate);
	
	my $articleContent = $dom_tree->createElement("DIV");
	
	
	
	for my $siblingNode (@siblingNodes) {
		
		# say "dalsi SiblingNode";
		
		
		my $append = 0;
		if (!$siblingNode) {
			next;
		}
		
		
		if($siblingNode == $topCandidate) {
			
			$append = 1;
		}
		
		my $contentBonus = 0;
		
		my $cname = "";
		eval {$cname = $siblingNode->className;};
		if ($cname eq $topCandidate->className and $topCandidate->className ne "") {
			$contentBonus += $scores{$topCandidate} * 0.2;
		}
		
		if(exists $scores{$siblingNode} and ($scores{$siblingNode}+$contentBonus) >= $siblingScoreThreshold) {
			
			$append = 1;
		}
		 
		if ($siblingNode->nodeName eq "P") {
			
			my $nodeContent = getInnerText($siblingNode);
			my $nodeLength  = length($nodeContent);
			

			if ($nodeLength == 0) {
				
			} else {
				
				my $linkDensity = getLinkDensity($siblingNode);
				
				if ($nodeLength > 80 && $linkDensity < 0.25) {
					
					$append = 1;
					
				} elsif ($nodeLength < 80 && $linkDensity == 0 && $nodeContent=~/\.( |$)/) {
					
					$append = 1;
				}
			}
		}
		
		
		
		if ($append) {
			my $nodeToAppend;
			if ($siblingNode->nodeName ne "DIV" and $siblingNode->nodeName ne "P") {
				
				$nodeToAppend = $dom_tree->createElement('div');
				$nodeToAppend->className($siblingNode->className);
				$nodeToAppend->id($siblingNode->id);
				$nodeToAppend->innerHTML($siblingNode->innerHTML);
				
			} else {
				$nodeToAppend = $siblingNode;
			}
			$articleContent->appendChild($nodeToAppend);
		}
	}
	#==================TADY KONCI GRAB ARTICLE - ale jeste musim zkopirovat prepArticle
	
	# say "Konci grabArticle";

	
	#cleanStyles
	cleanStyles($articleContent);
	
	cleanTag($articleContent, "form");
	cleanTag($articleContent, "object");
	cleanTag($articleContent, "h1");
	
	
	cleanTag($articleContent, "iframe");
	
	for my $headerIndex (3..7) {
		my @headers = $articleContent->getElementsByTagName('h'.$headerIndex);
		for my $header (@headers) {
			if (getClassWeight($header)<0 or getLinkDensity($header) > 0.33) {
				$header->parentNode->removeChild($header);
			}
		}
	}
	
	
	
	cleanConditionally(\%scores, $articleContent, "table");
	cleanConditionally(\%scores, $articleContent, "ul");
	
	
	
	
	cleanConditionally(\%scores, $articleContent, "div");
	
	
	
	my @articleParagraphs = $articleContent->getElementsByTagName('p');
	for my $paragraph (reverse(@articleParagraphs)) {
		my $imgCount    = getTagCount($paragraph, "img");
		my $embedCount  = getTagCount($paragraph, "embed");
		my $objectCount = getTagCount($paragraph, "object");
		
		if($imgCount == 0 and $embedCount == 0 and $objectCount == 0 and getInnerText($paragraph) eq ''){
			$paragraph->parentNode->removeChild($paragraph);
		}
	}
	

	$res = getTextContent($articleContent);

	say $res;
	
	say "Extractor hotovo";
	

        
	return $res;
}

1;
