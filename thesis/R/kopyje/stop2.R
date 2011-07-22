Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")

y<-scan("/Users/karelbilek/Desktop/Rploty/R_podily_stop");

posun = 20
vahy=c(1:(posun/2), (posun/2):1)


what_paint=c(1:length(y));
prettify=function(zz) {rollapply(zoo(zz), width=posun, FUN=function(z) weighted.mean(z, vahy), na.pad = TRUE);}

y_p = prettify(y);


kde<-pretty(c(what_paint), 10)+1;


plot(c(what_paint), y[c(what_paint)], type="n", xlab="Dny", ylab="Průměrný počet témat na článek" , xaxt="n");

kde<-scan("/Users/karelbilek/Desktop/Rploty/R_dnywhere_tfidf");
mesice<-scan("/Users/karelbilek/Desktop/Rploty/R_mesice_tfidf", what="char");
axis(1, at=kde, labels=mesice);
abline(v=kde, untf = FALSE, col="gray")

lines(c(what_paint),y[c(what_paint)],type="l");

lines(c(what_paint),y_p[c(what_paint)],type="l", col="red", lwd=3);

#what_print=pretty(c(what_paint), 20)+1;

#text(x=what_print, y=y[what_print], labels=x[what_print], pos=4)

