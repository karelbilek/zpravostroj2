source("prepare.R");

do_all <- function (width=7, height=3.7, max_y, lines_y, from=0, to=0, detailed_y=0, type, words, colors, smooth, smoothing_alpha=0.1) {

	prepare(width=width, height=height);
	
	#I have no other way to find out all the length, so I take some file that I know has one line for every day
	y_size<-length(scan("../data/R_data/all_dates"));

	if (from==0) {
		from=1;
	}
	if (to==0) {
		to=y_size;
	}
	x=c(from:to);

	y_reference = c(0,rep(max_y, length(x)-1));

	smooth_function <- function(v) {
		result<-c(v[1])

		for (i in v[2:length(v)]) {
			nw<-(1-smoothing_alpha)*result[length(result)]+smoothing_alpha*i;
			result<-c(result, nw);
		}
	
		return(result);
	}


	#It won't paint the lines, just the axes
	plot(x=x, y=y_reference, type="n", xlab="Měsíce", ylab="Počet článků" , xaxt="n");

	paint <- function(word, type, is_smoothed, color) {
		filename = paste("../data/R_data/word_", type, "_", word, sep="");
		data<-scan(filename)
		
		if (is_smoothed==0) {
			lines(x= x,y=data[x],type="l", col=color);
		} else {
			data_smoothed <- smooth_function(data);
			lines(x = x,y=data_smoothed[x], type="l", col=color, lwd=3);
			if (is_smoothed==2) {
				lines(x = x,y=data[x], type="l", col=color, lwd=1);
			}
		}
	}
	if (detailed_y==0) {
		x_marks_places<-scan("../data/R_data/filtered_dates__places");

		x_marks_names<-scan("../data/R_data/filtered_dates__marks", what="char");

		axis(1, at=x_marks_places, labels=x_marks_names);
		abline(v=x_marks_places, untf = FALSE, col="gray");

	} else {
		all_dates<-scan("../data/R_data/all_dates");
		where = pretty(x, n=15)+1;
		
		axis(1, at=where, labels=all_dates[where]);
		abline(v=where, untf = FALSE, col="gray");
	}
	

	abline(h=lines_y, untf = FALSE, col="gray");

	
	for (i in 1:length(words)) {
		paint(word=words[i], type=type, is_smoothed=smooth, color=colors[i]);
	}
	
	if (smooth!=0) {
		legend(from, max_y, words, col=colors, lty=1, lwd=3, bg="transparent");
	} else {
		legend(from, max_y, words, col=colors, lty=1, lwd=1, bg="transparent");
	}
	
	
}

#do_all(max_y=25, lines_y=c(5,10,15,20), type="stop", words=c("premier", "nehoda"), colors=c("blue", "red"), smooth=1);
