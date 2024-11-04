envelope_code := U+F0E0
brand_codes := U+F0E1,U+F09B,U+F16D,U+F39E,U+F2C6,U+F189,U+E61B,U+F167


.PHONY: install
install:
	brew update
	brew upgrade
	brew install zola
	brew install uv
	brew install npm
	brew install fonttools
	brew install brotli
	brew install zopfli

	npm install clean-css
	npm install -g glyphhanger


.PHONY: minify
minify:
	zola build
	cleancss -O2 --output ./static/css/main.min.css ./public/css/main.css

	$(call subset_font,fa-solid-900,$(envelope_code))
	$(call subset_font,fa-brands-400,$(brand_codes))


define subset_font
	pyftsubset "./static/webfonts/$(1).ttf" --output-file="static/webfonts/$(1).subset.ttf" --layout-features='*' --unicodes=$(2)
	sed -i '' 's/$(1).ttf/$(1).subset.ttf/g' ./static/css/main.min.css

	pyftsubset "./static/webfonts/$(1).ttf" --output-file="static/webfonts/$(1).subset.woff2" --layout-features='*' --flavor=woff2 --with-zopfli --unicodes=$(2)
	sed -i '' 's/$(1).woff2/$(1).subset.woff2/g' ./static/css/main.min.css

endef
