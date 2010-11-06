package Zpravostroj::Walker;

use strict;
use warnings;
use Zpravostroj::Other;
use Zpravostroj::WebReader;
use Zpravostroj::RSS;
use Zpravostroj::Database;
use Zpravostroj::Extractor;
use Zpravostroj::Tagger;
use Zpravostroj::Counter;

use base 'Exporter';
our @EXPORT = qw(step redo_it);



sub read_new {
	my_log("Walker", "read_new starts! will read all links...");
	my @new_articles = get_all_links;
	if (!scalar @new_articles) {
		return;
	}
	
	my_log("Walker", "read_new will write the links to database...");
	my $start = write_db(pool=>1, append=>1, articles=>\@new_articles);
	my_log("Walker", "\$start is $start . Is it THAT weird?");
	my_log("Walker", "And there are ".scalar @new_articles." new articles. whataver.");

	my_log("Walker", "read_new will read all the stuff");
	@new_articles = read_from_webs(@new_articles);
	
	my_log("Walker", "read_new will extract all the stuff");
	@new_articles = extract_texts(@new_articles);
	
	my_log("Walker", "read_new will save all the stuff again before that terrible tagging");
	write_db(pool=>1, articles_begin=>$start, articles=>\@new_articles);

	my_log("Walker", "read_new ugh.... let's tag. It probably crashes somewhere here :-(");
	@new_articles = tag_texts(@new_articles);
	
	my_log("Walker", "read_new tagged it allllllll. save it.");
	write_db(pool=>1, articles_begin=>$start, articles=>\@new_articles);
	
	my_log("Walker", "read_new will read everything AGAIN for counting.");
	my $all_articles_ref = (read_db(pool=>1, articles=>1))->{articles};
	my_log("Walker", "btw, the whole thing is ".scalar(@$all_articles_ref)." big.");
	
	my_log("Walker", "read_new will count it all! lets shake it!");
	my %r = count_themes(0.85, 0.07, 0.9, 0.6, $all_articles_ref);
	
	my_log("Walker", "Lets rewrite the whole thing. Thats the point, right? RIGHT?");
	write_db(%r, pool=>1);
	
	my_log("Walker", "Done. OK thats enough. I will prbbly sleep or something.");

}

sub redo_it {
	my_log("Walker-redo", "redo_it starts!");
	my %parameters = @_;
	my @articles;
	my $top_themes_ref;
	
	if ($parameters{pool}) {
		if (my $which = $parameters{which}) {
			@articles = (read_db(pool=>1, articles=>1, articles_one=>$which))->{articles};
		} else {
			@articles = (read_db(pool=>1, articles=>1))->{articles};
			#my_log("Walker-redo", "I read pool articles");
			#use YAML::XS;
		}
	} elsif (my $day = $parameters{day}) {
		if ($parameters{do_reading}) {
			@articles = @{(read_db(day=>$day, articles=>1, short=>1))->{articles}};
		} else {
			@articles = @{(read_db(day=>$day, articles=>1))->{articles}};
		}
	}
	
	if (!scalar @articles) {
		my_warning("Walker-redo", "EMPTY \@articles! MY GOD THE HEAVENS!");
		return;
	}
	
	if ($parameters{do_reading}) {
		my_log("Walker-redo", "will read..");
		@articles = read_from_webs(@articles);
	}
	
	if ($parameters{do_extracting}) {
		my_log("Walker-redo", "will extract..");
		@articles = extract_texts(@articles);
	}
	
	if ($parameters{do_tagging}) {
		my_log("Walker-redo", "will tag..");
		@articles = tag_texts(@articles);
	}
	
	my $count_bottom_ref;
	my $all_counts_ref;
	if ($parameters{do_counting}) {
		my_log("Walker-redo", "will count..");
		
		if (my $day = $parameters{day}) {
			my_log("Walker-redo", "will null..");
			null_day_counts($day);
		}
		my_log("Walker-redo", "nulled, will count fo real..");
		
		my %r = count_themes(0.85, 0.07, 0.9, 0.6, \@articles);
		#my %r = count_themes(0.85, 0.07, 0.9, 100, \@articles);
		@articles = @{$r{articles}};
		$top_themes_ref = $r{top_themes};
		$count_bottom_ref = $r{count_bottom};
		$all_counts_ref = $r{all_counts};
	}
	
	if ($parameters{pool}) {
		if (my $which = $parameters{which}) {
			write_db(pool=>1, articles_begin=>$which, articles=>\@articles); #counting themes is impossible if doing just one
		} else {
			write_db(pool=>1, articles=>\@articles);
			if ($parameters{do_counting}) {
				write_db(pool=>1, top_themes=>$top_themes_ref);
			}
		}
	} elsif (my $day = $parameters{day}) {
		my_log("Walker-redo", "nulled, will count fo real..");

		write_db(day=>$day, articles=>\@articles);
		if ($parameters{do_counting}) {
			write_db(day=>$day, top_themes=>$top_themes_ref, count_bottom=>$count_bottom_ref, all_counts => $all_counts_ref);
		}
	}
	my_log("Dan!", "nulled, will count fo real..");

}


sub step {
	
	my_log("Walker", "step starts.");
	my $new_day = get_day;
	my $last_day = get_global("day");
	
	if (($last_day) and !($last_day eq $new_day)) {
		my_log("Walker", "step jupiiii, dny se lisi, jdu sunout");
		archive_pool;
	}
	
	my_log("Walker", "step gonna read stuff.");
	read_new;
	
	my_log("Walker", "step done, set global something");
	set_global("day", $new_day);
	my_log("Walker", "step done, kthxbai.");
}


1;