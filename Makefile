envelope_code := U+F0E0
brand_codes := U+F0E1,U+F09B,U+F16D,U+F39E,U+F2C6,U+F189,U+E61B,U+F167
UNAME_S := $(shell uname -s)

.DEFAULT_GOAL := help

CONTAINER_CLI ?= $(shell if command -v docker >/dev/null 2>&1; then echo docker; elif command -v container >/dev/null 2>&1; then echo container; else echo docker; fi)
CONTAINER_IMAGE ?= ignat-fi-build
CONTAINER_SERVE_NAME ?= ignat-fi-serve
CONTAINER_PLATFORM ?= linux/amd64
SITE_HOST ?= 127.0.0.1
SITE_PORT ?= 1111

ifeq ($(CONTAINER_CLI),container)
CONTAINER_RUN_PLATFORM_FLAGS ?= --platform $(CONTAINER_PLATFORM) --rosetta
CONTAINER_REMOVE_FLAG ?= --remove
else
CONTAINER_RUN_PLATFORM_FLAGS ?= --platform $(CONTAINER_PLATFORM)
CONTAINER_REMOVE_FLAG ?= --rm
endif

CONTAINER_RUN ?= $(CONTAINER_CLI) run $(CONTAINER_REMOVE_FLAG) \
	$(CONTAINER_RUN_PLATFORM_FLAGS) \
	--user "$$(id -u):$$(id -g)" \
	-e HOME=/tmp \
	-e npm_config_cache=/tmp/.npm \
	-e CLOUDFLARE_API_TOKEN \
	-v "$$(pwd):/site" \
	-w /site

WRANGLER ?= npx wrangler

ifeq ($(UNAME_S),Darwin)
SED_INPLACE ?= sed -i ''
else
SED_INPLACE ?= sed -i
endif

.PHONY: help
help: ## Show available commands
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {printf "\033[36m%-24s\033[0m %s\n", $$1, $$NF }' $(MAKEFILE_LIST)

.PHONY: install
install: ## Install local host build and deploy dependencies
	brew update
	brew upgrade
	brew install zola
	brew install npm
	brew install fonttools
	brew install brotli
	brew install zopfli
	brew cleanup
	npm install -g clean-css-cli wrangler

.PHONY: build
build: ## Build the Zola site
	zola build

.PHONY: build-fast
build-fast: build ## Alias for the default Zola build

.PHONY: serve
serve: ## Serve the Zola site locally
	zola serve --interface 0.0.0.0 --port $(SITE_PORT) --base-url http://$(SITE_HOST)

.PHONY: minify
minify: build ## Build and minify production assets
	cleancss -O2 --output ./public/css/main.min.css ./public/css/main.css
	cleancss -O2 --output ./static/css/main.min.css ./public/css/main.css
	rm -f ./public/css/main.css
	find ./public -name '*.html' -exec \
		$(SED_INPLACE) 's/css\/main.css/css\/main.min.css/g' {} +

	$(call subset_font,fa-solid-900,$(envelope_code))
	$(call subset_font,fa-brands-400,$(brand_codes))

.PHONY: deploy
deploy: minify ## Deploy production build to Cloudflare Pages
	$(WRANGLER) pages deploy public --project-name=ignat-fi

.PHONY: preview
preview: minify ## Deploy preview build to Cloudflare Pages preview branch
	$(WRANGLER) pages deploy public --project-name=ignat-fi --branch=preview

.PHONY: docker-image
docker-image: ## Build the local Docker build image
	$(CONTAINER_CLI) build --platform $(CONTAINER_PLATFORM) -t $(CONTAINER_IMAGE) .

.PHONY: docker-build
docker-build: docker-image ## Build the site inside Docker
	$(CONTAINER_RUN) $(CONTAINER_IMAGE) make build

.PHONY: docker-build-fast
docker-build-fast: docker-image ## Run the default Zola build inside Docker
	$(CONTAINER_RUN) $(CONTAINER_IMAGE) make build-fast

.PHONY: docker-minify
docker-minify: docker-image ## Build and minify production assets inside Docker
	$(CONTAINER_RUN) $(CONTAINER_IMAGE) make minify

.PHONY: docker-serve-stop
docker-serve-stop: ## Stop an existing local serve container on SITE_PORT
	@$(CONTAINER_CLI) stop --time 2 $(CONTAINER_SERVE_NAME) >/dev/null 2>&1 || true
	@$(CONTAINER_CLI) rm --force $(CONTAINER_SERVE_NAME) >/dev/null 2>&1 || true

.PHONY: docker-serve
docker-serve: docker-image docker-serve-stop ## Serve the site locally from Docker
	@$(CONTAINER_RUN) --detach --name $(CONTAINER_SERVE_NAME) --init --publish $(SITE_PORT):$(SITE_PORT) $(CONTAINER_IMAGE) make SITE_HOST=$(SITE_HOST) SITE_PORT=$(SITE_PORT) serve
	@echo "Serving at http://$(SITE_HOST):$(SITE_PORT). Press Ctrl-C to stop."
	@trap '$(CONTAINER_CLI) stop --time 2 $(CONTAINER_SERVE_NAME) >/dev/null 2>&1 || true; exit 0' INT TERM; \
	while $(CONTAINER_CLI) inspect $(CONTAINER_SERVE_NAME) >/dev/null 2>&1; do \
		sleep 1; \
	done

.PHONY: docker-preview
docker-preview: docker-image ## Deploy a Cloudflare Pages preview from Docker
	$(CONTAINER_RUN) $(CONTAINER_IMAGE) make WRANGLER=wrangler preview

.PHONY: docker-deploy
docker-deploy: docker-image ## Deploy production to Cloudflare Pages from Docker
	$(CONTAINER_RUN) $(CONTAINER_IMAGE) make WRANGLER=wrangler deploy

define subset_font
	pyftsubset "./static/webfonts/$(1).ttf" --output-file="./static/webfonts/$(1).subset.ttf" --layout-features='*' --unicodes=$(2)
	$(SED_INPLACE) 's/$(1).ttf/$(1).subset.ttf/g' ./static/css/main.min.css

	pyftsubset "./static/webfonts/$(1).ttf" --output-file="./static/webfonts/$(1).subset.woff2" --layout-features='*' --flavor=woff2 --with-zopfli --unicodes=$(2)
	$(SED_INPLACE) 's/$(1).woff2/$(1).subset.woff2/g' ./static/css/main.min.css

	mkdir -p ./public/webfonts
	cp "./static/webfonts/$(1).subset.ttf" "./public/webfonts/$(1).subset.ttf"
	cp "./static/webfonts/$(1).subset.woff2" "./public/webfonts/$(1).subset.woff2"
	$(SED_INPLACE) 's/$(1).ttf/$(1).subset.ttf/g' ./public/css/main.min.css
	$(SED_INPLACE) 's/$(1).woff2/$(1).subset.woff2/g' ./public/css/main.min.css

endef
