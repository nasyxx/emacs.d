EMACS ?= emacs

all: help
.PHONY: all

## Generate all
generate: early-init user-config init bootstrap core editor tools langs ui org app
.PHONY: generate


## Generate early-init.el from literate-config/early-init.org
./early-init.el: literate-config/early-init.org
	@echo "Generate early-init.el from literate-config/early-init.org"
	@rm -rf var/org/timestamps/early-init.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "early-init")'

## Generate early-init.el from literate-config/early-init.org
early-init: ./early-init.el


## Generate init.el from literate-config/README.org
./init.el: literate-config/README.org
	@echo "Generate init.el from literate-config/README.org"
	@rm -rf var/org/timestamps/init.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "init")'

## Generate init.el from literate-config/README.org
init: ./init.el


## Generate user-config-example.el from README.org
custom/user-config-example.el: README.org
	@echo "Generate user-config-example.el from README.org"
	@rm -rf var/org/timestamps/user-config-example.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "custom")'

## Generate user-config-example.el from README.org
user-config: custom/user-config-example.el


## Generate bootstrap from literate-config/bootstrap/README.org
config/nasy-bootstrap.el: literate-config/bootstrap/README.org
	@echo "Generate bootstrap from literate-config/bootstrap/README.org"
	@rm -rf config/nasy-bootstrap.el var/org/timestamps/bootstrap.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "bootstrap")'

## Generate bootstrap from literate-config/bootstrap/README.org
bootstrap: config/nasy-bootstrap.el


## Generate core from literate-config/core
config/core: $(wildcard literate-config/core/*.org)
	@echo "Generate core from literate-config/core"
	@rm -rf config/core straight/build/nasy-core var/org/timestamps/core.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "core")'

## Generate core from literate-config/core
core: config/core


## Generate editor from literate-config/editor
config/editor: $(wildcard literate-config/editor/*.org)
	@echo "Generate editor from literate-config/editor"
	@rm -rf config/editor straight/build/nasy-editor var/org/timestamps/editor.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "editor")'

## Generate editor from literate-config/editor
editor: config/editor


## Generate tools from literate-config/tools
config/tools: $(wildcard literate-config/tools/*.org)
	@echo "Generate tools from literate-config/tools"
	@rm -rf config/tools straight/build/nasy-tools var/org/timestamps/tools.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "tools")'

## Generate tools from literate-config/tools
tools: config/tools


## Generate langs from literate-config/langs
config/langs: $(wildcard literate-config/langs/*.org)
	@echo "Generate langs from literate-config/langs"
	@rm -rf config/langs straight/build/nasy-langs var/org/timestamps/langs.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "langs")'

## Generate langs from literate-config/langs
langs: config/langs


## Generate org from literate-config/org
config/org: $(wildcard literate-config/org/*.org)
	@echo "Generate org from literate-config/org"
	@rm -rf config/org straight/build/nasy-org var/org/timestamps/org.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "org")'

## Generate org from literate-config/org
org: config/org


## Generate ui from literate-config/ui
config/ui: $(wildcard literate-config/ui/*.org)
	@echo "Generate ui from literate-config/ui"
	@rm -rf config/ui straight/build/nasy-ui var/org/timestamps/ui.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "ui")'

## Generate ui
ui: config/ui

## Generate ui from literate-config/app
config/app: $(wildcard literate-config/app/*.org)
	@echo "Generate app from literate-config/app"
	@rm -rf config/app straight/build/nasy-app var/org/timestamps/app.cache
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "app")'

## Generate app
app: config/app

.PHONY: bootstrap core editor tools langs ui org app


## clean build (var/org/timestamps/ & config/)
clean-build:
	rm -rf var/org/timestamps
	rm -rf config


## Clean straight (straight/)
clean-straight:
	rm -rf straight


## clean all build straight
clean-all: clean-build clean-straight
.PHONY: clean-all clean-straight clean-build


## Rebuild
rebuild: clean-all
	make generate -j
.PHONY: rebuild


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
