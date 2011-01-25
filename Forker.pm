package Forker;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

has 'size' => (
	is=>'ro',
	required=>1,
	isa=>'Int'
);

has 'threads' => (
	is=>'rw',
	isa=>'ArrayRef',
	default=>sub{[]}
);

sub wait {
	my $s = shift;
	$s->wait_until(0);
}

sub wait_until {
	my $s = shift;
	my $how = shift;
	
	while (scalar @{$s->threads} > $how) {
		sleep(1);
		my @newthreads = grep {$_->is_running()} @{$s->threads};
		$s->threads(\@newthreads);
	}
}

sub run {
	my $s = shift;
	my $sub = shift;
	
	$s->wait_until($s->size);
	
	
	
	my $thread = threads->new($sub);
	
	$thread->detach();
	push @{$s->threads}, $thread;
	
	my @newthreads = grep {$_->is_running()} @{$s->threads};
	$s->threads(\@newthreads);
	
	
}

__PACKAGE__->meta->make_immutable;
