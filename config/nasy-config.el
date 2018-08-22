;;; config.el --- User config file.                    -*- lexical-binding: t; -*-

;; Author: Nasy <nasyxx@gmail.com>

;;; Commentary:

;; User config file.

;;; Code:


;; Ui settings
;;----------------------------------------------------------------------------

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

(setq-default nasy:theme 'doom-dracula)


;; Some default settings
;;----------------------------------------------------------------------------

(setq-default
 ;; calendar-latitude  24.8801
 ;; calendar-longitude 102.8329
 ;; user-mail-address ""
 blink-cursor-interval             .6
 blink-matching-paren              t
 company-idle-delay                .5
 ;; cursor-type 'bar
 fill-column                       80
 helm-ag-base-command              "rg --no-heading --smart-case"  ;; brew install rg
 highlight-indent-guides-method    'column
 shell-file-name                   "/bin/zsh"
 show-paren-style                  'expression
 sp-base-key-bindings              'paredit
 tab-width                         8
 tooltip-delay                     1.5
 use-pyenv                         t  ;; `t' if you'd like to use pyenv when using pyls
 visual-fill-column-width          100
 whitespace-line-column            80
 whitespace-style                  '(face spaces tabs newline
                                     space-mark tab-mark newline-mark
                                     lines-tail empty)
 word-wrap                         t
)


(setq-default
 initial-scratch-message     (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
 dashboard-banner-logo-title (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
 initial-buffer-choice #'(lambda () (get-buffer "*dashboard*"))
)


(defun nasy:config-after ()
  "Set default after init."
  (setq-default
   helm-allow-mouse                  t
   helm-follow-mode-persistent       t
   helm-move-to-line-cycle-in-source nil
   helm-source-names-using-follow    '("Buffers" "kill-buffer" "Occur")))


(add-hook 'nasy:config-after-hook  #'nasy:config-after)

;; Custom face
;;----------------------------------------------------------------------------

(defun nasy:set-face ()
  "Set custom face."
  (set-face-attribute 'custom-comment              nil :background "#3d4551" :foreground "#cbe3e7" :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face      nil :foreground "#aa96da"                       :slant 'italic)
  (set-face-attribute 'mode-line                   nil :background "#a1de93" :foreground "#2f3e75" :box nil )
  (set-face-attribute 'mode-line-inactive          nil :background "#333"    :foreground "#96A7A9" :box nil)
  (set-face-attribute 'powerline-active0           nil :background "#ffffc1"                       :inherit 'mode-line )
  (set-face-attribute 'powerline-active1           nil :background "#aa96da" :foreground "#2f3e75" :inherit 'mode-line )
  (set-face-attribute 'powerline-active2           nil :background "#d0efb5" :foreground "black"   :inherit 'mode-line)
  (set-face-attribute 'show-paren-match            nil :background "#bfcfff" :foreground "#dc322f" :weight  'ultra-bold)
  (set-face-attribute 'show-paren-match-expression nil :background "#2f3e75"                       :inherit 'unspecified)
  (set-face-attribute 'which-func                  nil                       :foreground "#333"))

(add-hook 'nasy:config-before-hook #'nasy:set-face)


;; Key Bindings
;;----------------------------------------------------------------------------

(when *is-a-mac*  ;; init.el:16 (defconst *is-a-mac* (eq system-type 'darwin))
  ;; Cursor Movement
  (global-set-key (kbd "s-<up>")   'beginning-of-buffer)
  (global-set-key (kbd "s-<down>") 'end-of-buffer)
  ;; Text Operations
  (global-set-key (kbd "M-¥") (lambda ()
                                (interactive)
                                (insert "\\")))
  (global-set-key (kbd "s-<backspace>") (lambda ()
                                         (interactive)
                                         (kill-line 0)))
)

(provide 'nasy-config)
;;; nasy-config.el ends here
