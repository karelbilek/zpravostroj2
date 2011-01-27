package Zpravostroj::Forker;
#Takovy muj pomocny modulek, co se mi ale osobne hrozne libi :) protoze mi setri spoustu prace

#reknu mu, kolik chci maximalne spustit threadu, a pak mu strkam pres run reference na procedury a on je spousti

#pricemz $f->run({...}) blokuje do doby, nez se thread SPUSTI, ale NEblokuje do doby, nez skonci
#proto je na konci prace s Forkerem NUTNE spustit $f->wait(), coz pocka na dobehnuti vsech threadu

#jako jinde v programu, thready myslim ve skutecnosti forky z modulu forks, ale jelikoz jsou vsude klicova slova jako "threads", tak se mi o tom pise lip jako o threadech. plus, syntaxe zustava z perlich, jinak nepouzitelnych, ithreadu.

use forks;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use Globals;

#mnozstvi povolenych threadu
has 'size' => (
	is=>'ro',
	required=>1,
	isa=>'Int'
);

has 'name' => (
	is=>'ro',
	required=>0,
	isa=>'Str'
);

has 'threads' => (
	is=>'rw',
	isa=>'ArrayRef',
	default=>sub{[]}
);

has 'waiting_subs' => (
	is=>'rw',
	isa=>'ArrayRef',
	default=>sub{[]}
);



#cekam na skonceni vseho = dokud je 0 bezicich threadu
sub wait {
	my $s = shift;
	
	while (!$s->is_all_completed()) {
		sleep(1);		
		$s->check_waiting();
	}
}

sub get_curr_running {
	my $s = shift;
	
	my @threads = grep {$_->is_running()} @{$s->threads};
	$s->threads(\@threads);
	
	return scalar @threads;
}

sub is_all_completed {
	my $s = shift;
	
	return (($s->get_curr_running == 0) and (scalar @{$s->waiting_subs} == 0));
}

sub how_many_free_to_run {
	my $s = shift;
	return ($s->size - $s->get_curr_running);
}


sub add_to_threads {
	my $s = shift;
	my $sub = shift;
	#say "ADD TO THREADS ".$s->name;
	
	my $thread = threads->new(sub {
		eval{$sub->();};
		if ($@) {
			print "Died with $@\n";
		}
	});
	$thread->detach();
	push @{$s->threads}, $thread;
	say "Stvoril jsem novy thread s cislem ",$thread->tid();
}


sub check_waiting {
	my $s = shift;
	
	
	my $subs = $s->how_many_free_to_run();
	
	
	my $added=0;
	
	for (1..$subs) {
		if (scalar @{$s->waiting_subs} > 0) {
			$added=1;
			say "spoustim dalsi";
			my $sub = shift @{$s->waiting_subs};
			$s->add_to_threads($sub);
		} 
	}
	
	if ($added) {
		$s->check_waiting();
	} 
}

sub run {
	
	my $s = shift;
	
	my $sub = shift;
	
	say "In forker - jdu posilat";
	
	my $f = $s->how_many_free_to_run();
	say "how many free to run vychazi na $f";
	
	if ($f>0) {
		
		say "Muzu tedy spustit.";
		$s->add_to_threads($sub);
		
	} else {
		
		say "Ukladam do cekajicich.";
		push @{$s->waiting_subs}, $sub;
	}
	
	
	$s->check_waiting();
	
	
}

__PACKAGE__->meta->make_immutable;
