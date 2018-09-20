;;; config.el --- User config file.                    -*- lexical-binding: t; -*-

;; Author: Nasy <nasyxx@gmail.com>

;;; Commentary:

;; User config file.

;;; Code:

(defconst *is-a-mac* (eq system-type 'darwin))

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

 ;;---cursor-----------------------------------------------------------------
 blink-cursor-interval                           .6
 blink-matching-paren                            t
 ;; cursor-type 'bar

 ;;---visual-----------------------------------------------------------------
 fill-column                                     80
 visual-fill-column-width                        100
 word-wrap                                       t
 highlight-indent-guides-method                  'column
 tab-width                                       8
 tooltip-delay                                   1.5

 ;;---company----------------------------------------------------------------
 company-idle-delay                              .5

 ;;---helm-------------------------------------------------------------------
 ;; brew install rg   if you'd like to use rg as my doing
 helm-ag-base-command                            "rg --no-heading --smart-case"

 ;;---shell------------------------------------------------------------------
 shell-file-name                                 "/bin/zsh"

 ;;---language---------------------------------------------------------------
 haskell-stylish-on-save                         nil
 blacken-line-length                             80
 *clangd*                                        (or (executable-find "clangd")  ;; usually
                                                     (executable-find "/usr/local/opt/llvm/bin/clangd"))  ;; macOS

 ;;---parens-----------------------------------------------------------------
 show-paren-style                                'expression
 sp-autoinsert-quote-if-followed-by-closing-pair t
 sp-base-key-bindings                            'paredit
 sp-show-pair-from-inside                        t

 ;;---whitespace-------------------------------------------------------------
 whitespace-line-column                          80
 whitespace-style                                '(face spaces tabs newline
                                                   space-mark tab-mark newline-mark
                                                   lines-tail empty)

 ;;---straight---------------------------------------------------------------
 ;; The original one is `(find-at-startup find-when-checking) which is so slow.
 ;; straight-check-for-modifications                '(find-at-startup find-when-checking)
 straight-check-for-modifications                '(check-on-save find-when-checking)

 ;;---others-----------------------------------------------------------------
 use-pyenv                                       t  ;; `t' if you'd like to use pyenv when using pyls
 use-blacken                                     nil  ;; `t' if you'd like to use black when using pyls
)


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

;; Custom face
;;----------------------------------------------------------------------------

(defun nasy:set-face ()
  "Set custom face."
  (set-face-attribute 'custom-comment              nil :background "#3d4551" :foreground "#cbe3e7" :slant   'italic)
  (set-face-attribute 'font-lock-keyword-face      nil                       :foreground "#aa96da" :slant   'italic)
  (set-face-attribute 'mode-line                   nil :background "#a1de93" :foreground "#2f3e75" :box     nil)
  (set-face-attribute 'mode-line-inactive          nil :background "#333"    :foreground "#96A7A9" :box     nil)
  (set-face-attribute 'powerline-active0           nil :background "#ffffc1"                       :inherit 'mode-line )
  (set-face-attribute 'powerline-active1           nil :background "#aa96da" :foreground "#2f3e75" :inherit 'mode-line )
  (set-face-attribute 'powerline-active2           nil :background "#d0efb5" :foreground "black"   :inherit 'mode-line)
  (set-face-attribute 'show-paren-match            nil :background "#bfcfff" :foreground "#dc322f" :weight  'ultra-bold)
  (set-face-attribute 'show-paren-match-expression nil :background "#2f3e75"                       :inherit 'unspecified)
  (set-face-attribute 'which-func                  nil                       :foreground "#333"))

(add-hook 'nasy:config-before-hook #'nasy:set-face)


;; Key Bindings
;;----------------------------------------------------------------------------

(when *is-a-mac*
  ;; cursor Movement
  (global-set-key (kbd "s-<up>")   'beginning-of-buffer)
  (global-set-key (kbd "s-<down>") 'end-of-buffer)
  ;; text Operations
  (global-set-key (kbd "M-¥") (lambda ()
                                (interactive)
                                (insert "\\")))
  (global-set-key (kbd "s-<backspace>") (lambda ()
                                         (interactive)
                                         (kill-line 0)))
)

(provide 'nasy-config)
;;; nasy-config.el ends here
