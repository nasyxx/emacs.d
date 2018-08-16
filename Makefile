all:
	@echo "Do nothing."
.PHONY: all

clean:
	@echo "cleaning."
	rm -rf .cache .emacs.desktop .historian .session .smex-items anaconda-mode auto-save-list ditaa0_9.jar history plantuml.jar projectile-bookmarks.eld recentf

clean-all: clean
	rm -rf straight

.PHONY: clean clean-all
