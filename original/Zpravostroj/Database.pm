package Zpravostroj::Database;

use strict;
use warnings;

use File::Touch;
use File::Remove 'rm';
use File::Slurp;
use Scalar::Util qw(looks_like_number);
use YAML::XS;# qw(LoadFile DumpFile);
use File::Copy;
use File::Touch;
use IO::Uncompress::Bunzip2;
use IO::Compress::Bzip2;
use utf8;

use Zpravostroj::Other;


use base 'Exporter';
our @EXPORT = qw( write_db read_db archive_pool set_global get_global null_day_counts read_db_bottom read_db_all_counts);

my $bottom_count = read_option("count_bottom");
my $database_dir = read_option("articles_address");
my $pool_dir = $database_dir."/pool";
my $appendix = ".yaml.bz2";

my $count_dir = read_option("count_dir");
mkdir $count_dir;

my $bottom_file = $count_dir."/bottom.yaml.bz2";
my $all_counts_file = $count_dir."/inverse_counts.yaml.bz2";

my %all_article_properties;
@all_article_properties{@{read_option("all_article_properties")}}=();

my $archive="archive.yaml.bz2";
my $topthemes = "top_themes.yaml.bz2";

sub read_db {
	
	my %parameters = @_;
	my %results;
	
	if ($parameters{pool} or (exists $parameters{day} and $parameters{day} eq get_day)) {
		#reading pool
		if ($parameters{top_themes}) {
			my $arr_ref;
			$arr_ref = load_anything($pool_dir."/".$topthemes) || [];
			$results{top_themes} = $arr_ref;
		}
		
		if ($parameters{articles}) {
			my @res;
			
			my $begin = (exists $parameters{articles_begin}) ? $parameters{articles_begin} : 0;
			
			my $end = (exists $parameters{articles_end}) ? $parameters{articles_end} : (get_count("pool")-1);
			
			if (exists $parameters{articles_one}) {
				$begin = $end = $parameters{articles_one};
			}
			
			foreach my $i ($begin..$end){
				my $article = load_anything($pool_dir."/".$i.$appendix) || \%all_article_properties;
				push (@res, $article);
			}
			$results{articles} = \@res;
		}
		
		if ($parameters{count}) {
			$results{count} = get_count("pool");
		}
		
		if ($parameters{count_bottom} or $parameters{all_counts}) {
			$results{all_counts}=load_anything($pool_dir."/inverse_counts.yaml.bz2");
			$results{count_bottom}=($pool_dir."/bottom.yaml.bz2");
		}
		
	} elsif (my $day = $parameters{day}) {
		#reading from archive
		if ($parameters{top_themes}) {
			my $arr_ref;
			$arr_ref = load_anything($database_dir."/".$day."/".$topthemes) || [];
			$results{top_themes} = $arr_ref;
		}
		
		if ($parameters{count}) {
			$results{count} = get_count($day);
		}
		
		
		
		if ($parameters{articles}) {
			if ($parameters{short}) {
				my @res;

				my $begin = (exists $parameters{articles_begin}) ? $parameters{articles_begin} : 0;

				my $end = (exists $parameters{articles_end}) ? $parameters{articles_end} : (get_count($day)-1);

				if (exists $parameters{articles_one}) {
					$begin = $end = $parameters{articles_one};
				}

				foreach my $i ($begin..$end){
					my $article = load_anything($database_dir."/".$day."/".$i.$appendix);
					if (!$article) {
						$article = \%all_article_properties;
					}
					push (@res, $article);
				}
				$results{articles} = \@res;
			} else {
				
				my $arr_ref;
				$arr_ref = load_anything($database_dir."/".$day."/".$archive) || [];

				if ((exists $parameters{articles_begin}) and exists $parameters{articles_end}) {
					my @splited = @{$arr_ref}[$parameters{articles_begin}..$parameters{articles_end}];
					$results{articles} = \@splited;
				} else {
					$results{articles} = $arr_ref;
				}
				
			}
		}
	}
	return \%results;
}

sub write_db {
	my %parameters = @_;
	my $res;
	if ($parameters{pool}) {
		if (exists $parameters{articles}) {
			my $i=0;
			if ($parameters{append}) {
				
				$res = my $i = get_count("pool");
				
			} elsif ($parameters{articles_begin}) { 
				
				$i = $parameters{articles_begin};
			}
			
			foreach my $article_ref (@{$parameters{articles}}) {
				dump_anything($pool_dir."/".$i.$appendix, $article_ref);
				$i++;
			}
		}
		if (exists $parameters{top_themes}) {
			dump_anything($pool_dir."/".$topthemes, $parameters{top_themes});
		}
		
		if (exists $parameters{count_bottom} and exists $parameters{all_counts}) {
			dump_anything($pool_dir."/inverse_counts.yaml.bz2", $parameters{all_counts});
			dump_anything($pool_dir."/bottom.yaml.bz2", $parameters{count_bottom});

		}
	} elsif (my $day = $parameters{day}) {
		#it ALWAYS rewrites EVERYTHING - so no appending / rewriting
		get_count($day); #this is just for creating directory
		
		if (exists $parameters{articles}) {
		
			dump_anything($database_dir."/".$day."/".$archive, $parameters{articles});
			
			for my $i (0..$#{$parameters{articles}}){
				
				my $article = $parameters{articles}->[$i];
				
				my @keys = map ({best_form=>$_->{best_form}, lemma=>$_->{lemma}}, @{$article->{top_keys}});
				
				dump_anything($database_dir."/".$day."/".$i.$appendix, {url=>($article->{url}), keys=>\@keys, title=>$article->{title}});
				
			}
		}
		if (exists $parameters{top_themes}) {
			dump_anything($database_dir."/".$day."/".$topthemes, $parameters{top_themes});
		}
		if (exists $parameters{count_bottom} and exists $parameters{all_counts}) {
			dump_anything($database_dir."/".$day."/inverse_counts.yaml.bz2", $parameters{all_counts});
			dump_anything($database_dir."/".$day."/bottom.yaml.bz2", $parameters{count_bottom});
			
			add_bottom($parameters{count_bottom});
			add_counts($parameters{all_counts});

		}
	}
	return $res; #sometimes i DO want to return something
}

