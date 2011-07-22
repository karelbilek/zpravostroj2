Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")

x<-scan("/Users/karelbilek/Desktop/Rploty/R_dny_less_tfidf", what="char");

posun = 20

what_paint=c(80:150);
vahy=c(1:(posun/2), (posun/2):1)
prettify=function(zz) {rollapply(zoo(zz), width=posun, FUN=function(z) weighted.mean(z, vahy), na.pad = TRUE);}



kde<-pretty(c(what_paint), 10)+1;

min=0;
max = 50;


plot(c(what_paint), c(0,rep(max, length(what_paint)-1)), type="n", xlab="Dny", ylab="Počet článků" , xaxt="n");
axis(1, at=kde, labels=x[kde]);


kresli <- function(jmeno, barva) {
	filename = paste("/Users/karelbilek/Desktop/Rploty/R_tfidf_special_", jmeno, sep="");
	cely<-scan(filename)
	lines(c(what_paint),cely[c(what_paint)],type="l", col=barva);
}


texty=c();
barvy=c();

kreslis2 <- function(jmeno, barva) {
	filename = paste("/Users/karelbilek/Desktop/Rploty/R_tfidf_special_", jmeno, sep="");
	cely<-scan(filename)
	cely_sma<-prettify(cely)
	lines(c(what_paint),cely_sma[c(what_paint)],type="l", col=barva, lwd=3);
	
	texty<<-c(texty, jmeno);
	barvy<<-c(barvy, barva);
}



kreslis2("ods", "blue")
kresli("ods", "blue")

kreslis2("cssd", "red")
kresli("cssd", "red")


kreslis2("demokrat", "deeppink2")
kresli("demokrat", "deeppink2")


kreslis2("volebni", "green")
kresli("volebni", "green")


legend(80, max, texty, col=barvy, lty=1, lwd=3);

