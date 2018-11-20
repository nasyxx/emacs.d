all:
	@echo "Do nothing."
.PHONY: all

clean: clean-cache clean-history clean-python
	rm -rf straight/repoes/straight.el
	@echo "Cleaning done!"
.PHONY: clean


clean-cache:
	rm -rf straight/build-cache.el
	rm -rf .smex-items
	rm -rf auto-save-list
	rm -rf .cache
.PHONY: clean-cache


clean-history:
	rm -rf .historian
	rm -rf history
	rm -rf recentf
	rm -rf .session
	rm -rf .emacs.desktop
	rm -rf .bookmarks.el
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


clean-all: clean clean-jar
	rm -rf straight
.PHONY: clean-all

update: clean clean-build
	git pull
.PHONY: update
