package RSS;
use 5.008;

use warnings;
use strict;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use MooseX::Storage;
use Globals;

with Storage;


use Date;
use Zpravostroj::WebReader;

has 'url' => (
	is=>'ro',
	required=>1,
	isa=>'URL'
);

has 'article_urls' => (
	is=>'rw',
	isa=>'HashRef',
	default=>sub { {} }
);

sub load_article_urls {
	my $s = shift;
	my $today = new Date() -> get_to_string;
	my $before_yesterday = Date::get_days_before_today(2)-> get_to_string;
	my $html = Zpravostroj::WebReader::wread($s->url);
	
	say "RSS ".$s->url;
	
	#smaze predvcerejsi
	for (keys %{$s->article_urls}) {
		if ($s->article_urls->{$_} =~ /$before_yesterday/) {
			delete $s->article_urls->{$_};
		}
	}
	
	#je to hnusne, ale zadny pricetny RSS parser pro perl neexistuje
	while ($html=~/<link>([^<]*)<\/link>/g) {
		my $link = $1;
		if ($link!~/^http:\/\/[^\/]*\/?$/) {
			#say "LINK $link";
			
			$s->article_urls->{$link} = $today;
		}
		
	}
	

}

sub get_article_urls{
	my $s = shift;
	my $today = new Date() -> get_to_string;
	my $yesterday = Date::get_days_before_today(1)-> get_to_string;
	

	my @res;
	for (keys %{$s->article_urls}) {
		if ($s->article_urls->{$_} eq $today or $s->article_urls->{$_} eq $yesterday) {
			push (@res, $_);
			$s->article_urls->{$_}.="_read";
		}
	}
	return @res;
	
}

__PACKAGE__->meta->make_immutable;

1;