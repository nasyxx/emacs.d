;;; init.el --- Nasy's emacs.d init file.            -*- lexical-binding: t; -*-
;; Copyright (C) 2018  Nasy

;; Author: Nasy <echo bmFzeXh4QGdtYWlsLmNvbQo= | base64 -d (or -D on macOS)>

;;; Commentary:

;; Nasy's emacs.d init file.  For macOS and Emacs 26.

;;; Code:
(setq debug-on-error t)
(setq message-log-max t)
(setq-default lexical-binding t)

(defconst *is-a-mac* (eq system-type 'darwin))

;; For straight
;;----------------------------------------------------------------------------
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (Bootstrap-version 4))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Adjust garbage collection thresholds during startup, and thereafter
;;----------------------------------------------------------------------------

(let ((normal-gc-cons-threshold (* 20 1024 1024))
      (init-gc-cons-threshold (* 128 1024 1024)))
  (setq gc-cons-threshold init-gc-cons-threshold)
  (add-hook 'after-init-hook
            (lambda ()
              (setq gc-cons-threshold normal-gc-cons-threshold))))

;; For use-package
;;----------------------------------------------------------------------------

(straight-use-package 'use-package)

;; Benchmark
;;----------------------------------------------------------------------------

(use-package benchmark-init
  :demand t
  :straight t
  :hook ((after-init . benchmark-init/deactivate)))

;; Reload the init-file
;;----------------------------------------------------------------------------

(defun radian-reload-init ()
  "Reload init.el."
  (interactive)
  (straight-transaction
    (straight-mark-transaction-as-init)
    (message "Reloading init.el...")
    (load user-init-file nil 'nomessage)
    (message "Reloading init.el... done.")))


(defun radian-eval-buffer ()
  "Evaluate the current buffer as Elisp code."
  (interactive)
  (message "Evaluating %s..." (buffer-name))
  (straight-transaction
    (if (null buffer-file-name)
        (eval-buffer)
      (when (string= buffer-file-name user-init-file)
        (straight-mark-transaction-as-init))
      (load-file buffer-file-name)))
  (message "Evaluating %s... done." (buffer-name)))

(unwind-protect
    (let ((straight-treat-as-init t))
      "load your init-file here")
  (straight-finalize-transaction))

;; Expand load-path
;;----------------------------------------------------------------------------

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;; Compile
;;----------------------------------------------------------------------------

(use-package auto-compile
  :demand t
  :straight t
  :init (setq load-prefer-newer t)
  :config
  (auto-compile-on-load-mode)
  (auto-compile-on-save-mode))

(setq-default compilation-scroll-output t)

(use-package alert
  :straight t
  :init
  (defun alert-after-compilation-finish (buf result)
    "Use `alert' to report compilation RESULT if BUF is hidden."
    (when (buffer-live-p buf)
      (unless (catch 'is-visible
                (walk-windows (lambda (w)
                                (when (eq (window-buffer w) buf)
                                  (throw 'is-visible t))))
                nil)
        (alert (concat "Compilation " result)
               :buffer buf
               :category 'compilation)))))


(use-package compile
  :demand t
  :preface
  (defvar last-compilation-buffer nil
    "The last buffer in which compilation took place.")
  (defadvice compilation-start (after save-compilation-buffer activate)
    "Save the compilation buffer to find it later."
    (setq last-compilation-buffer next-error-last-buffer))

  (defadvice recompile (around find-prev-compilation (&optional edit-command) activate)
    "Find the previous compilation buffer, if present, and recompile there."
    (if (and (null edit-command)
             (not (derived-mode-p 'compilation-mode))
             last-compilation-buffer
             (buffer-live-p (get-buffer last-compilation-buffer)))
        (with-current-buffer last-compilation-buffer
          ad-do-it)
      ad-do-it))
  :bind (([f6] . recompile))
  :hook ((compilation-finish-functions . alert-after-compilation-finish)))


(use-package ansi-color
  :demand t
  :after compile
  :straight t
  :hook ((compilation-filter . colourise-compilation-buffer))
  :config
  (defun colourise-compilation-buffer ()
    (when (eq major-mode 'compilation-mode)
      (ansi-color-apply-on-region compilation-filter-start (point-max)))))

(use-package cmd-to-echo
  :defer t
  :straight t)

;; Shell
;;----------------------------------------------------------------------------


(defadvice shell-command-on-region
    (after shell-command-in-view-mode
           (start end command &optional output-buffer replace &rest other-args)
           activate)
  "Put \"*Shell Command Output*\" buffers into view-mode."
  (unless (or output-buffer replace)
    (with-current-buffer "*Shell Command Output*"
      (view-mode 1))))


(use-package exec-path-from-shell
  :demand *is-a-mac*
  :straight t
  :init (setq shell-file-name "/bin/zsh")
  :config (progn
            (when nil (message "PATH: %s, INFO: %s" (getenv "PATH")
                               (getenv "ENVIRONMENT_SETUP_DONE"))
                  (setq exec-path-from-shell-debug t))
            (setq exec-path-from-shell-arguments (list "-l"))
            (setq exec-path-from-shell-check-startup-files nil)
            (add-to-list 'exec-path-from-shell-variables "SHELL")
            (add-to-list 'exec-path-from-shell-variables "GOPATH")
            (add-to-list 'exec-path-from-shell-variables "ENVIRONMENT_SETUP_DONE")
            (add-to-list 'exec-path-from-shell-variables "PYTHONPATH")
            (exec-path-from-shell-initialize)))


;; Non-Forking Shell Command To String
;; https://github.com/bbatsov/projectile/issues/1044
;;----------------------------------------------------------------------------

(defun call-process-to-string (program &rest args)
  (with-temp-buffer
    (apply 'call-process program nil (current-buffer) nil args)
    (buffer-string)))

(defun get-call-process-args-from-shell-command (command)
  (cl-destructuring-bind
      (the-command . args) (split-string command " ")
    (let ((binary-path (executable-find the-command)))
      (when binary-path
        (cons binary-path args)))))

(defun shell-command-to-string (command)
  (let ((call-process-args
         (imalison:get-call-process-args-from-shell-command command)))
    (if call-process-args
        (apply 'call-process-to-string call-process-args)
      (shell-command-to-string command))))

(defun try-call-process (command)
  (let ((call-process-args
         (get-call-process-args-from-shell-command command)))
    (if call-process-args
        (apply 'call-process-to-string call-process-args))))

(advice-add 'shell-command-to-string :before-until 'try-call-process)

(defun call-with-quick-shell-command (fn &rest args)
  (noflet ((shell-command-to-string (&rest args)
                                    (or (apply 'try-call-process args) (apply this-fn args))))
    (apply fn args)))

(advice-add 'projectile-find-file :around 'call-with-quick-shell-command)



;; UI
;;----------------------------------------------------------------------------

;; Frame initializes and GUI disables

(when *is-a-mac*
  (add-to-list 'default-frame-alist
               '(ns-transparent-titlebar . t))

  (add-to-list 'default-frame-alist
               '(ns-appearance . dark))

  (add-to-list 'default-frame-alist
               '(alpha . (80 . 75)))
  (global-set-key (kbd "M-¥") (lambda () (interactive) (insert "\\"))))

(defun stop-minimizing-window ()
  "Stop minimizing window under macOS."
  (interactive)
  (unless (and *is-a-mac*
               window-system)
    (suspend-frame)))

(global-set-key (kbd "C-z") 'stop-minimizing-window)

;; Disable some features

(setq use-file-dialog nil
      use-dialog-box nil
      inhibit-startup-screen t)

(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))

(when (fboundp 'set-scroll-bar-mode)
  (set-scroll-bar-mode nil))


;; scratch message

(use-package scratch
  :demand t
  :straight t
  :init (setq-default initial-scratch-message
                      (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")))

;; nice scrolling

(setq scroll-margin 0
      scroll-conservatively 100000
      scroll-preserve-screen-position 'always)


;; sunrise-sunset

(setq calendar-latitude 24.8801
      calendar-longitude 102.8329)


;; Require packages
;;----------------------------------------------------------------------------

(use-package command-log-mode
  :demand t
  :straight t)


;; Windows
;;----------------------------------------------------------------------------

(add-hook 'after-init-hook 'winner-mode)

(use-package switch-window
  :straight t
  :init (setq-default switch-window-shortcut-style 'alphabet
                      switch-window-timeout nil)
  :bind (("C-x o" . switch-window)))

;; When splitting window, show (other-buffer) in the new window
(defun split-window-func-with-other-buffer (split-function)
  (lambda (&optional arg)
    "Split this window and switch to the new window unless ARG is provided."
    (interactive "P")
    (funcall split-function)
    (let ((target-window (next-window)))
      (set-window-buffer target-window (other-buffer))
      (unless arg
        (select-window target-window)))))

(global-set-key (kbd "C-x 2")
                (split-window-func-with-other-buffer 'split-window-vertically))
(global-set-key (kbd "C-x 3")
                (split-window-func-with-other-buffer 'split-window-horizontally))


(defun toggle-delete-other-windows ()
  "Delete other windows in frame if any, or restore previous window config."
  (interactive)
  (if (and winner-mode
           (equal (selected-window) (next-window)))
      (winner-undo)
    (delete-other-windows)))

(global-set-key (kbd "C-x 1") 'toggle-delete-other-windows)


;; Functions
;;----------------------------------------------------------------------------

(defun insert-current-date ()
  "Insert current date."
  (interactive)
  (insert (shell-command-to-string "echo -n $(date +'%b %d, %Y')")))

(defun insert-current-filename ()
  "Insert current buffer filename."
  (interactive)
  (insert (file-relative-name buffer-file-name)))

;; Rearrange split windows

(defun split-window-horizontally-instead ()
  "Kill any other windows and re-split such that the current window is on the
top half of the frame."
  (interactive)
  (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
    (delete-other-windows)
    (split-window-horizontally)
    (when other-buffer
      (set-window-buffer (next-window) other-buffer))))

(defun split-window-vertically-instead ()
  "Kill any other windows and re-split such that the current window is on the
left half of the frame."
  (interactive)
  (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
    (delete-other-windows)
    (split-window-vertically)
    (when other-buffer
      (set-window-buffer (next-window) other-buffer))))

(global-set-key (kbd "C-x |") 'split-window-horizontally-instead)
(global-set-key (kbd "C-x _") 'split-window-vertically-instead)


;; Borrowed from http://postmomentum.ch/blog/201304/blog-on-emacs
(defun nasy/split-window()
  "Split the window to see the most recent buffer in the other window.
Call a second time to restore the original window configuration."
  (interactive)
  (if (eq last-command 'nasy/split-window)
      (progn
        (jump-to-register :nasy:split-window)
        (setq this-command 'nasy/unsplit-window))
    (window-configuration-to-register :nasy/split-window)
    (switch-to-buffer-other-window nil)))

(global-set-key (kbd "<f7>") 'nasy/split-window)


(defun toggle-current-window-dedication ()
  "Toggle whether the current window is dedicated to its current buffer."
  (interactive)
  (let* ((window (selected-window))
         (was-dedicated (window-dedicated-p window)))
    (set-window-dedicated-p window (not was-dedicated))
    (message "Window %sdedicated to %s"
             (if was-dedicated "no longer " "")
             (buffer-name))))

(global-set-key (kbd "C-c <down>") 'toggle-current-window-dedication)



;; Session
;;----------------------------------------------------------------------------
;; desktop save

(setq desktop-path (list user-emacs-directory)
      desktop-auto-save-timeout 600)
(desktop-save-mode 1)


(defadvice desktop-read (around time-restore activate)
    (let ((start-time (current-time)))
      (prog1
          ad-do-it
        (message "Desktop restored in %.2fms"
                 (benchmark-init/time-subtract-millis (current-time)
                                                 start-time)))))


(defadvice desktop-create-buffer (around time-create activate)
  (let ((start-time (current-time))
        (filename (ad-get-arg 1)))
    (prog1
        ad-do-it
      (message "Desktop: %.2fms to restore %s"
               (benchmark-init/time-subtract-millis (current-time)
                                               start-time)
               (when filename
                 (abbreviate-file-name filename))))))


(setq-default history-length 1000)
(add-hook 'after-init-hook 'savehist-mode)


(use-package session
  :defer t
  :straight t
  :hook ((after-init . session-initialize))
  :init
  (setq session-save-file (expand-file-name ".session" user-emacs-directory)
        session-name-disable-regexp "\\(?:\\`'/tmp\\|\\.git/[A-Z_]+\\'\\)"
        session-save-file-coding-system 'utf-8
        desktop-globals-to-save
        (append '((comint-input-ring        . 50)
                  (compile-history          . 30)
                  desktop-missing-file-warning
                  (dired-regexp-history     . 20)
                  (extended-command-history . 30)
                  (face-name-history        . 20)
                  (file-name-history        . 100)
                  (grep-find-history        . 30)
                  (grep-history             . 30)
                  (ido-buffer-history       . 100)
                  (ido-last-directory-list  . 100)
                  (ido-work-directory-list  . 100)
                  (ido-work-file-list       . 100)
                  (ivy-history              . 100)
                  (magit-read-rev-history   . 50)
                  (minibuffer-history       . 50)
                  (org-clock-history        . 50)
                  (org-refile-history       . 50)
                  (org-tags-history         . 50)
                  (query-replace-history    . 60)
                  (read-expression-history  . 60)
                  (regexp-history           . 60)
                  (regexp-search-ring       . 20)
                  register-alist
                  (search-ring              . 20)
                  (shell-command-history    . 50)
                  tags-file-name
                  tags-table-list))))

;; Editor
;;----------------------------------------------------------------------------

;; some default settings

(setq-default
 blink-cursor-interval 1
 bookmark-default-file (expand-file-name ".bookmarks.el" user-emacs-directory)
 buffers-menu-max-size 30
 case-fold-search t
 column-number-mode t
 dired-dwim-target t
 ediff-split-window-function 'split-window-horizontally
 ediff-window-setup-function 'ediff-setup-windows-plain
 indent-tabs-mode nil
 line-move-visual t
 make-backup-files nil
 mouse-yank-at-point t
 require-final-newline t
 save-interprogram-paste-before-kill t
 set-mark-command-repeat-pop t
 tab-always-indent 'complete
 tab-width 8
 tooltip-delay 1.5
 truncate-lines nil
 truncate-partial-width-windows nil)


(delete-selection-mode t)

(fset 'yes-or-no-p 'y-or-n-p)

(global-auto-revert-mode t)



(use-package diminish
  :demand t
  :straight t)


(use-package disable-mouse
  :straight t
  :bind (([mouse-4] . (lambda ()
                        (interactive)
                        (scroll-down 1)))
         ([mouse-5] . (lambda ()
                        (interactive)
                        (scroll-up 1)))))


(use-package list-unicode-display
  :defer t
  :straight t)


(use-package which-key
  :demand t
  :straight t
  :config (which-key-mode +1))


;; isearch

(use-package isearch
  :preface
  ;; Search back/forth for the symbol at point
  ;; See http://www.emacswiki.org/emacs/SearchAtPoint
  (defun isearch-yank-symbol ()
    "*Put symbol at current point into search string."
    (interactive)
    (let ((sym (thing-at-point 'symbol)))
      (if sym
          (progn
            (setq isearch-regexp t
                  isearch-string (concat "\\_<" (regexp-quote sym) "\\_>")
                  isearch-message (mapconcat 'isearch-text-char-description isearch-string "")
                  isearch-yank-flag t))
        (ding)))
    (isearch-search-and-update))

  ;; http://www.emacswiki.org/emacs/ZapToISearch
  (defun isearch-exit-other-end (rbeg rend)
    "Exit isearch, but at the other end of the search string.
This is useful when followed by an immediate kill."
    (interactive "r")
    (isearch-exit)
    (goto-char isearch-other-end))

  :bind (:map isearch-mode-map
              ([remap isearch-delete-char] . isearch-del-char)
              ("C-M-w" . isearch-yank-symbol)
              ([(control return)] . isearch-exit-other-end))
  :config
  (when (fboundp 'isearch-occur)
    ;; to match ivy conventions
    (define-key isearch-mode-map (kbd "C-c C-o") 'isearch-occur)))

;; grep

(setq-default grep-highlight-matches t
              grep-scroll-output t)

(when *is-a-mac*
  (setq-default locate-command "mdfind"))


;; parens

(setq show-paren-style 'mixed)
;; (add-hook 'after-init-hook 'show-paren-mode)


(use-package smartparens-config
  :demand t
  :straight smartparens
  :init
  (setq sp-base-key-bindings 'paredit)
  (setq sp-autoskip-closing-pair 'always)
  (setq sp-hybrid-kill-entire-symbol nil)
  :config
  (sp-use-paredit-bindings)
  (show-smartparens-global-mode)
  (smartparens-global-mode)

  ;; disable annoying blink-matching-paren
  (setq blink-matching-paren nil))


(use-package rainbow-delimiters
  :straight t
  :hook ((prog-mode . rainbow-delimiters-mode)))


;; nicer naming of buffers for files with identical names

;; dired

(use-package dired
  :demand t
  :init
  (let ((gls (executable-find "gls")))
    (when gls (setq insert-directory-program gls)))
  :config
  (setq dired-recursive-deletes 'top)
  (define-key dired-mode-map [mouse-2] 'dired-find-file)
  (define-key dired-mode-map (kbd "C-c C-p") 'wdired-change-to-wdired-mode))


(use-package diredfl
  :defer t
  :after dired
  :straight t
  :config
  (diredfl-global-mode))


(use-package uniquify
  :demand t
  :config
  (setq uniquify-buffer-name-style 'reverse
        uniquify-separator " • "
        uniquify-after-kill-buffer-p t
        uniquify-ignore-buffers-re "^\\*"))


(use-package diff-hl
  :defer t
  :after dired
  :straight t
  :hook ((dired-mode . diff-hl-dired-mode)))


;; recentf

(use-package recentf
  :demand t
  :hook ((after-init . recentf-mode))
  :init (setq-default
         recentf-max-saved-items 1000
         recentf-exclude '("/tmp/" "/ssh:")))

;; smex

(use-package smex
  :defer t
  :straight t
  :init (setq-default smex-save-file (expand-file-name ".smex-items" user-emacs-directory))
  :bind (("<remap> <execute-extended-command>" . smex)))

;; subword

(use-package subword
  :demand t
  :diminish (subword-mode))

;; multiple cursors

(use-package multiple-cursors
  :defer t
  :straight t
  :bind (("C-<" . mc/mark-previous-like-this)
         ("C->" . mc/mark-next-like-this)
         ("C-+" . mc/mark-next-like-this)
         ("C-c C-<" . mc/mark-all-like-this)
         ;; From active region to multiple cursors:
         ("C-c m r" . set-rectangular-region-anchor)
         ("C-c m c" . mc/edit-lines)
         ("C-c m e" . mc/edit-ends-of-lines)
         ("C-c m a" . mc/edit-beginnings-of-lines)))

;; whitespace

(use-package whitespace
  :demand t
  :preface
  (defun no-trailing-whitespace ()
    "Turn off display of trailing whitespace in this buffer."
    (setq show-trailing-whitespace nil))
  :init
  (setq-default show-trailing-whitespace t)

  ;; But don't show trailing whitespace in SQLi, inf-ruby etc.
  (dolist (hook '(special-mode-hook
                  Info-mode-hook
                  eww-mode-hook
                  term-mode-hook
                  comint-mode-hook
                  compilation-mode-hook
                  twittering-mode-hook
                  minibuffer-setup-hook))
    (add-hook hook #'no-trailing-whitespace))

  (setq whitespace-style
        '(face spaces tabs newline space-mark tab-mark newline-mark lines-tail empty)
        whitespace-line-column 80))


(use-package whitespace-cleanup-mode
  :demand t
  :straight t
  :init (setq whitespace-cleanup-mode-only-if-initially-clean nil)
  :hook ((after-init . global-whitespace-cleanup-mode))
  :diminish (whitespace-cleanup-mode)
  :bind (("<remap> <just-one-space>" . cycle-spacing)))

;; large file

(use-package vlf
  :demand t
  :straight t
  :preface
  (defun ffap-vlf ()
    "Find file at point with VLF."
    (interactive)
    (let ((file (ffap-file-at-point)))
      (unless (file-exists-p file)
        (error "File does not exist: %s" file))
      (vlf file))))


;; text-scale

(use-package default-text-scale
  :straight t)

;; unfill

(use-package unfill
  :straight t)


;; visual fill column

(use-package visual-fill-column
  :demand t
  :straight t
  :preface (defun maybe-adjust-visual-fill-column ()
             "Readjust visual fill column when the global font size is modified.
This is helpful for writeroom-mode, in particular."
             (if visual-fill-column-mode
                 (add-hook 'after-setting-font-hook 'visual-fill-column--adjust-window nil t)
               (remove-hook 'after-setting-font-hook 'visual-fill-column--adjust-window t)))
  :init
  (setq fill-column 80
        visual-fill-column-width 140)
  :hook ((visual-line-mode . visual-fill-column-mode)
         (after-init . global-visual-line-mode)
         (visual-fill-column-mode . maybe-adjust-visual-fill-column)))


;; flycheck
;;----------------------------------------------------------------------------

(use-package flycheck
  :defer t
  :straight t
  :preface
  (defun save-buffer-maybe-show-errors ()
    "Save buffer and show errors if any."
    (interactive)
    (save-buffer)
    (when (not flycheck-current-errors)
      (flycheck-list-errors)))
  :commands (flycheck-mode
             flycheck-next-error
             flycheck-previous-error)
  ;; :bind (("C-x C-s" . save-buffer-maybe-show-errors))
  :hook ((after-init . global-flycheck-mode))
  :init (setq flycheck-display-errors-function
              #'flycheck-display-error-messages-unless-error-list)
  :config (defalias 'show-error-at-point-soon
            'flycheck-show-error-at-point)
  (add-to-list 'flycheck-emacs-lisp-checkdoc-variables 'sentence-end-double-space))


(use-package flycheck-package
  :after flycheck
  :straight t)

(use-package flycheck-color-mode-line
  :after flycheck
  :straight t
  :hook ((flycheck-mode . flycheck-color-mode-line-mode)))


;; company
;;----------------------------------------------------------------------------

(use-package company
  :defer t
  :straight t
  :init
  (setq tab-always-indent 'complete
        company-minimum-prefix-length 2
        company-idle-delay 0
        ;; company-transformers '(company-sort-by-occurrence)
        company-transformers nil
        company-require-match nil)
  :hook ((after-init . global-company-mode))
  :bind (("M-C-/" . company-complete)
         :map company-mode-map
         ("M-/" . company-complete)
         :map company-active-map
         ("M-/" . company-other-backend)
         ("C-n" . company-select-next)
         ("C-p" . company-select-previous))
  :config
  (setq-default company-dabbrev-other-buffers 'all
                company-tooltip-align-annotations t)
  
  (defvar my-prev-whitespace-mode nil)
  (make-variable-buffer-local 'my-prev-whitespace-mode)
  (defun pre-popup-draw ()
    "Turn off whitespace mode before showing company complete tooltip"
    (if whitespace-mode
        (progn
          (setq my-prev-whitespace-mode t)
          (whitespace-mode -1)
          (setq my-prev-whitespace-mode t))))
  (defun post-popup-draw ()
    "Restore previous whitespace mode after showing company tooltip"
    (if my-prev-whitespace-mode
        (progn
          (whitespace-mode 1)
          (setq my-prev-whitespace-mode nil))))
  (advice-add 'company-pseudo-tooltip-unhide :before #'pre-popup-draw)
  (advice-add 'company-pseudo-tooltip-hide :after #'post-popup-draw)
  (diminish 'company-mode "CMP"))


(use-package company-quickhelp
  :defer t
  :after company
  :straight t
  :bind (:map company-active-map
              ("C-c h" . company-quickhelp-manual-begin))
  :hook ((after-init . company-quickhelp-mode)))


(use-package company-math
  :defer t
  :straight t)


(use-package company-flx
  :demand t
  :straight t
  :after company
  :config (company-flx-mode +1))


;; version control

(use-package git-gutter
  :straight t
  :diminish
  :hook (after-init . global-git-gutter-mode)
  :bind (("C-x C-g" . git-gutter)
         ("C-x v =" . git-gutter:popup-hunk)
         ("C-x p" . git-gutter:previous-hunk)
         ("C-x n" . git-gutter:next-hunk))
 :init (setq git-gutter:visual-line t
             git-gutter:disabled-modes '(asm-mode image-mode)
             git-gutter:modified-sign "■"
             git-gutter:added-sign "●"
             git-gutter:deleted-sign "✘"))



;; projectile
;;----------------------------------------------------------------------------
(use-package projectile
  :defer 5
  :straight t
  :diminish
  :bind (("C-c TAB" . projectile-find-other-file)
         ("M-?" . counsel-search-project))
  :bind-keymap ("C-c p" . projectile-command-map)
  :hook ((after-init . projectile-global-mode))
  :init (setq projectile-require-project-root nil)
  :config (let ((search-function
                 (cond
                  ((executable-find "rg") 'counsel-rg)
                  ((executable-find "ag") 'counsel-ag)
                  ((executable-find "pt") 'counsel-pt)
                  ((executable-find "ack") 'counsel-ack))))
            (when search-function
              (defun counsel-search-project (initial-input &optional use-current-dir)
                "Search using `counsel-rg' or similar from the project root for INITIAL-INPUT.
If there is no project root, or if the prefix argument
USE-CURRENT-DIR is set, then search from the current directory
instead."
                (interactive (list (thing-at-point 'symbol)
                                   current-prefix-arg))
                (let ((current-prefix-arg)
                      (dir (if use-current-dir
                               default-directory
                             (condition-case err
                                 (projectile-project-root)
                               (error default-directory)))))
                  (funcall search-function initial-input dir))))))


(use-package counsel-projectile
  :after (counsel projectile)
  :straight t
  :config
  (counsel-projectile-mode)
  (define-key counsel-projectile-mode-map [remap projectile-ag]
    #'counsel-projectile-rg))



;; ivy settings
;;----------------------------------------------------------------------------

(use-package ivy
  :defer t
  :straight t
  :diminish ivy-mode
  :hook ((after-init . ivy-mode))
  :config (setq-default ivy-use-virtual-buffers t
                      ivy-dynamic-exhibit-delay-ms 150
                      ivy-count-format ""
                      ivy-virtual-abbreviate 'fullpath)
  :bind (:map ivy-minibuffer-map
              ("RET" . ivy-alt-done)
              ("C-j" . ivy-immediate-done)
              ("C-RET" . ivy-immediate-done)
              ("<up>" . ivy-previous-line-or-history)))

(use-package ivy-historian
  :defer t
  :straight t
  :hook ((after-init . ivy-historian-mode)))

(use-package swiper
  :defer t
  :after ivy
  :straight t
  :bind (("C-s" . swiper)
         :map ivy-mode-map
              ("M-s /". swiper-at-point))
  :preface
  (defun swiper-at-point (sym)
    "Use `swiper' to search for the symbol at point."
    (interactive (list (thing-at-point 'symbol)))
    (swiper sym)))

(use-package counsel
  :defer t
  :straight t
  :diminish (counsel-mode)
  :init
  (setq-default counsel-mode-override-describe-bindings t)
  :hook ((after-init . counsel-mode)))

(use-package ivy-xref
  :defer t
  :straight t
  :init
  (setq xref-show-xrefs-function 'ivy-xref-show-xrefs))

;; ivy-support-chinese-pinyin
;; https://github.com/pengpengxp/swiper/wiki/ivy-support-chinese-pinyin

(use-package pinyinlib
  :demand t
  :straight t
  :config
  (defun re-builder-pinyin (str)
    (or (pinyin-to-utf8 str)
        (ivy--regex-plus str)
        (ivy--regex-ignore-order)))

  (setq ivy-re-builders-alist
        '((t . re-builder-pinyin)))

  (defun my-pinyinlib-build-regexp-string (str)
    (progn
      (cond ((equal str ".*") ".*")
            (t (pinyinlib-build-regexp-string str t)))))
  (defun my-pinyin-regexp-helper (str)
    (cond ((equal str " ") ".*")
          ((equal str "") nil)
          (t str)))

  (defun pinyin-to-utf8 (str)
    (cond ((equal 0 (length str)) nil)
          ((equal (substring str 0 1) "!")
           (mapconcat 'my-pinyinlib-build-regexp-string
                      (remove nil
                              (mapcar 'my-pinyin-regexp-helper
                                      (split-string (replace-in-string str "!" "") ""))) ""))
          nil)))


;; Themes
;;----------------------------------------------------------------------------

;; Font

(add-to-list 'initial-frame-alist
             '(font . "OperatorMonoLig Nerd Font-14"))
(add-to-list 'default-frame-alist
             '(font . "OperatorMonoLig Nerd Font-14"))


;; Now I use emojify
;; (when (member "Apple Color Emoji" (font-family-list))
;;   (set-fontset-font t 'unicode "Apple Color Emoji" nil 'prepend))

(use-package emojify
  :straight t
  :commands emojify-mode
  :hook ((after-init . global-emojify-mode))
  :init (setq emojify-emoji-styles '(unicode github)
              emojify-display-style 'unicode))


;; all the icons

(use-package all-the-icons
  :demand t
  :init (setq inhibit-compacting-font-caches t)
  :straight t)


;; (use-package mode-icons
;;   :demand t
;;   :straight t
;;   :init (setq mode-icons-change-mode-name t
;;               mode-icons-desaturate-inactive nil
;;               mode-icons-desaturate-active nil
;;               mode-icons-grayscale-transform nil)
;;   :hook ((after-init . mode-icons-mode))
;;   :config (push '("\\` ?CMP\\'" #xf1ad FontAwesome) mode-icons))


;; Mode Line

(use-package mode-line-bell
  :demand t
  :straight t
  :hook ((after-init . mode-line-bell-mode)))


(use-package powerline
  :straight t)


(use-package spaceline-config
  :demand t
  :init
  (setq-default
   mode-line-format '("%e" (:eval (spaceline-ml-main)))
   powerline-default-separator 'contour
   powerline-gui-use-vcs-glyph t
   powerline-height 22
   spaceline-highlight-face-func 'spaceline-highlight-face-modified
   spaceline-workspace-numbers-unicode t
   spaceline-window-numbers-unicode t
   spaceline-separator-dir-left '(left . right)
   spaceline-separator-dir-right '(right . left)
   spaceline-flycheck-bullet "❀ %s")
  (spaceline-info-mode 1)
  :straight spaceline
  :config
  (spaceline-define-segment nasy:version-control
    "Version control information."
    (when vc-mode
      (let ((branch (mapconcat 'concat (cdr (split-string vc-mode "[:-]")) "-")))
        (powerline-raw
         (s-trim (concat "  "
                         branch
                         (when (buffer-file-name)
                           (pcase (vc-state (buffer-file-name))
                             (`up-to-date " ✓")
                             (`edited " ❓")
                             (`added " ➕")
                             (`unregistered " ■")
                             (`removed " ✘")
                             (`needs-merge " ↓")
                             (`needs-update " ↑")
                             (`ignored " ✦")
                             (_ " ⁇")))))))))

  (spaceline-define-segment nasy-time
    "Time"
    (format-time-string "%b %d, %Y - %H:%M")
    :tight-right t)

  (spaceline-define-segment flycheck-status
    "An `all-the-icons' representaiton of `flycheck-status'"
    (let* ((text
            (pcase flycheck-last-status-change
              (`finished (if flycheck-current-errors
                             (let ((count (let-alist (flycheck-count-errors flycheck-current-errors)
                                            (+ (or .warning 0) (or .error 0)))))
                               (format "✖ %s Issue%s" count (if (eq 1 count) "" "s")))
                           "✔ No Issues"))
              (`running     "⟲ Running")
              (`no-checker  "⚠ No Checker")
              (`not-checked "✖ Disabled")
              (`errored     "⚠ Error")
              (`interrupted "⛔ Interrupted")
              (`suspicious  "")))
           (f (cond
               ((string-match "⚠" text) `(:height 0.9 :foreground ,(face-attribute 'spaceline-flycheck-warning :foreground)))
               ((string-match "✖ [0-9]" text) `(:height 0.9 :foreground ,(face-attribute 'spaceline-flycheck-error :foreground)))
               ((string-match "✖ Disabled" text) `(:height 0.9 :foreground ,(face-attribute 'font-lock-comment-face :foreground)))
               (t '(:height 0.9 :inherit)))))
      (propertize (format "%s" text)
                  'face f
                  'help-echo "Show Flycheck Errors"
                  'mouse-face '(:box 1)
                  'local-map (make-mode-line-mouse-map 'mouse-1 (lambda () (interactive) (flycheck-list-errors)))))
    :when active)

  (spaceline-compile
    `(((major-mode buffer-modified buffer-size) :face highlight-face)
      (anzu)
      ((nasy:version-control projectile-root) :separator " in ")
      (buffer-id)
      ((flycheck-status (flycheck-error flycheck-warning flycheck-info)))
      (selection-info))
    `((which-function)
      (global :face highlight-face)
      (line-column)
      (minor-modes)
      (buffer-position hud)
      (nasy-time))))


(use-package doom-themes
  :demand t
  :straight t
  :init
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  :config
  (load-theme 'doom-challenger-deep t)
  (doom-themes-treemacs-config)
  (doom-themes-org-config))

;; custom file
;;----------------------------------------------------------------------------

(when (file-exists-p custom-file)
  (load custom-file))

;;; init.el ends here
