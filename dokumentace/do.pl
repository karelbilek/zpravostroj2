$w = "dokumentace";

`rm dokumentace.html`;

for my $f (<$w*>) {
	if ($f ne "$w.tex" and $f ne "$w.html") {
		system("rm $f");
	}
}

`rm texput.log`;

system("hevea $w");
system("hevea $w");


for my $f (<$w*>) {
	if ($f ne "$w.tex" and $f ne "$w.html") {
		system("rm $f");
	}
}

`rm texput.log`;