sub null_day_counts {
	my $day = shift;
	
	my $all_counts_ref = load_anything($database_dir."/".$day."/inverse_counts.yaml.bz2") || {};
	remove_counts($all_counts_ref);
	my $bottom_ref = load_anything($database_dir."/".$day."/bottom.yaml.bz2") || {};
	remove_bottom($bottom_ref);
	
}

sub remove_counts {
	my $all_counts_ref = shift;
	my %original_counts_hash = %{(load_anything($all_counts_file) || {})};
	for my $key (keys %$all_counts_ref) {
		$original_counts_hash{$key}-=$all_counts_ref->{$key} ;
		delete $original_counts_hash{$key} if ($original_counts_hash{$key}==0);
	}
	dump_anything($all_counts_file, \%original_counts_hash); 
}

sub remove_bottom {
	my $all_counts_ref = shift;
	my %original_bottom_hash = %{(load_anything($bottom_file) || {})};
	for my $key (keys %$all_counts_ref) {
		if (exists $original_bottom_hash{$key}) {
			$original_bottom_hash{$key}-=$all_counts_ref->{$key} ;
			delete $original_bottom_hash{$key} if ($original_bottom_hash{$key}==0);
		}
	}
	dump_anything($bottom_file, \%original_bottom_hash); 
}

sub add_counts {
	my $all_counts_ref = shift;
	my %original_counts_hash = %{(load_anything($all_counts_file) || {})};
	for my $key (keys %$all_counts_ref) {
		$original_counts_hash{$key}+=$all_counts_ref->{$key};
	}
	dump_anything($all_counts_file, \%original_counts_hash); 
}
sub add_bottom {
	my $add_bottom_hash_ref = shift;
	my %original_bottom_hash = %{(load_anything($bottom_file) || {})};
	@original_bottom_hash{keys %$add_bottom_hash_ref} = values %$add_bottom_hash_ref;
	if ((keys %original_bottom_hash) > $bottom_count) {
		my @sorted = sort {$original_bottom_hash{$b} <=> $original_bottom_hash{$a}} keys %original_bottom_hash;
		for my $i (50..$#sorted) {
			delete $original_bottom_hash{$sorted[$i]};
		}
	}
	dump_anything($bottom_file, \%original_bottom_hash);
}

sub read_db_bottom {
	my %hash = %{load_anything($bottom_file) || {}};
	return %hash;
}

sub read_db_all_counts {
	my %hash = %{load_anything($all_counts_file) || {}};
	return %hash;
}

sub get_count {
	my $what = shift;
	my $dir = $database_dir."/".$what;
	if (!-d $dir) {
		if (!-d $database_dir) {
			mkdir $database_dir or die "making directory $database_dir not succesful.";
		}
		mkdir $dir or die "making directory $pool_dir not succesful.";
		return 0;
	} else {
		
		my $count=0;
		$count = scalar grep(/(^|\/)\d+\.yaml\.bz2$/, <$dir/*.yaml.bz2>);
		return $count;
	}
}



sub load_anything {
	
	
	my $where = shift;
	
	my $no_existence_warning = shift;
	
	if (!-e $where) {
		my_warning("Database", "load_anything - $where does not exist!!") unless ($no_existence_warning);
		return 0;
	}
	
	my $z = new IO::Uncompress::Bunzip2($where);
	
	if (!$z) {
		my_warning("Database", "load_anything - $where cannot be read for weird reason...");
		return 0;
	}
	
	my $all = do {local ($/); <$z>};
	close $z;
	
	my $result;
	if ($all) {
		eval {$result = Load($all)};
		
		if ($@) {
			my_warning("Database", "load_anything - some weird error given when loading $where - ".$@." :-(");
			return 0;
		}
		return $result;
	} else {
		return 0;
	}

}



sub dump_anything {
	my $where = shift;
	my $what = shift;
	

	# open my $z, "| bzip2 > $where";
	my $z = new IO::Compress::Bzip2($where);
	if (!$z) {
		my_warning("Database", "dump_anything - cannot create file ".$where);
		return;
	}	
	
	if (!$what) {
		my_warning ("Database", "dump_anything - \$what is empty :-(");
		return;
	}

	my $dumped;
	eval {$dumped = Dump($what)};
	if ($@) {
		my_warning("Database", "dump_anything - cannot dump when trying to write to ".$where."- ".$@." :-(");
	}
	
	print $z $dumped unless (!$what);
	close $z;
}

sub set_global {
	my $name=shift;
	my $contents= shift;
	open my $fh, ">", $database_dir."/".$name;
	print $fh $contents;
	close $fh;
}

sub get_global {
	my $name = shift;
	if (-e $database_dir."/".$name) {
		open my $fh, "<", $database_dir."/".$name;
		chomp (my $c = <$fh>);
		close $fh;
		return $c;
	} else {
		return "";
	}
}


sub archive_pool {
	
	my $day = get_day(1);
	
	my %r = %{read_db(pool=>1, top_themes=>1, articles=>1)};
	
	write_db(%r, day=>$day);
	
	`rm -r $pool_dir`;
}

1;