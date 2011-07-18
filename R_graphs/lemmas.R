source("prepare.R"); prepare(width=10.3, height=7.65);

do_graph<-function(count=0) {

	x<-scan("../data/R_data/lemmas", what="char");
	y<-scan("../data/R_data/lemma_counts");

	if (count==0) {
		what_paint = c(1:length(x))
	} else {
		what_paint=c(1:5000);
	}

	what_print=c(1:30);


	x_labels<-pretty(what_paint, 13)+1;


	plot(what_paint, y[what_paint], type="n", xlab="Lemmata", ylab="Procentuální zastoupení lemmatu" , xaxt="n");
	axis(1, at=x_labels, labels=x[x_labels]);

	lines(what_paint,y[what_paint],type="l");

	text(x=what_print, y=y[what_print], labels=x[what_print], pos=4)

}