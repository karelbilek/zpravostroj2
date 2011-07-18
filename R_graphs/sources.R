source("prepare.R"); prepare(width=8.1, height=2.93);

#totally different from the rest of graphs

library(ggplot2);

dataframe=c();
dataframe_podil = c();


do_graph<-function(news, colors) {

	

	x_marks_places<-scan("../data/R_data/filtered_dates__places");
	x_marks_names<-scan("../data/R_data/filtered_dates__marks", what="char");

	y_size<-length(scan("../data/R_data/all_dates"));

	add_to_frame<-function(source) {
		vector <- scan(paste("../data/R_data/news_source_", source, sep=""));
		dataframe <<- rbind(dataframe, data.frame(hodnoty=vector, popis=source, x=1:y_size))
	}

	add_more_to_frame<-function(vector) {
		for (name in vector) {
			add_to_frame(name);
		}
	}
	1;

	add_more_to_frame(news);

	for (day in unique(dataframe$x)) {
		counts_day = subset(dataframe, x==day);
		summ = sum(counts_day$hodnoty);
		counts_day$hodnoty = counts_day$hodnoty/summ;
		dataframe_podil <<- rbind(dataframe_podil, counts_day)
	
	}


	p <- ggplot(dataframe_podil, aes(x, hodnoty)) + scale_x_continuous(labels=x_marks_names, breaks=x_marks_places, name="Měsíce") + scale_y_continuous(name="Poměr počtu článků") + scale_fill_manual(values = colors) + scale_colour_manual(values = colors) + coord_cartesian(ylim=0:1)

	5;
	p + geom_area(aes(colour = popis, fill= popis), position = 'stack')
}
