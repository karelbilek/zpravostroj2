source("prepare.R");

do_all <- function (width=7, height=3.7, max_y=15, lines_y=c(5,10,15), word, smoothing_alpha=0.1) {

	prepare(width=width, height=height);
	
	#I have no other way to find out all the length, so I take some file that I know has one line for every day
	y_size<-length(scan("../data/R_data/all_dates"));

	x=c(1:y_size);

	y_reference = c(0,rep(max_y, y_size-1));

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

	tf_idf_filename = paste("../data/R_data/word_tf_idf_", word, sep="");
	tf_idf_data<-scan(tf_idf_filename)
	
	stop_filename = paste("../data/R_data/word_stop_", word, sep="");
	stop_data<-scan(stop_filename)
	
	rozdil_data<-stop_data - tf_idf_data;
	
	
	paint <- function(data, color) {
		data_smoothed <- smooth_function(data);
		lines(x = x,y=data_smoothed[x], type="l", col=color, lwd=3);
		
		
	}
	
	x_marks_places<-scan("../data/R_data/filtered_dates__places");

	x_marks_names<-scan("../data/R_data/filtered_dates__marks", what="char");

	axis(1, at=x_marks_places, labels=x_marks_names);

	abline(v=x_marks_places, untf = FALSE, col="gray");

	abline(h=lines_y, untf = FALSE, col="gray");

	paint(stop_data, "black");
	paint(tf_idf_data, "red");
	paint(rozdil_data, "blue");

	legend(1, max_y, c("stop témata", "tf-idf témata", "rozdíl"), col=c("black", "red", "blue"), lty=1, lwd=3, bg="transparent");
	
	
	
}

#do_all(max_y=25, lines_y=c(5,10,15,20), type="stop", words=c("premier", "nehoda"), colors=c("blue", "red"), smooth=1);
