package Zpravostroj::HTML;

use base 'Exporter';
our @EXPORT = qw(generate_HTML);

use strict;
use warnings;
use utf8;

use CGI ':standard';

use Zpravostroj::Database;
use Zpravostroj::Other;


sub generate_HTML {
	my $q = shift;
	# my $x = $q->param('lol');
	# return $x if $x;
	my $p_old = $q->param('old');
	my $p_day = $q->param('day');
	
	my $day;
	if ($p_day) {
		$day = $p_day;
	} elsif ($p_old) {
		$day = get_day($p_old);
	}
	
	my @themes;
	if ($day) {
		@themes = @{read_db(day=>$day, top_themes=>1)->{top_themes}};
	} else {
		@themes = @{read_db(pool=>1, top_themes=>1)->{top_themes}};
	}
	foreach (@themes) {$_->{best_form}=~s/_/ /g;};
	
	my $res;
	$res.=start_html(-title=>'Zpravostroj - nejčastější témata dne $day',
					-author=>'kaja.bilek[<>]gmail.com',
					-meta=>{'keywords'=>'zpravostroj zpravodajství zprávy',
							'copyright'=>'(C) Karel Bílek 2009'},
					-lang=>"cs",
					-head=>meta({-http_equiv => 'Content-Type',
					 			 -content    => 'text/html; charset=utf8'}));
	
	$res.=h1("Nejčastější témata dne $day");
	
	$res.=table(Tr({-align=>'CENTER',-valign=>'TOP'},
				[
					th(['Téma', 'Lemma', '#článků', 'Nějaký titulek', 'id']),
					map {
						my $article = ${$_->{articles}}[0];
						td[$_->{best_form}, $_->{lemma}, scalar (@{$_->{articles}}), $article->{title}, $article->{id}]
					} @themes
				]
				));
	
	$res.=end_html;
	return $res;
}

1;