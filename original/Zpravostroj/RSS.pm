package Zpravostroj::RSS;

use warnings;
use strict;
use XML::RAI;
use Encode;
use YAML::XS qw(LoadFile DumpFile);
use File::Touch;

use Zpravostroj::Other;
use Zpravostroj::WebReader;
use utf8;

use base 'Exporter';
our @EXPORT = qw(get_all_links);

my $RSS_address=read_option("RSS_address");
my $RSS_kept =  read_option("RSS_kept");

sub get_filename {
	my $source_name = shift;
	my $result = $RSS_address."/".$source_name.".yaml";
	return $result;
}

sub get_new_links{
	my $source=shift;
	
	my %options = @_; #if there is a limit (just for testing)
	my $content = read_from_web ($source, 1);
	
	my_log("RSS", "new_links - let's try and eval the guy");
	my $rai;
	eval { $rai = XML::RAI->parse($content);};
	
	if ($@) {
		my_log("RSS", "new_links the guy really has issues! $@");
	} else {
		my_log("RSS", "new_links - it JUST WORKS!");
	}
		
	my $source_name = lc $source;
	$source_name =~ s/^http:\/\/([^\.]*\.)*([^\.]*)\.cz.*$/$+/;	
	
	my @visited_arr;
	
	my_log("RSS", "new_links - this is actually quite boring");
	
	if (-e (my $filename = get_filename($source_name))) {
		@visited_arr = @{LoadFile($filename)};
	}
	
	
	my %visited_hash;
	@visited_hash{@visited_arr}=();
	
	my @results;
	my $count=0;
	
	my @items;
	
	my_log("RSS", "new_links - let's try and eval the guy for the 2nd time");
	eval {@items = @{$rai->items};};
			#in VERY rare occasions XML::RAI just cannot parse RSS
			#I wont force it to
	if ($@) {
		my_log("RSS", "new_links the guy really has issues! $@");
	} else {
		my_log("RSS", "new_links - it JUST WORKS!");
	}
	
	my_log("RSS", "new_links will do some boring stuff");
	
	foreach my $item (@items) {
		last if (($options{"limit"}) and ($count>=$options{"limit"}));
		$count++;
		push (@results, $item->link()) unless (exists $visited_hash{$item->link()});
	}
	
	
	
	unshift (@visited_arr, @results);
	if (scalar @visited_arr > $RSS_kept) {
		splice (@visited_arr, $RSS_kept);
	}
	
	
	
	DumpFile(get_filename($source_name), \@visited_arr);
	
	my_log("RSS", "new_links Dan");
	return map ({url=>$_}, @results);
	
}

sub get_all_links {
	my @RSS_sources = @{read_option("RSS_sources")};
	my @result;
	for my $source (@RSS_sources) {
		my_log("RSS", "all_links - let's try source $source rite?");
		eval {push (@result, get_new_links($source))};
		if ($@) {
			my_warning("RSS", "all_links - error downloading $source - $@");
		} else {
			my_log("RSS", "all_links - all OK and fine");
		}
	}
	my_log("RSS", "all_links - Dan.");
	return @result;
}
