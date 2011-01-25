sub is_last_end {
	if (!-e "write_out") {
		return 0;
	} else {
		my $w = `tail -1 write_out`;
		if ($w=~/end/) {
			return 1;
		} else {
			return 0;
		}
	}
}

$|=1;
unlink "write_out";
while (!is_last_end()) {
	system("perl review.pl >> write_out");
	if (!is_last_end()) {
		print "Spadlo! Jedu znova\n";
	} else {
		print "Hotovo v poradku!\n";
	}
}