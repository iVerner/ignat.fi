.PHONY: minify
minify:
	npx lightningcss --minify --bundle ./static/css/main.css -o ./static/css/main.min.css
