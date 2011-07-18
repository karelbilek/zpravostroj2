prepare <- function (width=7, height=7) {
	Sys.setlocale(category = "LC_ALL", locale = "cs_CZ.utf8")
			  
	cairo_pdf(width=width, height=height);
}