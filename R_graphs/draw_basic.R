
source("prepare.R"); 


draw <- function(what, h_lines,  y_title, width=7, height=7) {

	prepare(width=width, height=height);


	y<-scan(paste("../data/R_data/", what, sep=""));


	x=c(1:length(y));


	plot(x=x, y=y[x], type="n", xlab="Měsíce", ylab=y_title , xaxt="n");

	x_marks_places<-scan("../data/R_data/filtered_dates__places");

	x_marks_names<-scan("../data/R_data/filtered_dates__marks", what="char");

	axis(1, at=x_marks_places, labels=x_marks_names);

	abline(v=x_marks_places, untf = FALSE, col="gray");

	abline(h=h_lines, untf = FALSE, col="gray");


	lines(c(x),y[c(x)],type="l");
}

