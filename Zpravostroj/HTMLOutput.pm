package Zpravostroj::HTMLOutput;

use 5.008;
use strict;
use warnings;
use utf8;
use encoding 'utf8';


use Zpravostroj::AllDates;
use Zpravostroj::Globals;
use Zpravostroj::ManualCategorization::Unlimited;
use Zpravostroj::ManualCategorization::NewsTopics;


my $UNLIMITED=1;
#jinak news topics

use Facebook::Graph;

use Encode;

use YAML::XS qw(Load Dump);

use URI::Escape;

use CGI ':standard';

sub print_zacatek {
	print << 'EOF';
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
	<html>
		<head>
			<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
			<title>Zpravostroj - zatrizovani</title>
		</head>
		<style type="text/css">
		body    {font-family: "lucida grande", tahoma, verdana, arial, sans-serif;font-size: 13px;}
		h1{font-size: 1.5em;border-bottom:1px solid black;}
		
		.kvalita{float:left}
		
		.hodnoceni{border-top:1px solid black;}
		.instrukce{background-color:#E7EBF1}
		ul{list-style: none;}
		.addthemebutton {
			background-color: #5B74A8;
			/*background-position: 0 -48px;*/
			border:1px solid;
			border-color: #29447E #29447E #1A356E;
			
			color:white;
		}
		.nevybrana, .vybrana {
			
			padding: 3px 4px 3px 4px;
			margin: -1px;
			line-height: 2.4;
			white-space: nowrap; 
		}
		
		.nevybrana {
			background-color: #E8EBF2;
			border: 1px solid #B0B9EC;
			cursor:pointer
		}
		
		.vybrana {
			background-color: #FFF9D7;
			border: 1px solid #E2C822;
		}
		
		#predkoncem {
			border-top: 1px solid black; 
			margin-top: 20px;
		}
		
		#endsubmit {
			
			background-color: #D4D0C8;
			border: 1px solid;
			color: black;
			font-size: 130%;
			margin-top: 10px;
			font-weight: bold;
			border-color: #888;
		}
		#clear{clear:both}
		</style>
		<body>
EOF
}

sub polozka {
	my $text = shift;
	my $cscript = shift;
	
	my $res = '<span class="nevybrana" ';
	$res = $res. 'onclick="'.$cscript.'"';
		
	$res = $res. '>'.$text.'</span> ';
	return $res;
}

sub print_redirect {
	my $where = shift;
	print << "EOF";
	<script type="text/javascript">
	
	top.location.href = "$where"
	
	</script>
EOF
}

sub print_end {
	print << 'EOF';
		</body>
	</html>
EOF
}

sub chci_novy_token {
	my ($fb, $c) = @_;
	my $uri = $fb->authorize->uri_as_string;
	
	print $c->header(-charset=>'utf-8');
		
	print_zacatek;
	print_redirect($uri);
	print_end;
}





