$w = "prace";

`rm $w.pdf`;

for my $f (<$w*>) {
	if ($f ne "$w.tex" and $f ne "$w.pdf" and $f ne "$w.bib") {
		system("rm $f");
	}
}

`rm texput.log`;

system("pdflatex $w");

system("bibtex $w");
system("pdflatex $w ");
system("pdflatex $w");
system("pdflatex $w");


for my $f (<$w*>) {
	if ($f ne "$w.tex" and $f ne "$w.pdf" and $f ne "$w.bib") {
		system("rm $f");
	}
}

`rm texput.log`;
