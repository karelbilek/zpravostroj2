package OldGetter;
use 5.010;

use IO::Uncompress::Bunzip2;
use YAML::XS;

use warnings;
use strict;
use Article;
use Word;
use Date;
$|=1;
sub get_all_articles {
	my ($day, $month, $year) = @_;
	my $string = sprintf "%02d-%02d-%d", $day, $month, $year;
	
	say "Zacinam $string.";
	
	my $d = new Date(day=>$day, month=>$month, year=>$year);
	
	if (!-e "oldata/".$string."/archive.yaml.bz2") {
		die "oldata/".$string."/archive.yaml.bz2\n";
	}
	
	my $arr;
	{
		my $z = IO::Uncompress::Bunzip2->new("oldata/".$string."/archive.yaml.bz2");
	
		my $y = join ("", <$z>);
		close($z);
		say "Docteno";
		$arr = Load($y);
		say "DoLoadnuto.";
	}

	my @res;
	
	for my $old_article (@$arr) {
		if (!exists $old_article->{extracted}) {
			say "Zacinam buildovat ",$old_article->{url};
			push (@res, new Article(url=>$old_article->{url}));
		} else {
			my $old_all_named = $old_article->{all_named};
			my $old_all_words = $old_article->{all_words};
			
			my %all_named_hash;
			@all_named_hash{@$old_all_named}=();
			
			my @new_words;
			for (@$old_all_words) {
				my $lm = $_->{lemma};
				my $fm = $_->{form};
				my $new_wrd = new Word(lemma=>$lm , form=>$fm, all_named=>\%all_named_hash);
				push @new_words, $new_wrd;
			}
			
		
			push (@res, new Article(url=>($old_article->{url}), html_contents=>($old_article->{html}), article_contents=>($old_article->{extracted}), title=>($old_article->{title}), words=>\@new_words));
			
		}
	}
	for (@res) {
		$d->save_article($_);
	}
}

sub get_all_dates {
	for (<oldata/*>) {
		/oldata\/0?([^-]*)-0?([^-]*)-([^-]*)/;
		my $day = $1;
		my $month = $2;
		my $year = $3;
		system("perl -e 'use OldGetter; OldGetter::get_all_articles($day, $month, $year);'");
	}
}

1;