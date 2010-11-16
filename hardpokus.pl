use warnings;
use strict;
use 5.010;
#use encoding 'utf8';
binmode STDOUT, ":utf8";


use All;
use Date;
use Globals;


my $counts = undump_bz2("data/all/counts.bz2");

dump_bz2_new("data/all/counts_better.bz2", $counts); 


#my $date = Date::get_from_string("2009-12-29");
# say "Zkoumam date ",$date->get_to_string,"!";



#$date->get_and_save_themes($count, $total);

# All::get_top_themes();
# my $randart = int(rand(30));
# say "rand je $randart";
# my $article = $date->read_article($randart);
#my $article = $date->read_article(27);
# $article->clear_counts();
# my $count = All::get_count();
# my $total = All::get_total_before_count();

# $article->count_themes($total, $count);
# my $themes = $article->themes;
# for (@$themes) {say "form: ",$_->form, ", lemma: ", $_->lemma,", importance:", $_->importance};
# say $article->article_contents;
# say "Hotovo, ukladam kamsi...";
# #$date->save_day_themes($themes);
# All::add_to_theme_files($themes, $date, 10);
# 
# 
# # (All::get_all_dates())[0]->get_counts_parts;