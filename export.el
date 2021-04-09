;;; export.el --- Nasy's Emacs configuration export script.  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Nasy

;; Author: Nasy <nasyxx@gmail.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Nasy's Emacs configuration export script.

;;; Code:

(require 'ox-publish)

(defvar nasy/publish-base)

(setq org-publish-timestamp-directory
      (expand-file-name "var/org/timestamps/" user-emacs-directory)
      nasy/publish-base "~/.emacs.d/config")

(setq org-publish-project-alist
      `(("early-init"
         :base-directory "~/.emacs.d/literate-config/"
         :base-extension "org"
         :recursive nil
         :exclude ".*"
         :include ("early-init.org")
         :publishing-directory ,(expand-file-name "../" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("custom"
         :base-directory "~/.emacs.d/"
         :base-extension "org"
         :recursive nil
         :exclude ".*"
         :include ("README.org")
         :publishing-directory ,(expand-file-name "../custom" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("init"
         :base-directory "~/.emacs.d/literate-config/"
         :base-extension "org"
         :recursive nil
         :exclude ".*"
         :include ("README.org")
         :publishing-directory ,(expand-file-name "../" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("bootstrap"
         :base-directory "~/.emacs.d/literate-config/bootstrap/"
         :base-extension "org"
         :recursive nil
         :exclude ".*"
         :include ("README.org")
         :publishing-directory ,(expand-file-name nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("core"
         :base-directory "~/.emacs.d/literate-config/core/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :exclude "keydef"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "core" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("editor"
         :base-directory "~/.emacs.d/literate-config/editor/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "editor" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("tools"
         :base-directory "~/.emacs.d/literate-config/tools/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "tools" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("langs"
         :base-directory "~/.emacs.d/literate-config/langs/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "langs" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("org"
         :base-directory "~/.emacs.d/literate-config/org/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "org" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("ui"
         :base-directory "~/.emacs.d/literate-config/ui/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "ui" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("app"
         :base-directory "~/.emacs.d/literate-config/app/"
         :base-extension "org"
         :recursive nil
         ;; :exclude "README.org"
         ;; :include ("README.org")
         :publishing-directory ,(expand-file-name "app" nasy/publish-base)
         :publishing-function org-babel-tangle-publish)
        ("all"
         :components ("early-init"
                      "custom"
                      "init"
                      "bootstrap"
                      "core"
                      "editor"
                      "tools"
                      "langs"
                      "org"
                      "ui"
                      "app"))))

(provide 'export)
;;; export.el ends here
