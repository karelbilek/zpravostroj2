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

#mnozstvi povolenych threadu
has 'size' => (
	is=>'ro',
	required=>1,
	isa=>'Int'
);

#thready samotne
has 'threads' => (
	is=>'rw',
	isa=>'ArrayRef',
	default=>sub{[]}
);

#cekam na skonceni vseho = dokud je 0 bezicich threadu
sub wait {
	my $s = shift;
	$s->_wait_until(0);
}

#cekam, dokud neni HOW nebo mene bezicich threadu
sub _wait_until {
	my $s = shift;
	my $how = shift;
	
	while (scalar @{$s->threads} > $how) {
		sleep(1);
		$s->clean_up();
			#clean_up tady nutny!
	}
}

#projede thready a smaze mrtvolky
sub clean_up {
	my $s = shift;
	my @newthreads = grep {$_->is_running()} @{$s->threads};
	$s->threads(\@newthreads);
}

sub run {
	my $s = shift;
	my $sub = shift;
	
	#tady muze blokovat
	$s->_wait_until($s->size);
	
	
	my $thread = threads->new($sub);
	
	$thread->detach();
	push @{$s->threads}, $thread;
	
	$s->clean_up();
		#clean_up tady - MYSLIM - nutny neni, ale nicemu nevadi
	
}

__PACKAGE__->meta->make_immutable;
