package Zpravostroj::Forker;
#Takovy muj pomocny modulek, co se mi ale osobne hrozne libi :) protoze mi setri spoustu prace

#reknu mu, kolik chci maximalne spustit threadu, a pak mu strkam pres run reference na procedury a on je spousti

#pricemz $f->run({...}) blokuje do doby, nez se thread SPUSTI, ale NEblokuje do doby, nez skonci
#proto je na konci prace s Forkerem NUTNE spustit $f->wait(), coz pocka na dobehnuti vsech threadu

#jako jinde v programu, thready myslim ve skutecnosti forky z modulu forks, ale jelikoz jsou vsude klicova slova jako "threads", tak se mi o tom pise lip jako o threadech. plus, syntaxe zustava z perlich, jinak nepouzitelnych, ithreadu.

use forks;
use forks::shared;

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

has 'currently_running' => (
	is=>'rw',
	isa=>'Int',
	default=>0
);

has 'waiting_subs' => (
	is=>'rw',
	isa=>'ArrayRef',
	default=>sub{[]}
);

sub BUILD {
	my $self = shift;
	say "SHARUJI V ".$self->name;
	share($self->{currently_running});
	say "SHARUJI V ".$self->name." DONE";
	$self->{currently_running}=0;
	my $w = is_shared($self->{currently_running});
	say "IS SHARED V ".$self->name." JE ".$w;
	
	
}



#cekam na skonceni vseho = dokud je 0 bezicich threadu
sub wait {
	my $s = shift;
	
	while (!$s->is_all_completed()) {
		sleep(1);		
		$s->check_waiting();
	}
}

sub get_curr_running {
	my $self = shift;
	say "PTAM SE V ".$self->name;
	
	if (!is_shared($self->{currently_running})) {
		say "OMG verze GCR - bylo ".$self->{currently_running};
		share($self->{currently_running});
		$self->{currently_running}=0;
		share($self->{currently_running});
		$self->{currently_running}=1;
		share($self->{currently_running});
		$self->{currently_running}=0;
		share($self->{currently_running});
	}
	
	my $w = is_shared($self->{currently_running});
	say "IS SHARED V ".$self->name." JE ".$w;
	
	
	lock($self->{currently_running});
	
	say "PTAM SE V ".$self->name." DONE";
	
	return $self->currently_running;
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
	
	if (!is_shared($s->{currently_running})) {
		say "OMG verze ADT - bylo ".$s->{currently_running};
		share($s->{currently_running});
	}
	
	{
		lock($s->{currently_running});
		$s->{currently_running}++;
	}
	
	my $thread = threads->new(sub {
		eval{$sub->();};
		if ($@) {
			say "ERROR ERROR ERROR - died with $@";
		}
		lock($s->{currently_running});
		$s->{currently_running}--;
	});
	#say "CREATED THREAD ".$s->name;
	$thread->detach();
	#say "DETACHED THREAD ".$s->name;	
}


#projede thready a smaze mrtvolky
sub check_waiting {
	my $s = shift;
	
	my $subs = $s->how_many_free_to_run();
	
	for (1..$subs) {
		if (scalar @{$s->waiting_subs} > 0) {
			my $sub = shift @{$s->waiting_subs};
			$s->add_to_threads($sub);
		}
	}
	
	if ($subs>0 and scalar @{$s->waiting_subs} > 0) {
		$s->check_waiting();
	}
}

sub run {
	
	my $s = shift;
	#say "LOCK RUN 2 ".$s->name;
	
	my $sub = shift;
	#say "LOCK RUN 3".$s->name;
	
	{
	
		#say "LOCK RUN 4".$s->name;
	
		if ($s->how_many_free_to_run()>0) {
		
			#say "LOCK RUN 5".$s->name;
		
			$s->add_to_threads($sub);
			
			#say "LOCK RUN 6".$s->name;
			
		} else {
			push @{$s->waiting_subs}, $sub;
		}
		
		#say "LOCK RUN 7".$s->name;
		
		$s->check_waiting();
			#check_waiting tady - MYSLIM - nutny neni, ale nicemu nevadi
			
			#say "LOCK RUN 8".$s->name;
			
	}
	
	#say "LOCK RUN 9".$s->name;

	
}

__PACKAGE__->meta->make_immutable;
