x<-scan("/Users/karelbilek/Desktop/RgraphX", what="char");
y<-scan("/Users/karelbilek/Desktop/RgraphY");

what_paint=c(1:5000);

what_print=c(1:30);


kde<-pretty(c(what_paint), 13)+1;


plot(c(what_paint), y[c(what_paint)], type="n", xlab="Lemmata", ylab="Procentuální zastoupení lemmatu" , xaxt="n");
axis(1, at=kde, labels=x[kde]);

lines(c(what_paint),y[c(what_paint)],type="l");

text(x=what_print, y=y[what_print], labels=x[what_print], pos=4)