sub print_article {
	my $a = shift;
	my $name = shift;
	my $id = shift;
	
	print '
	<script language="JavaScript" type="text/javascript">
	
	window.fbAsyncInit = function() {
		FB.Canvas.setAutoResize();
	}
	var all_themes = new Array();
	
	function addtheme(what) {
		what = what.replace(/\s*$/gi,"");
		if (what!="další theme") {
			all_themes[what] = 1;
		
			update_visible_themes();
		}
	}
	
	function deletetheme(what) {
		all_themes[what] = 0;
		
		update_visible_themes();
	}
	
	function update_visible_themes() {
		var H = document.getElementById("vybraneh3");
		H.innerHTML = "Vybrané kategorie";
	
		var Parent = document.getElementById("themesdiv");
		
		Parent.innerHTML="";
		document.trizeni.themes.value = "";
		for (var theme in all_themes) {
			
			if (all_themes[theme]==1) {
				var NewDIV = document.createElement("SPAN");
				NewDIV.setAttribute("class", "vybrana");
				NewDIV.innerHTML = theme + " <a href=\"javascript:deletetheme(\'" + theme + "\')\">X</a>";
				
				document.trizeni.themes.value = document.trizeni.themes.value + "\n" + theme;

				Parent.appendChild(NewDIV);
				Parent.innerHTML = Parent.innerHTML+" ";
			}
		}
		
		FB.Canvas.setSize();
	}
	
	
	
	</script>
	<div class="instrukce">Vyberte, do kterých kategorie článek patří. Pokud se jedná o prázdný článek, zvolte "prázdný článek".</div>
	
	';
	
	print "<h1>".$a->title."</h1>";
	
	print "<a href=\"".$a->url."\" target=\"_blank\">původní článek (s lepšími odstavci, nemusí ale fungovat)</a>";
	print "<p>".$a->article_contents."</p>";
	

	
	print "<div class=\"hodnoceni\" id=\"hodnoceni\">";
	
	
	
	print '<h3 id="vybraneh3"></h3>
	<div id="themesdiv"></div>';
	
	print "<h3 id=\"oblibh3\">Oblíbené kategorie</h3><div>";
	my @possible_categories = $UNLIMITED ? (Zpravostroj::ManualCategorization::Unlimited::get_possible_categories()) 
											: (Zpravostroj::ManualCategorization::NewsTopics::get_possible_categories());
	
	for (@possible_categories) {
		print polozka($_, "addtheme('$_')");
	}
	
		
	print "</div><form name=\"trizeni\" method=\"get\">";
	print '<h3>Jiná kategorie</h3>
	<input type="text" name="newtheme" value="další theme" style="width:100%"><button name="addthemebutton" onclick="addtheme(document.trizeni.newtheme.value)" type="button" class="addthemebutton">přidej téma</button><br>
	<input type="hidden" name="article" value="'.$name.'">
	<input type="hidden" name="person" value="'.$id.'">
	<input type="hidden" name="themes">
	';

	print "<div id=\"predkoncem\"><input type=\"submit\" value=\"Hotovo, dej další článek!\" id=\"endsubmit\"></div></form>";

	
}



sub generate_HTML {
	Zpravostroj::Globals::_shut_up;
	my $c = shift;
	
	
	my $fb = Facebook::Graph->new(
		secret      => "5e26c0f3d3027dfd90d7dfe52575f9be",
		app_id      => "188978231143185",
		postback    => 'http://ufallab2.ms.mff.cuni.cz/~bilek/',
	);
	
	if (!$fb) {
		print $c->header(-charset=>'utf-8');
		print "Totalni chyba.";
		return;
	}
	
	if ($c->param("code")) {
		#prichazi jako postback po autorizaci
		my $code = $c->param("code");
		$fb->request_access_token($code);
		my $access_token = $fb->access_token;
		
		my $cookie=cookie(-name=>'token', -value=>$access_token);
		print $c->header(-cookie=>$cookie, -charset=>'utf-8');
		print_zacatek;
		
		print_redirect("http://apps.facebook.com/zpravostroj_z/");
		print_end;
		return;
	}
	
	if ($c->param("article")) {
		#samotne oznackovani :)
		
		my $encoded = Encode::decode_utf8( $c->param("themes") );
		if ($UNLIMITED) {
			Zpravostroj::ManualCategorization::Unlimited::add_article_to_categories($c->param("article"), $encoded);
		} else {
			Zpravostroj::ManualCategorization::NewsTopics::add_article_to_categories($c->param("article"), $encoded);
			
		}
	}
	
	if (!$c->cookie('token')) {
		#nemam auth token, musim si ho vytvorit
		chci_novy_token($fb, $c);
		return;
	}
	
	
	#mam token, ale nevim, jestli platny.
	eval {
		$fb->access_token($c->cookie('token'));
		$fb->fetch("me");
	};
	
	
	if ($@) {
		#neni platny
		chci_novy_token($fb, $c);
		return;
	}
	
	
	#jsem konecne uspesne nalogovan
	print $c->header(-charset=>'utf-8');
	
	
	
	
	print_zacatek;
	
	$fb->access_token($c->cookie('token'));
	
	my $person = $c->param("person") || $fb->fetch("me")->{id};
	
	
	
	
	
	my ($a, $name) = $UNLIMITED ? 
				(Zpravostroj::ManualCategorization::Unlimited::get_random_article()) 
				: 
				(Zpravostroj::ManualCategorization::NewsTopics::get_random_article());
				
	print_article($a, $name, $person);
	
	
	
	print_end;
	
	
	
}


1;