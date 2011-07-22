Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")

posun = 20
vahy=c(1:(posun/2), (posun/2):1)
celadelka<-scan("/Users/karelbilek/Desktop/Rploty/R_dny_tfidf", what="char");
what_paint=c(1:length(celadelka));

prettify=function(zz) {rollapply(zoo(zz), width=posun, FUN=function(z) weighted.mean(z, vahy), na.pad = TRUE);}


min=0;
max = 25;


plot(c(what_paint), c(0,rep(max, length(what_paint)-1)), type="n", xlab="Dny", ylab="Počet článků" , xaxt="n");


kresli <- function(jmeno, barva) {
	filename = paste("/Users/karelbilek/Desktop/Rploty/R_stop_special_", jmeno, sep="");
	cely<-scan(filename)
	lines(c(what_paint),cely[c(what_paint)],type="l", col=barva);
}


kreslis2 <- function(jmeno, barva) {
	filename = paste("/Users/karelbilek/Desktop/Rploty/R_stop_special_", jmeno, sep="");
	cely<-scan(filename)
	cely_sma<-prettify(cely)
	lines(c(what_paint),cely_sma[c(what_paint)],type="l", col=barva, lwd=3);
}

kde<-scan("/Users/karelbilek/Desktop/Rploty/R_dnywhere_tfidf");
mesice<-scan("/Users/karelbilek/Desktop/Rploty/R_mesice_tfidf", what="char");
axis(1, at=kde, labels=mesice);
abline(v=kde, untf = FALSE, col="gray")

kresli("nehoda", "red")
kresli("premier", "blue")



kreslis2("nehoda", "red")

kreslis2("premier", "blue")

legend(1, max, c("nehoda", "premier"), col=c("blue", "red"), lty=1, lwd=3);
