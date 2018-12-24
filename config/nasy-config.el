;;; config.el --- User config file.                    -*- lexical-binding: t; -*-

;; Author: Nasy <nasyxx+emacs@gmail.com>

;;; Commentary:

;; Nasy's Custom Config file.

;;; Code:

(defconst *is-a-mac*  (eq system-type 'darwin))

(defconst *clangd*    (or (executable-find "clangd")  ;; usually
                          (executable-find "/usr/local/opt/llvm/bin/clangd")))  ;; macOS

(defconst *nix*       (executable-find "nix"))

(defconst *rust*      (or (executable-find "rustc")
                          (executable-find "cargo")
                          (executable-find "rustup")))
(defconst *rls*       (or (executable-find "rls")
                          (executable-find "~/.cargo/bin/rls")))

(defvar   *intero*    t)

(defconst *struct-hs* (executable-find "structured-haskell-mode"))
(defvar   *struct-hs-path* nil)

(defvar   *blacken*   nil)

(defvar   *vterm*     nil)

;; Theme
(defvar nasy:theme 'doom-dracula)

(when *is-a-mac*
  (add-to-list 'default-frame-alist
               '(ns-transparent-titlebar . t))

  (add-to-list 'default-frame-alist
               '(ns-appearance . dark))

  (add-to-list 'default-frame-alist
               '(alpha . (80 . 75)))

  (add-to-list 'default-frame-alist
               '(font . "OperatorMonoLig Nerd Font-14"))

  (defun stop-minimizing-window ()
  "Stop minimizing window under macOS."
  (interactive)
  (unless (and *is-a-mac*
               window-system)
    (suspend-frame)))

  (global-set-key (kbd "C-z") 'stop-minimizing-window))

(setq-default
  blink-cursor-interval .6
  blink-matching-paren  t)

(setq-default
 fill-column                    80
 visual-fill-column-width       100
 word-wrap                      t
 highlight-indent-guides-method 'column
 tab-width                      8
 tooltip-delay                  1.5)

(setq-default
 company-idle-delay .5)

(setq-default
 ;; brew install rg   if you'd like to use rg as my doing
 helm-ag-base-command "rg --no-heading --smart-case")

(setq-default
 shell-file-name "/bin/zsh")

(setq-default
 haskell-stylish-on-save nil
 blacken-line-length     80
 lsp-rust-rls-command    '("rls"))

(setq-default
 show-paren-style                                'expression
 sp-autoinsert-quote-if-followed-by-closing-pair t
 sp-base-key-bindings                            'paredit
 sp-show-pair-from-inside                        t)

(setq-default
 whitespace-line-column 80
 whitespace-style       '(face spaces tabs newline
                          space-mark tab-mark newline-mark
                          lines-tail empty))

;; The original one is `(find-at-startup find-when-checking) which is so slow.
;; straight-check-for-modifications '(find-at-startup find-when-checking)
(setq-default
 straight-check-for-modifications '(check-on-save find-when-checking))

(setq-default
 initial-scratch-message     (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
 dashboard-banner-logo-title (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
 ;; initial-buffer-choice       #'(lambda () (get-buffer "*dashboard*"))  ;; It will cause error if you start emacs from Command line with file name
                                                                          ;; https://github.com/rakanalh/emacs-dashboard/issues/69
)

(defun nasy:config-after ()
  "Set configuration need to be set after init."
  (setq-default
   helm-allow-mouse                  t
   helm-follow-mode-persistent       t
   helm-move-to-line-cycle-in-source nil
   helm-source-names-using-follow    '("Buffers" "kill-buffer" "Occur")))


(add-hook 'nasy:config-after-hook  #'nasy:config-after)

(defun nasy:set-face ()
  "Set custom face."
  (set-face-attribute 'custom-comment              nil                                             :slant   'italic)
  (set-face-attribute 'font-lock-keyword-face      nil                                             :slant   'italic)
  (set-face-attribute 'show-paren-match            nil :background "#bfcfff" :foreground "#dc322f" :weight  'ultra-bold)
  (set-face-attribute 'show-paren-match-expression nil :background "#543e5c"                       :inherit 'unspecified)
  (set-face-attribute 'which-func                  nil                       :foreground "#333"))

(add-hook 'nasy:config-before-hook #'nasy:set-face)

(when *is-a-mac*
  ;; cursor Movement
  (global-set-key (kbd "s-<up>")   'beginning-of-buffer)
  (global-set-key (kbd "s-<down>") 'end-of-buffer)
  ;; text Operations
  (global-set-key (kbd "M-¥")
                  (lambda ()
                    (interactive)
                    (insert "\\")))
  (global-set-key (kbd "s-<backspace>")
                  (lambda ()
                    (interactive)
                    (kill-line 0)))
)

(provide 'nasy-config)
;;; nasy-config.el ends here
