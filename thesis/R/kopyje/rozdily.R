Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")


posun = 20

vahy=c(1:(posun/2), (posun/2):1)

what_paint=c(1:length(x));
vahy=c(1:(posun/2), (posun/2):1)

prettify=function(zz) {rollapply(zoo(zz), width=posun, FUN=function(z) weighted.mean(z, vahy), na.pad = TRUE);}


kde<-scan("/Users/karelbilek/Desktop/Rploty/R_dnywhere_tfidf");
mesice<-scan("/Users/karelbilek/Desktop/Rploty/R_mesice_tfidf", what="char");

min=0;
max = 15;


plot(c(what_paint), c(0,rep(max, length(what_paint)-1)), type="n", xlab="Dny", ylab="Počet článků" , xaxt="n");
axis(1, at=kde, labels=mesice);


kresli_rozdil_s2<- function(jmeno, barva) {
	filename_s = paste("/Users/karelbilek/Desktop/Rploty/R_stop_special_", jmeno, sep="");
	filename_t = paste("/Users/karelbilek/Desktop/Rploty/R_tfidf_special_", jmeno, sep="");
	cely_s<-scan(filename_s)
	cely_t<-scan(filename_t)
	
	cely_r<-cely_s - cely_t;
	cely<-prettify(cely_r)
	
	lines(c(what_paint),cely[c(what_paint)],type="l", col=barva, lwd=3);

}


kreslis2 <- function(jmeno, barva) {
	filename = paste("/Users/karelbilek/Desktop/Rploty/R_stop_special_", jmeno, sep="");
	cely<-scan(filename)
	cely_sma<-prettify(cely)
	
	lines(c(what_paint),cely_sma[c(what_paint)],type="l", col=barva, lwd=3);
}

kreslis2_tf <- function(jmeno, barva) {
	filename = paste("/Users/karelbilek/Desktop/Rploty/R_tfidf_special_", jmeno, sep="");
	cely<-scan(filename)
	cely_sma<-prettify(cely)
	lines(c(what_paint),cely_sma[c(what_paint)],type="l", col=barva, lwd=3);
}

abline(v=kde, untf = FALSE, col="gray")

kreslis2("premier", "black")



kresli_rozdil_s2("premier", "blue")


kreslis2_tf("premier", "red")

legend(1, max, c("stop témata", "tf-idf témata",  "rozdíl" ), col=c("black", "red",  "blue"), lty=1, lwd=3);

