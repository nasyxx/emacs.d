EMACS ?= emacs

all: help
.PHONY: all

## Generate all
generate: init.el bootstrap core editor tools langs ui org
.PHONY: generate


## Generate init.el from literate-config/README.org
init.el: literate-config/README.org
	@echo "Generate init.el from literate-config/README.org"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "init")'


## Generate bootstrap from literate-config/bootstrap/README.org
config/nasy-bootstrap.el: literate-config/bootstrap/README.org
	@echo "Generate bootstrap from literate-config/bootstrap/README.org"
	@rm -rf config/core var/org/timestamps/bootstrap.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "bootstrap")'

## Generate bootstrap from literate-config/bootstrap/README.org
bootstrap: config/nasy-bootstrap.el


## Generate core from literate-config/core
config/core: $(wildcard literate-config/core/*.org)
	@echo "Generate core from literate-config/core"
	@rm -rf config/core var/org/timestamps/core.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "core")'

## Generate core from literate-config/core
core: config/core


## Generate editor from literate-config/editor
config/editor: $(wildcard literate-config/editor/*.org)
	@echo "Generate editor from literate-config/editor"
	@rm -rf config/editor var/org/timestamps/editor.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "editor")'

## Generate editor from literate-config/editor
editor: config/editor


## Generate tools from literate-config/tools
config/tools: $(wildcard literate-config/tools/*.org)
	@echo "Generate tools from literate-config/tools"
	@rm -rf config/tools var/org/timestamps/tools.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "tools")'

## Generate tools from literate-config/tools
tools: config/tools


## Generate langs from literate-config/langs
config/langs: $(wildcard literate-config/langs/*.org)
	@echo "Generate langs from literate-config/langs"
	@rm -rf config/langs var/org/timestamps/langs.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "langs")'

## Generate langs from literate-config/langs
langs: config/langs


## Generate org from literate-config/org
config/org: $(wildcard literate-config/org/*.org)
	@echo "Generate org from literate-config/org"
	@rm -rf config/org var/org/timestamps/org.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "org")'

## Generate org from literate-config/org
org: config/org


## Generate ui from literate-config/ui
config/ui: $(wildcard literate-config/ui/*.org)
	@echo "Generate ui from literate-config/ui"
	@rm -rf config/ui var/org/timestamps/ui.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "ui")'

## Generate ui
ui: config/ui
.PHONY: bootstrap core editor tools langs ui org


# Old Generate init.el from README.org
old-generate:
	@echo "Generate init.el from README.org and literate-config.org."
	@mkdir -p custom && \
		$(EMACS) -Q --batch --find-file "README.org" -f "org-babel-tangle"
	@$(EMACS) -Q --batch --find-file "literate-config.org" -f "org-org-export-to-org" && \
		$(EMACS) -Q --batch --find-file "literate-config.org.org" -f "org-babel-tangle" && \
		rm -rf "literate-config.org.org" "literate-config.org.org~"
	@$(EMACS) -Q --batch --find-file "extra/README.org" -f "org-babel-tangle"
	@echo "If you want to customize, you can simply change/create custom/user-config.el"
.PHONY: old-generate


## clean build (var/org/timestamps/ & config/)
clean-build:
	rm -rf var/org/timestamps
	rm -rf config


## Clean straight (straight/)
clean-straight:
	rm -rf straight
.PHONY: clean-build


## clean all build straight
clean-all: clean-build clean-straight
.PHONY: clean-all


## Update config
update: clean-all
	git pull && make generate
.PHONY: update


# Update docs
docs:
	org2html README.org && git checkout gh-pages && mv README.html index.html && git commit -am "Update docs." && git push && git checkout master


# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

TARGET_MAX_CHAR_NUM=20

## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\.\_0-9%]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
		  helpCommand = $$1; sub(/:$$/, "", helpCommand); \
		  helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
		  printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
.PHONY: help
