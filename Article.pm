package Article;
use 5.010;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Types;
use WebReader;
use ReadabilityExtractor;
use Lemmatizer;
use Word;



has 'url' => (
	is=>'ro',
	required=>1,
	isa=>'URL'
);

has 'html_contents' => (
	is=>'ro',
	lazy => 1,
	default=>sub{read_from_web($_[0]->url)}
);

has 'article_contents' => (
	is=>'ro',
	lazy=>1,
	default=>sub{extract_text($_[0]->html_contents)}
);

has 'title' => (
	is=>'ro',
	lazy=>1,
	default=>sub{extract_title($_[0]->html_contents)}
);

has 'words' => (
	is=>'ro',
	isa=>'ArrayRef[Word]',
	lazy=>1,
	default=>sub{lemmatize(($_[0]->title)." ".($_[0]->article_contents))}
);



has 'word_counts' => (
	is=>'ro',
	isa=>'HashRef',
	lazy=>1,
	default=>sub{
		$|=1;
		my $a = shift;
		my %mycounts;
		my $last = undef;
		my $before_last = undef;
		my @words = @{$a->words};
		
		for my $word (@words) {
			my $l = $word->lemma;
			$mycounts{$l}++;
			if (defined $last) {
				$mycounts{$last." ".$l}++;
			}
			if (defined $before_last) {
				$mycounts{$before_last." ".$last." ".$l}++;
			}
			$before_last = $last;
			$last = $l;
		}
		return \%mycounts;
	}
);

sub BUILD {
	my $s = shift;
	$s->word_counts;
}

__PACKAGE__->meta->make_immutable;

1;
# 
# package Main;
# 
# my $r = Article->new(url=>"http://www.blesk.cz/clanek/134067/topolanek-dostane-pet-platu-co-s-nim-dal.html");
