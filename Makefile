all:
	@echo "Do nothing."
.PHONY: all

clean: clean-cache clean-history clean-jar clean-python
	@echo "Cleaning done!"
.PHONY: clean


clean-cache:
	rm -rf straight/build-cache.el
	rm -rf .smex-items
.PHONY: clean-cache


clean-history:
	rm -rf .historian
	rm -rf history
	rm -rf recentf
	rm -rf .session
	rm -rf .emacs.desktop
.PHONY: clean-history


clean-jar:
	rm -rf *.jar
.PHONY: clean-jar


clean-python:
	rm -rf anaconda-mode
.PHONY: clean-python


clean-build: clean-cache
	rm -rf striaght/build
.PHONY: clean-build


clean-all: clean
	rm -rf straight
.PHONY: clean-all
