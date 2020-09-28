EMACS ?= emacs

all: help
.PHONY: all


## Generate init.el from literate-config/README.org
init.el: literate-config/README.org
	@echo "Generate init.el from literate-config/README.org"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "init")'


## Generate config/nasy-bootstrap.el from literate-config/bootstrap
config/nasy-bootstrap.el: $(wildcard literate-config/bootstrap/*.org)
	@echo "Generate config/nasy-bootstrap.el from literate-config/bootstrap/README.org"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "bootstrap")'


## Generate config/core from literate-config/core
config/core/nasy-core.el: $(wildcard literate-config/core/*.org)
	@echo "Generate config/core from literate-config/core"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "core")'


## Generate config/editor from literate-config/editor
config/editor/nasy-editor.el: $(wildcard literate-config/editor/*.org)
	@echo "Generate config/editor from literate-config/editor"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "editor")'


## Generate config/tools from literate-config/tools
config/tools/nasy-tools.el: $(wildcard literate-config/tools/*.org)
	@echo "Generate config/tools from literate-config/tools"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "tools")'


## Generate config/langs from literate-config/langs
config/langs/nasy-langs.el: $(wildcard literate-config/langs/*.org)
	@echo "Generate config/langs from literate-config/langs"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "langs")'


## Generate config/ui from literate-config/org
config/org/nasy-org.el: $(wildcard literate-config/org/*.org)
	@echo "Generate config/org from literate-config/org"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "org")'


## Generate config/ui from literate-config/ui
config/ui/nasy-ui.el: $(wildcard literate-config/ui/*.org)
	@echo "Generate config/ui from literate-config/ui"
	@$(EMACS) -Q --batch -l export.el --eval '(org-publish "ui")'


## Generate all
generate: init.el config/nasy-bootstrap.el config/core/nasy-core.el config/editor/nasy-editor.el config/tools/nasy-tools.el config/langs/nasy-langs.el config/ui/nasy-ui.el config/org/nasy-org.el
.PHONY: generate


## Old Generate init.el from README.org
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

## Clean build (straight/)
clean-build:
	rm -rf straight
.PHONY: clean-build

## Clean etc (etc/)
clean-etc:
	rm -rf etc
.PHONY: clean-etc

## Clean var (var/)
clean-var:
	rm -rf var
.PHONY: clean-var

## clean all build etc python var
clean-all: clean-build clean-etc clean-python clean-var
.PHONY: clean-all

## Update config
update: clean-build
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
