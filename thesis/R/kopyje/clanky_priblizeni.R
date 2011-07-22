Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")

x<-scan("/Users/karelbilek/Desktop/Rploty/R_dny_stop", what="char");

kde<-scan("/Users/karelbilek/Desktop/Rploty/R_dnywhere_tfidf");
y<-scan("/Users/karelbilek/Desktop/Rploty/R_pocty");
mesice<-scan("/Users/karelbilek/Desktop/Rploty/R_mesice_tfidf", what="char");

posun = 20
vahy=c(1:(posun/2), (posun/2):1)

what_paint=c(70:140);

y_p = rollapply(zoo(y), width=posun, FUN=function(z) weighted.mean(z, vahy), na.pad = TRUE);



plot(c(what_paint), y[c(what_paint)], type="n", xlab="Dny", ylab="Počet článků" , xaxt="n");
axis(1, at=kde, labels=mesice);

abline(v=kde, untf = FALSE, col="gray")


lines(c(what_paint),y[c(what_paint)],type="l");

lines(c(what_paint),y_p[c(what_paint)],type="l", col="red", lwd=3);



what_print=(c(90:120))+1;

text(x=what_print, y=y[what_print], labels=x[what_print], pos=4)

