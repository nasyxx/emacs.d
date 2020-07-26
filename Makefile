EMACS ?= emacs

all: help
.PHONY: all

## Generate init.el from README.org
generate:
	@echo "Generate init.el from README.org and literate-config.org."
	@mkdir -p custom && \
		$(EMACS) -Q --batch --find-file "README.org" -f "org-babel-tangle"
	@$(EMACS) -Q --batch --find-file "literate-config.org" -f "org-org-export-to-org" && \
		$(EMACS) -Q --batch --find-file "literate-config.org.org" -f "org-babel-tangle" && \
		rm -rf "literate-config.org.org" "literate-config.org.org~"
	@$(EMACS) -Q --batch --find-file "extra/README.org" -f "org-babel-tangle"
	@echo "If you want to customize, you can simply change/create custom/user-config.el"
.PHONY: generate

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
