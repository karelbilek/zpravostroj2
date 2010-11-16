package RSS;
use 5.010;

use warnings;
use strict;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use XML::RAI;
use MooseX::Storage;

with Storage;


use Date;
use WebReader;

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
	my $html = read_from_web($s->url);
	
	my $rai = XML::RAI->parse($html);
	
	#smaze predvcerejsi
	for (keys %{$s->article_urls}) {
		if ($s->article_urls->{$_} eq $before_yesterday) {
			delete $s->article_urls->{$_};
		}
	}
	
	my @items;
	eval {@items = @{$rai->items};};
	
	for my $item (@items) {
		my $link = $item->link();
		$s->article_urls->{$link} = $today;
	}
}

sub get_article_urls{
	my $s = shift;
	my $today = new Date() -> get_to_string;

	my @res;
	for (keys %{$s->article_urls}) {
		if ($s->article_urls->{$_} eq $today) {
			push (@res, $_);
		}
	}
	return @res;
	
}

__PACKAGE__->meta->make_immutable;

1;