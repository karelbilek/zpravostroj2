package Zpravostroj::Other;

use YAML::XS qw(LoadFile);

use strict;
use warnings;

use File::Touch;
use File::Spec;
use utf8;
use DateTime;
use DateTime::Duration;
#use Text::Unaccent;


use base 'Exporter';
our @EXPORT = qw(get_day my_log my_warning split_size all_subthemes is_word  make_normal_word load_yaml_file read_option most_frequent read_information get_correction longest_correction);


	#!!!!!!!!!!!! ------ GLOBALS ------ !!!!!!!!!!!!
my ($option_ref) = load_yaml_file("configure.yaml");
my $warning_dir = read_option("warning_dir");


my $czechs="ÁČĎĚÉÍŇÓŘŠŤÚŮÝŽáčďěéíňóřšťúůýž";
	#!!!!!!!!!!!! ------ GLOBALS ------ !!!!!!!!!!!!
	
	
my $longest_correction=0;
my %corrections;
my $log_dir = read_option("log_dir");
	#!!!!!!!!!!!! ------ GLOBALS ------ !!!!!!!!!!!!


sub get_day {
	my $move = shift;
	
	if (!$move) {
		return DateTime->today->dmy;
	} else  {
		return (DateTime->today - DateTime::Duration->new(days=>$move))->dmy;
	}
}

sub get_time {
	my $now = DateTime->now;
	return (($now->hms()).($now->millisecond()));
}

sub my_warning {
	my $type = shift;
	my $what = shift;
	
	if (! -d $warning_dir) {mkdir $warning_dir or die "cannot mkdir $warning_dir\n";}
	
	my $day_dir = $warning_dir."/".get_day();
	
	if (!-d $day_dir) {mkdir $day_dir or die "cannot mkdir $day_dir\n";}
	
	my $warning_file = $day_dir."/".$type;
	
	touch $warning_file or die $warning_file." cannot be touched, dying\n";
	open (my $fh, ">>", $warning_file) or die $warning_file." cannot be opened, wonder why? Dying painfully\n";
	print {$fh} get_time()," - ", $what,"\n";
	close $fh;
}


sub my_log {
	my $type = shift;
	my $what = shift;
	mkdir $log_dir;
	my $day_dir = $log_dir."/".get_day();
	mkdir $day_dir;
	my $log_file = $day_dir."/".$type;
	open (my $fh, ">>", $log_file) or die $log_file." cannot be opened, wonder why? Dying painfully\n";
	print {$fh} get_time()," - ", $what,"\n";
	close $fh;
}


#workaround for weird split behaviour in scalar context - they say its not a bug, i think it is
sub split_size{my $r=shift;my @ol=split (" ", $r);return scalar @ol;}


sub load_yaml_file {
	my $name = shift;
	
	my ($volume, $directory) = File::Spec->splitpath( $INC{'Zpravostroj/Other.pm'} );
	my $whole_name = File::Spec->catpath( $volume, $directory, '../../'.$name );
	
	if (!-e $whole_name) {
		my_warning("Other", "load_yaml_file - file ".$whole_name." does not exists!");
		return "";
	}

	my $ref="";
	
	eval{$ref = LoadFile($whole_name)};
	if ($@) {
		my_warning("Other", "load_yaml_file - some strange error when reading ". $whole_name." - ".$@." :-(");
	}
	return $ref;
}

sub most_frequent {
	my @array=@_;
	my %appearances;
	for my $element (@array){$appearances{$element}++};
	return ((sort {$appearances{$b}<=>$appearances{$a}} @array)[0]);
	
}

sub read_option{
	my $what = shift;
	exists $option_ref->{$what} or die "Option $what does not exists.";
	return $option_ref->{$what};
}



sub read_information {
	my $what = shift;
	return load_yaml_file("informations/".$what.".yaml");
}

sub all_subthemes {
	my $delimit=shift;
	my @res;
	
	foreach my $theme (@_) {
		my @themes = split($delimit, $theme);
		while (@themes) {
			my @themes_c = @themes;
			while (@themes_c) {
				my $joined = join($delimit, @themes_c);
				push(@res, $joined) unless ($joined eq $theme);
				pop @themes_c;
			}
			shift @themes;
		}
	}
	return @res;
}

sub is_word {
	my $what = shift;
	return ($what =~ /^[A-Za-z0-9$czechs]+$/);
}


sub make_normal_word {

    my $text = shift;
    return unless defined $text;
    
    $text =~ s/^([^\-\.,_;\/\\\^\?:\(\)!]*).*$/$1/;
        #remove all weird letters
    	
    $text =~ s/ +$//;
        #remove final space(s)
	#$text = unac_string('UTF-8', lc $text);
	$text= lc $text;
	
    return $text;
}

sub load_corrections {
	my %read_corrections;
	if (my $correction_ref = read_information("corrections")) {
		%read_corrections = %{read_information("corrections")};
	}

	foreach my $correct_lemma (keys %read_corrections) {
		my $length = split_size($correct_lemma);
		$longest_correction = $length if ($length > $longest_correction);

		foreach my $correct_form (@{$read_corrections{$correct_lemma}}) {
			$corrections{$correct_form} = $correct_lemma;
		}
	}
}

sub get_correction {
	my $what=shift;
	if (!$longest_correction) {
		load_corrections
	}
	return 0 if (!exists $corrections{$what});
	
	return $corrections{$what};
}

sub longest_correction {
	if (!$longest_correction) {
		load_corrections;
	}
	return $longest_correction;
}

1;
