Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")


posun = 20
vahy=c(1:(posun/2), (posun/2):1)
celadelka<-scan("/Users/karelbilek/Desktop/Rploty/R_dny_tfidf", what="char");
what_paint=c(1:length(celadelka));
prettify=function(zz) {rollapply(zoo(zz), width=posun, FUN=function(z) weighted.mean(z, vahy), na.pad = TRUE);}


min=0;
max = 30;


plot(c(what_paint), c(0,rep(max, length(what_paint)-1)), type="n", xlab="Vybrané dny", ylab="Počet článků" , xaxt="n");

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

kde<-scan("/Users/karelbilek/Desktop/Rploty/R_dnywhere_tfidf");
mesice<-scan("/Users/karelbilek/Desktop/Rploty/R_mesice_tfidf", what="char");
axis(1, at=kde, labels=mesice);
abline(v=kde, untf = FALSE, col="gray")




kreslis2("ods", "blue")

kreslis2("cssd", "red")

kreslis2("blesk", "green")

kreslis2("paroubek", "black")
kreslis2("necas", "cyan")
kreslis2("fischer", "yellow")

kreslis2("demokrat", "deeppink2")


legend(1, max, texty, col=barvy, lty=1, lwd=3);
