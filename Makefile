.PHONY: minify
minify:
	cleancss -O1 --output ./static/css/main.min.css ./static/css/main.css
	fontmin --text "" ./static/webfonts/fa-solid-900.ttf > ./static/webfonts/fa-solid-900.min.ttf
	fontmin --text "" ./static/webfonts/fa-brands-400.ttf > ./static/webfonts/fa-brands-400.min.ttf