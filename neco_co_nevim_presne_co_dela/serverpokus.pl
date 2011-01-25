use forks;


my $thread = threads->new( sub {    
	use TectoServer;

	$SIG{'KILL'} = sub { threads->exit(); }; 
    TectoServer::run;
} );

<>;

	$thread->kill('KILL')->detach();
