EM ?= emacs
EE ?= $(EM) -Q --batch --eval "(require 'ob-tangle)"
ETS ?= $(EM) -Q --batch --directory . --load tree-sitter-langs-build
# EL ?= $(EM) -Q --batch -l "init.el" --eval "(setq load-prefer-newer t load-suffixes '(\".el\") nasy--require t)" --eval "(progn (run-hooks 'after-init-hook 'emacs-startup-hook 'nasy-first-key-hook 'pre-command-hook 'prog-mode-hook 'org-mode-hook 'nasy-org-first-key-hook))"

EL ?= $(EM) -Q

DS = 小曐 庭燎 擊鼓 日月 月出 緑衣 風雨 麐之趾

LANGS = agda cpp html jsdoc pgn rust bash css fluent janet-simple json php \
	scala c elisp go java julia python swift c-sharp hcl javascript ocaml ruby typescript # elm elixir

TSLD = 木瓜/emacs-tree-sitter/tree-sitter-langs

ifeq ($(shell uname -s), Darwin)
suf = dylib
else
suf = so
endif


all: help


define tangle_template
ifeq ($(1),擊鼓)
$(1): 桃夭/擊鼓/擊鼓.el
else
$(1): $(subst 篇,$(1),$(patsubst 蔓艸/%.org,桃夭/%.el,$(wildcard 蔓艸/$(1)/*.org)))
endif

clean-$(1):
	rm -rf 桃夭/$(1)
.PHONY: clean-$(1)

桃夭/$(1)/$(1).el: 蔓艸/$(1)/篇.org
	$(EE) --eval '(org-babel-tangle-publish t "$$<" "$$(@D)")'


桃夭/$(1)/%.el: 蔓艸/$(1)/%.org
	$(EE) --eval '(org-babel-tangle-publish t "$$<" "$$(@D)")'
endef


譯.el: 蔓艸/擊鼓/譯.org
	$(EE) --eval '(org-babel-tangle-publish t "$<" "$(@D)/")'


early-init.el: 蔓艸/擊鼓/初.org
	$(EE) --eval '(org-babel-tangle-publish t "$<" "$(@D)/")'

init.el: 蔓艸/篇.org early-init.el
	$(EE) --eval '(org-babel-tangle-publish t "$<" "$(@D)/")'
启.el: init.el


芄蘭/芄蘭之例.el: 蔓艸/擊鼓/芄蘭之例.org
	$(EE) --eval '(org-babel-tangle-publish t "$<" "$(@D)")'


芄蘭/芄蘭.el:
	mkdir -p 芄蘭
	[ -f 芄蘭/芄蘭.el ] || \
	echo "(require '芄蘭之例 nil t)\\n\\n(provide '芄蘭)" > 芄蘭/芄蘭.el


$(foreach dir,$(DS),$(eval $(call tangle_template,$(dir))))


straight/build/tsc/tsc-dyn.dylib: 月出
	cd straight/build/tsc && cargo build --release && cp target/release/libtsc_dyn.dylib tsc-dyn.dylib


木瓜/emacs-tree-sitter/tree-sitter-langs/bin/%: 芄蘭/langs
	cd $(dir $(@D)) && \
	$(ETS) --eval "(tree-sitter-langs-compile '$*)"
	touch $@

芄蘭/langs:
	@date > 芄蘭/langs


langs: $(patsubst %,木瓜/emacs-tree-sitter/tree-sitter-langs/bin/%,$(LANGS))


## Generate emacs-lisp files
generate: $(DS) early-init.el init.el 启.el 譯.el 芄蘭/芄蘭.el 芄蘭/芄蘭之例.el


芄蘭/build-time: $(wildcard 桃夭/*/*.el)
	$(EL) --batch --eval '(setq nasy-first-p t)' -l 譯.el
	$(EL) --script 譯.el
	@date > 芄蘭/build-time



## Build elc
build: 芄蘭/build-time


## Generate Config
config: generate
	make build


## Clean Config
clean:
	rm -rf 桃夭 芄蘭/芄蘭之例.el 启.el init.el early-init.el 芄蘭/build-time


## Clean tree-sitter
clean-tsc:
	rm -rf 木瓜/emacs-tree-sitter/tree-sitter-langs/bin/*
	rm -rf 芄蘭/langs
	rm -rf .git/modules/tree-sitter-rangs/modules/repos/elisp

	cd $(TSLD) && rm -rf repos/elisp queries/elisp && git reset --hard && \
		git submodule add --force -b main -- https://github.com/Wilfred/tree-sitter-elisp.git repos/elisp
	cd $(TSLD) && mkdir -p queries/elisp && cp repos/elisp/queries/*.scm queries/elisp

## Clean Elc
clean-elc:
	rm -rf 桃夭/*/*.elc


## Clean straight
clean-straight:
	rm -rf straight


## Clean all (clean and clean straight)
clean-all: clean clean-straight clean-tsc


## Re-Generate Config
regenerate: clean
	make generate


## Re-Build Config
rebuild: clean
	-make langs -j
	-make langs -j
	make config -j


## Re-Build Config and Straight
rebuild-all: clean-all
	make rebuild



## Update
update: clean
	git pull --rebase
	make generate -j

## Update all
update-all: update clean-straight
	make config -j


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


.PHONY: help all $(DS) generate build config clean clean-elc rebuild
