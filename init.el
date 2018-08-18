;;; init.el --- Nasy's emacs.d init file.            -*- lexical-binding: t; -*-
;; Copyright (C) 2018  Nasy

;; Author: Nasy <echo bmFzeXh4QGdtYWlsLmNvbQo= | base64 -d (or -D on macOS)>

;;; Commentary:

;; Nasy's emacs.d init file.  For macOS and Emacs 26.

;;; Code:
(setq debug-on-error t)
(setq message-log-max t)
(setq-default lexical-binding t
              ad-redefinition-action 'accept)

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

(let ((normal-gc-cons-threshold (* 1024 1024 1024))
      (init-gc-cons-threshold (* 2048 1024 1024)))
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
  :straight t)

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

(use-package async
  :straight t
  :config
  (autoload 'dired-async-mode "dired-async.el" nil t)
  (dired-async-mode 1)
  (async-bytecomp-package-mode 1))

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
  :init (setq shell-file-name "/bin/zsh"
              shell-command-switch "-ic")
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

;; dashboard

(use-package dashboard
  :straight t
  :init (setq dashboard-banner-logo-title (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
              dashboard-startup-banner 'official
              dashboard-items '((recents   . 5)
                                (bookmarks . 5)
                                (projects  . 5)
                                (agenda    . 5)
                                (registers . 5)))
  :config
  (dashboard-setup-startup-hook)
  (when (get-buffer "*dashboard*")
    (setq initial-buffer-choice #'(lambda () (get-buffer "*dashboard*")))))

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
 blink-cursor-interval 0.6
 bookmark-default-file (expand-file-name ".bookmarks.el" user-emacs-directory)
 buffers-menu-max-size 30
 case-fold-search t
 column-number-mode t
 cursor-in-non-selected-windows t
 ;; cursor-type 'bar
 dired-dwim-target t
 ediff-split-window-function 'split-window-horizontally
 ediff-window-setup-function 'ediff-setup-windows-plain
 fill-column 80
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

(blink-cursor-mode t)


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

(setq show-paren-style 'expression)
(add-hook 'after-init-hook 'show-paren-mode)


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

;; highlight indention

(use-package highlight-indent-guides
  :straight t
  :init (setq highlight-indent-guides-method 'column)
  :hook ((prog-mode . highlight-indent-guides-mode)))


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


;; shell

(use-package shell)


;; recentf

(use-package recentf
  :demand t
  :hook ((after-init . recentf-mode))
  :init (setq-default
         recentf-save-file "~/.emacs.d/recentf"
         recentf-max-saved-items 100
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


;; mmm-mode

(use-package mmm-auto
  :demand t
  :straight mmm-mode
  :init (setq mmm-global-mode 'buffers-with-submode-classes
              mmm-submode-decoration-level 2))


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
  ;; :init (setq whitespace-cleanup-mode-only-if-initially-clean nil)
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
        visual-fill-column-width 100
        word-wrap t)
  :hook ((visual-line-mode . visual-fill-column-mode)
         ;; (after-init . global-visual-line-mode)
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

;; (use-package flycheck-color-mode-line
;;   :after flycheck
;;   :straight t
;;   :hook ((flycheck-mode . flycheck-color-mode-line-mode)))


;; (use-package flycheck-posframe
;;   :after flycheck
;;   :straight t
;;   :hook ((flycheck-mode . flycheck-posframe-mode)
;;          (flycheck-mode . flycheck-posframe-configure-pretty-defaults)))


;; company
;;----------------------------------------------------------------------------

(use-package company
  :defer t
  :straight t
  :init
  (setq-default tab-always-indent 'complete
                company-minimum-prefix-length .2
                company-idle-delay .5
                company-transformers '(company-sort-by-backend-importance)
                ;; company-transformers '(company-sort-by-occurrence)
                ;; company-transformers nil
                company-require-match nil
                company-tooltip-align-annotations t
                company-dabbrev-other-buffers 'all
                company-dabbrev-downcase nil
                company-dabbrev-ignore-case t
                company-gtags-executable "gtags")
  :hook ((after-init . global-company-mode))
  :bind (("M-C-/" . company-complete)
         :map company-mode-map
         ("M-/" . company-complete)
         ;; ("<tab>" . company-complete)
         :map company-active-map
         ("<tab>" . company-other-backend)
         ("C-n" . company-select-next)
         ("C-p" . company-select-previous))
  :config
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

  (defun nasy:local-push-company-backend (backend)
    "Add BACKEND to a buffer-local version of `company-backends'."
    (make-local-variable 'company-backends)
    (push backend company-backends))

  (diminish 'company-mode "CMP"))

(use-package company-try-hard
  :demand t
  :straight t
  :bind (("C-z" . company-try-hard)
         :map company-active-map
         ("C-z" . company-try-hard)))


;; (use-package company-posframe
;;   :after company
;;   :straight t
;;   :init (push '(company-posframe-mode . nil)
;;               desktop-minor-mode-table)
;;   :hook ((after-init . company-posframe-mode))
;;   :diminish company-posframe-mode)


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


;; anzu

(use-package anzu
  :defer t
  :straight t
  :hook ((after-init . global-anzu-mode))
  :bind ([remap query-replace] . anzu-query-replace-regexp))


;; outline-magic

(use-package outline-magic
  :demand t
  :straight t
  :preface
  ;; https://www.emacswiki.org/emacs/python-magic.el
  (defun py-outline-level ()
    (let (buffer-invisibility-spec)
      (save-excursion
        (skip-chars-forward "    ")
        (current-column))))

  (defun python-outline-hook ()
    (setq outline-regexp "[ \t]+\\(class\\|def\\|if\\|elif\\|else\\|while\\|for\\|try\\|except\\|with\\) ")
    (setq outline-level 'py-outline-level)
    (outline-minor-mode t)
    (hide-body))
  :bind (:map outline-minor-mode-map
              ("<C-tab>" . outline-cycle))
  :hook ((python-mode . python-outline-hook))
  :diminish outline-minor-mode)


;; projectile
;;----------------------------------------------------------------------------
(use-package projectile
  :defer 5
  :straight t
  :diminish
  :bind (("C-c TAB" . projectile-find-other-file)
         ("M-?" . counsel-search-project))
  ;; :bind-keymap ("C-c p" . projectile-command-map)
  :hook ((after-init . projectile-global-mode))
  :init (setq projectile-require-project-root nil
              projectile-keymap-prefix (kbd "C-c C-p"))
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


(use-package counsel
  :defer t
  :straight t
  :diminish (counsel-mode)
  :init
  (setq-default counsel-mode-override-describe-bindings t)
  :hook ((after-init . counsel-mode)))


;; (use-package counsel-projectile
;;   :after (counsel projectile)
;;   :straight t
;;   :config
;;   (counsel-projectile-mode)
;;   (define-key counsel-projectile-mode-map [remap projectile-ag]
;;     #'counsel-projectile-rg))


;; helm settings
;;----------------------------------------------------------------------------

(use-package helm
  :demand t
  :straight t
  :bind (("M-x" . helm-M-x)
         ("C-x c o" . helm-occur)
         ("<f1> SPC" . helm-all-mark-rings) ; I modified the keybinding
         ("M-y" . helm-show-kill-ring)
         ("C-x c x" . helm-register)    ; C-x r SPC and C-x r j
         ("C-x c g" . helm-google-suggest)
         ("C-x c M-:" . helm-eval-expression-with-eldoc)
         ("C-x C-f" . helm-find-files)
         ("C-x b" . helm-mini)      ; *<major-mode> or /<dir> or !/<dir-not-desired> or @<regexp>
         :map helm-map
         ("<tab>" . helm-execute-persistent-action) ; rebind tab to run persistent action
         ("C-i" . helm-execute-persistent-action) ; make TAB works in terminal
         ("C-z" . helm-select-action) ; list actions using C-z
         :map shell-mode-map
         ("C-c C-l" . helm-comint-input-ring) ; in shell mode
         :map minibuffer-local-map
         ("C-c C-l" . helm-minibuffer-history))
  :init
  (require 'helm-config)

  (setq helm-M-x-fuzzy-match        t
        helm-buffers-fuzzy-matching t
        helm-recentf-fuzzy-match    t
        helm-imenu-fuzzy-match      t
        helm-locate-fuzzy-match     t
        helm-apropos-fuzzy-match    t
        helm-lisp-fuzzy-completion  t)

  (when (executable-find "curl")
    (setq helm-google-suggest-use-curl-p t))

  (setq helm-split-window-in-side-p           t ; open helm buffer inside current window, not occupy whole other window
        helm-move-to-line-cycle-in-source     t ; move to end or beginning of source when reaching top or bottom of source.
        helm-ff-search-library-in-sexp        t ; search for library in `require' and `declare-function' sexp.
        helm-scroll-amount                    8 ; scroll 8 lines other window using M-<next>/M-<prior>
        helm-ff-file-name-history-use-recentf t
        helm-echo-input-in-header-line        t)

  :config

  (add-to-list 'helm-sources-using-default-as-input 'helm-source-man-pages)

  (helm-mode 1)
  (helm-autoresize-mode 1)

  (setq helm-follow-mode-persistent t
        helm-allow-mouse t
        helm-move-to-line-cycle-in-source nil))

(use-package helm-eshell
  :after helm
  :bind (:map eshell-mode-map
              ("C-c C-l" . helm-eshell-history)))

(use-package helm-descbinds
  :straight t
  :after helm
  :config
  (helm-descbinds-mode))

(use-package helm-projectile
  :straight t
  :hook ((after-init . helm-projectile-on))
  :init
  (setq projectile-completion-system 'helm))

(use-package helm-ag
  :straight t
  :bind (("C-s" . helm-do-ag-this-file))
  :init (setq helm-ag-base-command "rg --no-heading --smart-case"
              helm-ag-fuzzy-match t
              helm-ag-use-grep-ignore-list t
              helm-ag-use-agignore t))

(use-package helm-dash
  :straight t
  :init (setq helm-dash-docsets-path "~/.docsets"))

;; ivy settings
;;----------------------------------------------------------------------------

;; (use-package ivy
;;   :defer t
;;   :straight t
;;   :diminish ivy-mode
;;   :hook ((after-init . ivy-mode))
;;   :config (setq-default ivy-use-virtual-buffers t
;;                         ivy-dynamic-exhibit-delay-ms 150
;;                         ivy-count-format ""
;;                         ivy-virtual-abbreviate 'fullpath)
;;   :bind (:map ivy-minibuffer-map
;;               ("RET" . ivy-alt-done)
;;               ("C-j" . ivy-immediate-done)
;;               ("C-RET" . ivy-immediate-done)
;;               ("<up>" . ivy-previous-line-or-history)))

;; (use-package ivy-historian
;;   :defer t
;;   :straight t
;;   :hook ((after-init . ivy-historian-mode)))

;; (use-package swiper
;;   :defer t
;;   :after ivy
;;   :straight t
;;   :bind (("C-s" . swiper)
;;          :map ivy-mode-map
;;               ("M-s /". swiper-at-point))
;;   :preface
;;   (defun swiper-at-point (sym)
;;     "Use `swiper' to search for the symbol at point."
;;     (interactive (list (thing-at-point 'symbol)))
;;     (swiper sym)))

;; (use-package ivy-xref
;;   :defer t
;;   :straight t
;;   :init
;;   (setq xref-show-xrefs-function 'ivy-xref-show-xrefs))

;; ;; ivy-support-chinese-pinyin
;; ;; https://github.com/pengpengxp/swiper/wiki/ivy-support-chinese-pinyin

;; (use-package pinyinlib
;;   :demand t
;;   :straight t
;;   :config
;;   (defun re-builder-pinyin (str)
;;     (or (pinyin-to-utf8 str)
;;         (ivy--regex-plus str)
;;         (ivy--regex-ignore-order)))

;;   (setq ivy-re-builders-alist
;;         '((t . re-builder-pinyin)))

;;   (defun my-pinyinlib-build-regexp-string (str)
;;     (progn
;;       (cond ((equal str ".*") ".*")
;;             (t (pinyinlib-build-regexp-string str t)))))
;;   (defun my-pinyin-regexp-helper (str)
;;     (cond ((equal str " ") ".*")
;;           ((equal str "") nil)
;;           (t str)))

;;   (defun pinyin-to-utf8 (str)
;;     (cond ((equal 0 (length str)) nil)
;;           ((equal (substring str 0 1) "!")
;;            (mapconcat 'my-pinyinlib-build-regexp-string
;;                       (remove nil
;;                               (mapcar 'my-pinyin-regexp-helper
;;                                       (split-string (replace-in-string str "!" "") ""))) ""))
;;           nil)))

;; Treemacs
;;----------------------------------------------------------------------------

(use-package treemacs
  :defer t
  :straight t
  :init
  (with-eval-after-load 'winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window))
  :config
  (progn
    (setq treemacs-collapse-dirs              (if (executable-find "python3") 3 0)
          treemacs-deferred-git-apply-delay   0.5
          treemacs-display-in-side-window     t
          treemacs-file-event-delay           5000
          treemacs-file-follow-delay          0.2
          treemacs-follow-after-init          t
          treemacs-follow-recenter-distance   0.1
          treemacs-goto-tag-strategy          'refetch-index
          treemacs-indentation                2
          treemacs-indentation-string         " "
          treemacs-is-never-other-window      nil
          treemacs-no-png-images              nil
          treemacs-project-follow-cleanup     nil
          treemacs-persist-file               (expand-file-name ".cache/treemacs-persist" user-emacs-directory)
          treemacs-recenter-after-file-follow nil
          treemacs-recenter-after-tag-follow  nil
          treemacs-show-hidden-files          t
          treemacs-silent-filewatch           nil
          treemacs-silent-refresh             nil
          treemacs-sorting                    'alphabetic-desc
          treemacs-space-between-root-nodes   t
          treemacs-tag-follow-cleanup         t
          treemacs-tag-follow-delay           1.5
          treemacs-width                      35)

    ;; The default width and height of the icons is 22 pixels. If you are
    ;; using a Hi-DPI display, uncomment this to double the icon size.
    (treemacs-resize-icons 44)

    (treemacs-follow-mode t)
    (treemacs-filewatch-mode t)
    (treemacs-fringe-indicator-mode t)
    (pcase (cons (not (null (executable-find "git")))
                 (not (null (executable-find "python3"))))
      (`(t . t)
       (treemacs-git-mode 'extended))
      (`(t . _)
       (treemacs-git-mode 'simple))))
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
        ("C-x t 1"   . treemacs-delete-other-windows)
        ("C-x t t"   . treemacs)
        ("C-x t B"   . treemacs-bookmark)
        ("C-x t C-t" . treemacs-find-file)
        ("C-x t M-t" . treemacs-find-tag)))

(use-package treemacs-projectile
  :after treemacs projectile
  :straight t)


;; auto insert
;;----------------------------------------------------------------------------

(use-package autoinsert
  :init
  (define-auto-insert
    '("\\.py" . "Python Language")
    '("#!/usr/bin/env python3\n"
      "# -*- coding: utf-8 -*-\n"
      "\"\"\"\n"
      "Life's pathetic, have fun (\"▔□▔)/hi~♡ Nasy.\n\n"
      "Excited without bugs::\n\n"
      "    |             *         *\n"
      "    |                  .                .\n"
      "    |           .\n"
      "    |     *                      ,\n"
      "    |                   .\n"
      "    |\n"
      "    |                               *\n"
      "    |          |\\___/|\n"
      "    |          )    -(             .              ·\n"
      "    |         =\\ -   /=\n"
      "    |           )===(       *\n"
      "    |          /   - \\\n"
      "    |          |-    |\n"
      "    |         /   -   \\     0.|.0\n"
      "    |  NASY___\\__( (__/_____(\\=/)__+1s____________\n"
      "    |  ______|____) )______|______|______|______|_\n"
      "    |  ___|______( (____|______|______|______|____\n"
      "    |  ______|____\\_|______|______|______|______|_\n"
      "    |  ___|______|______|______|______|______|____\n"
      "    |  ______|______|______|______|______|______|_\n"
      "    |  ___|______|______|______|______|______|____\n\n"
      "author   : Nasy https://nasy.moe\n"
      "date     : " (format-time-string "%b %e, %Y") \n
      "email    : Nasy <nasyxx+python@gmail.com>" \n
      "filename : " (file-name-nondirectory (buffer-file-name)) \n
      "project  : " (file-name-nondirectory (directory-file-name (projectile-project-root))) \n
      "license  : GPL-3.0+\n\n"
      "There are more things in heaven and earth, Horatio, than are dreamt.\n"
      " --  From \"Hamlet\"\n"
      "\"\"\"\n")))


;; pretty
;;----------------------------------------------------------------------------

(use-package pretty-mode
  :demand t
  :straight t
  :hook (((prog-mode text-mode) . turn-on-pretty-mode)
         (after-init . global-prettify-symbols-mode)
         (python-mode . (lambda ()
                          (mapc (lambda (pair) (push pair prettify-symbols-alist))
                                '(;; Syntax
                                  ("def" .      #x2131)
                                  ;; ("not" .      #x2757)
                                  ("not" .      #xac)
                                  ("in" .       #x2208)
                                  ("not in" .   #x2209)
                                  ("return" .   #x27fc)
                                  ("yield" .    #x27fb)
                                  ("for" .      #x2200)
                                  ;; Extend Functions
                                  ("any" .      #x2754)
                                  ("all" .      #x2201)
                                  ("sum" .      #x2211)
                                  ("dict" .     #x1d507)
                                  ("list" .     #x2112)
                                  ("tuple" .    #x2a02)
                                  ("set" .      #x2126)
                                  ;; Base Types
                                  ("int" .      #x2124)
                                  ("float" .    #x211d)
                                  ("str" .      #x1d54a)
                                  ("True" .     #x1d54b)
                                  ("False" .    #x1d53d)
                                  ;; Extend Types
                                  ("Int" .      #x2124)
                                  ("Float" .    #x211d)
                                  ("String" .   #x1d54a)
                                  ;; Mypy
                                  ("Dict" .     #x1d507)
                                  ("List" .     #x2112)
                                  ("Tuple" .    #x2a02)
                                  ("Set" .      #x2126)
                                  ("Iterable" . #x1d50a)
                                  ("Any" .      #x2754)
                                  ("Union" .    #x22c3)))))
         (haskell-mode . (lambda ()
                          (mapc (lambda (pair) (push pair prettify-symbols-alist))
                                '(;; Syntax
                                  ("not" .      #x2757)
                                  ("in" .       #x2208)
                                  ("elem" .     #x2208)
                                  ("not in" .   #x2209)
                                  ("notElem" .  #x2209)
                                  ;; Types
                                  ("String" .   #x1d54a)
                                  ("Int" .      #x2124)
                                  ("Float" .    #x211d)
                                  ("True" .     #x1d54b)
                                  ("False" .    #x1d53d)
                                  ;; Functions
                                  ("sum" .      #x2211))))))
  :config
  ;; pretty python mode
  (pretty-deactivate-groups '( :sets-relations  ;; break int in python mode
                               :logic           ;; break for in python mode
                               )
                            'python-mode)
  (pretty-add-keywords 'python-mode '(
                                      ("->" .       #X2192)  ;; →
                                      ;; ("def" .      #x2131)
                                      ;; ;; ("not" .      #x2757)
                                      ;; ("not" .      #xac)
                                      ;; ("in" .       #x2208)
                                      ;; ("not in" .   #x2209)
                                      ;; ("return" .   #x27fc)
                                      ;; ("yield" .    #x27fb)
                                      ;; ("for" .      #x2200)
                                      ;; ;; Extend Functions
                                      ;; ("any" .      #x2754)
                                      ;; ("all" .      #x2201)
                                      ;; ("sum" .      #x2211)
                                      ;; ("dict" .     #x1d507)
                                      ;; ("list" .     #x2112)
                                      ;; ("tuple" .    #x2a02)
                                      ;; ("set" .      #x2126)
                                      ;; ;; Base Types
                                      ;; ("int" .      #x2124)
                                      ;; ("float" .    #x211d)
                                      ;; ("str" .      #x1d54a)
                                      ;; ("True" .     #x1d54b)
                                      ;; ("False" .    #x1d53d)
                                      ;; ;; Extend Types
                                      ;; ("Int" .      #x2124)
                                      ;; ("Float" .    #x211d)
                                      ;; ("String" .   #x1d54a)
                                      ;; ;; Mypy
                                      ;; ("Dict" .     #x1d507)
                                      ;; ("List" .     #x2112)
                                      ;; ("Tuple" .    #x2a02)
                                      ;; ("Set" .      #x2126)
                                      ;; ("Iterable" . #x1d50a)
                                      ;; ("Any" .      #x2754)
                                      ;; ("Union" .    #x22c3)
                                      ))
  (pretty-activate-groups
   '(:sub-and-superscripts :greek :arithmetic-nary)))


(use-package ipretty
  :defer t
  :straight t
  :hook ((after-init . ipretty-mode)))

;; https://github.com/tonsky/FiraCode/wiki/Emacs-instructions
;; This works when using emacs --daemon + emacsclient
(add-hook 'after-make-frame-functions (lambda (frame) (set-fontset-font t '(#Xe100 . #Xe16f) "Fira Code Symbol")))
;; This works when using emacs without server/client
(set-fontset-font t '(#Xe100 . #Xe16f) "Fira Code Symbol")
;; I haven't found one statement that makes both of the above situations work, so I use both for now

(defconst fira-code-font-lock-keywords-alist
  (mapcar (lambda (regex-char-pair)
            `(,(car regex-char-pair)
              (0 (prog1 ()
                   (compose-region (match-beginning 1)
                                   (match-end 1)
                                   ;; The first argument to concat is a string containing a literal tab
                                   ,(concat "	" (list (decode-char 'ucs (cadr regex-char-pair)))))))))
          '(("\\(www\\)"                   #Xe100)
            ("[^/]\\(\\*\\*\\)[^/]"        #Xe101)
            ("\\(\\*\\*\\*\\)"             #Xe102)
            ("\\(\\*\\*/\\)"               #Xe103)
            ("\\(\\*>\\)"                  #Xe104)
            ("[^*]\\(\\*/\\)"              #Xe105)
            ("\\(\\\\\\\\\\)"              #Xe106)
            ("\\(\\\\\\\\\\\\\\)"          #Xe107)
            ("\\({-\\)"                    #Xe108)
            ;; ("\\(\\[\\]\\)"                #Xe109)
            ("\\(::\\)"                    #Xe10a)
            ("\\(:::\\)"                   #Xe10b)
            ("[^=]\\(:=\\)"                #Xe10c)
            ("\\(!!\\)"                    #Xe10d)
            ("\\(!=\\)"                    #Xe10e)
            ("\\(!==\\)"                   #Xe10f)
            ("\\(-}\\)"                    #Xe110)
            ("\\(--\\)"                    #Xe111)
            ("\\(---\\)"                   #Xe112)
            ("\\(-->\\)"                   #Xe113)
            ("[^-]\\(->\\)"                #Xe114)
            ("\\(->>\\)"                   #Xe115)
            ("\\(-<\\)"                    #Xe116)
            ("\\(-<<\\)"                   #Xe117)
            ("\\(-~\\)"                    #Xe118)
            ("\\(#{\\)"                    #Xe119)
            ("\\(#\\[\\)"                  #Xe11a)
            ("\\(##\\)"                    #Xe11b)
            ("\\(###\\)"                   #Xe11c)
            ("\\(####\\)"                  #Xe11d)
            ("\\(#(\\)"                    #Xe11e)
            ("\\(#\\?\\)"                  #Xe11f)
            ("\\(#_\\)"                    #Xe120)
            ("\\(#_(\\)"                   #Xe121)
            ("\\(\\.-\\)"                  #Xe122)
            ("\\(\\.=\\)"                  #Xe123)
            ("\\(\\.\\.\\)"                #Xe124)
            ("\\(\\.\\.<\\)"               #Xe125)
            ("\\(\\.\\.\\.\\)"             #Xe126)
            ("\\(\\?=\\)"                  #Xe127)
            ("\\(\\?\\?\\)"                #Xe128)
            ("\\(;;\\)"                    #Xe129)
            ("\\(/\\*\\)"                  #Xe12a)
            ("\\(/\\*\\*\\)"               #Xe12b)
            ("\\(/=\\)"                    #Xe12c)
            ("\\(/==\\)"                   #Xe12d)
            ("\\(/>\\)"                    #Xe12e)
            ("\\(//\\)"                    #Xe12f)
            ("\\(///\\)"                   #Xe130)
            ("\\(&&\\)"                    #Xe131)
            ("\\(||\\)"                    #Xe132)
            ("\\(||=\\)"                   #Xe133)
            ("[^|]\\(|=\\)"                #Xe134)
            ("\\(|>\\)"                    #Xe135)
            ("\\(\\^=\\)"                  #Xe136)
            ("\\(\\$>\\)"                  #Xe137)
            ("\\(\\+\\+\\)"                #Xe138)
            ("\\(\\+\\+\\+\\)"             #Xe139)
            ("\\(\\+>\\)"                  #Xe13a)
            ("\\(=:=\\)"                   #Xe13b)
            ("[^!/]\\(==\\)[^>]"           #Xe13c)
            ("\\(===\\)"                   #Xe13d)
            ("\\(==>\\)"                   #Xe13e)
            ("[^=]\\(=>\\)"                #Xe13f)
            ("\\(=>>\\)"                   #Xe140)
            ("\\(<=\\)"                    #Xe141)
            ("\\(=<<\\)"                   #Xe142)
            ("\\(=/=\\)"                   #Xe143)
            ("\\(>-\\)"                    #Xe144)
            ("\\(>=\\)"                    #Xe145)
            ("\\(>=>\\)"                   #Xe146)
            ("[^-=]\\(>>\\)"               #Xe147)
            ("\\(>>-\\)"                   #Xe148)
            ("\\(>>=\\)"                   #Xe149)
            ("\\(>>>\\)"                   #Xe14a)
            ("\\(<\\*\\)"                  #Xe14b)
            ("\\(<\\*>\\)"                 #Xe14c)
            ("\\(<|\\)"                    #Xe14d)
            ("\\(<|>\\)"                   #Xe14e)
            ("\\(<\\$\\)"                  #Xe14f)
            ("\\(<\\$>\\)"                 #Xe150)
            ("\\(<!--\\)"                  #Xe151)
            ("\\(<-\\)"                    #Xe152)
            ("\\(<--\\)"                   #Xe153)
            ("\\(<->\\)"                   #Xe154)
            ("\\(<\\+\\)"                  #Xe155)
            ("\\(<\\+>\\)"                 #Xe156)
            ("\\(<=\\)"                    #Xe157)
            ("\\(<==\\)"                   #Xe158)
            ("\\(<=>\\)"                   #Xe159)
            ("\\(<=<\\)"                   #Xe15a)
            ("\\(<>\\)"                    #Xe15b)
            ("[^-=]\\(<<\\)"               #Xe15c)
            ("\\(<<-\\)"                   #Xe15d)
            ("\\(<<=\\)"                   #Xe15e)
            ("\\(<<<\\)"                   #Xe15f)
            ("\\(<~\\)"                    #Xe160)
            ("\\(<~~\\)"                   #Xe161)
            ("\\(</\\)"                    #Xe162)
            ("\\(</>\\)"                   #Xe163)
            ("\\(~@\\)"                    #Xe164)
            ("\\(~-\\)"                    #Xe165)
            ("\\(~=\\)"                    #Xe166)
            ("\\(~>\\)"                    #Xe167)
            ("[^<]\\(~~\\)"                #Xe168)
            ("\\(~~>\\)"                   #Xe169)
            ("\\(%%\\)"                    #Xe16a)
           ;; ("\\(x\\)"                   #Xe16b) This ended up being hard to do properly so i'm leaving it out.
            ("[^:=]\\(:\\)[^:=]"           #Xe16c)
            ("[^\\+<>]\\(\\+\\)[^\\+<>]"   #Xe16d)
            ("[^\\*/<>]\\(\\*\\)[^\\*/<>]" #Xe16f))))

(defun add-fira-code-symbol-keywords ()
  (font-lock-add-keywords nil fira-code-font-lock-keywords-alist))

;; (add-hook 'prog-mode-hook
;;           #'add-fira-code-symbol-keywords)


;; Languages
;;----------------------------------------------------------------------------

(use-package toml-mode
   :straight t)

;; lsp-mode

(use-package lsp-mode
  :demand t
  :straight t
  :init (setq lsp-document-sync-method ''full
              lsp-inhibit-message t
              ;; lsp-print-io t
              lsp-hover-text-function 'lsp--text-document-signature-help))

(use-package lsp-imenu
  :after lsp-mode
  :hook ((lsp-after-open . lsp-enable-imenu)))

(use-package lsp-ui
  :after lsp-mode
  :straight t
  :hook ((lsp-mode . lsp-ui-mode))
  :init
  (setq lsp-ui-doc-position 'at-point
        lsp-ui-sideline-update-mode 'point
        lsp-ui-sideline-delay 1
        lsp-ui-sideline-ignore-duplicate t
        lsp-ui-doc-header t
        lsp-ui-doc-include-signature t
        lsp-ui-peek-always-show t)
  :config
  (define-key lsp-ui-mode-map [remap xref-find-definitions]
    #'lsp-ui-peek-find-definitions)
  (define-key lsp-ui-mode-map [remap xref-find-references]
    #'lsp-ui-peek-find-references))

(use-package company-lsp
  :defer t
  :after lsp-mode
  :straight t
  :init
  (setq company-lsp-async t
        company-lsp-enable-recompletion t
        company-lsp-enable-snippet nil
        company-lsp-cache-candidates nil))

;; eglot

;; (straight-register-package
;;  '(jsonrpc :repo "https://github.com/nasyxx/temp-jsonrpc.el.git"
;;            :files ("jsonrpc.el")))

;; (use-package eglot
;;   :defer t
;;   :straight t)

;; python

(use-package python
  ;; :straight python-mode
  :commands python-mode
  :mode ("\\.py\\'" . python-mode)
  :interpreter (("python" . python-mode)
                ("python3" . python-mode))
  :preface
  (lsp-define-stdio-client lsp-python "python3"
                           #'projectile-project-root
                           '("pyls"))
  :hook ((python-mode . lsp-python-enable)
         (python-mode . (lambda () (setq lsp-ui-flycheck-enable nil
                                    lsp-ui-sideline-enable nil)))
         (python-mode . (lambda () (nasy:local-push-company-backend 'company-lsp)))
         (python-mode . (lambda () (nasy:local-push-company-backend '(company-dabbrev-code
                                                                      company-gtags
                                                                      company-etags
                                                                      company-keywords)))))
  :init (setq-default python-indent-offset 4
                      indent-tabs-mode nil
                      python-indent-guess-indent-offset nil
                      python-shell-completion-native-enable nil
                      python-shell-interpreter "ipython3"
                      python-shell-interpreter-args "-i --simple-prompt --classic"
                      py-ipython-command-args "-i --simple-prompt --classic"
                      py-python-command "python3"
                      flycheck-python-pycompile-executable "python3"
                      python-mode-modeline-display "Python"
                      python-skeleton-autoinsert t))


;; (use-package anaconda-mode
;;   :straight t
;;   :hook ((python-mode . anaconda-mode)
;;          (python-mode . anaconda-eldoc-mode)))

;; (use-package company-anaconda
;;   :straight t
;;   :hook ((python-mode . (lambda () (nasy:local-push-company-backend 'company-anaconda)))
;;          (python-mode . (lambda () (nasy:local-push-company-backend '(company-dabbrev-code
;;                                                                  company-gtags
;;                                                                  company-etags
;;                                                                  company-keywords))))))

;; (use-package elpy
;;   :demand t
;;   :after python
;;   :straight t
;;   :init (elpy-enable)
;;   (setq elpy-rpc-backend "jedi"
;;         elpy-rpc-python-command "python3")
;;   :hook ((python-mode . elpy-mode)
;;          (elpy-mode . (lambda () (setq elpy-modules (delq 'elpy-module-flymake elpy-modules))))))

;; disable due to lsp-mode
;; (use-package flycheck-pyflakes
;;   :after flycheck
;;   :straight t)


(use-package blacken
  :straight t
  :hook ((python-mode . blacken-mode)))


(use-package py-isort
  :straight t
  :hook (before-save . py-isort-before-save))


;; haskell

(use-package lsp-haskell
  :straight t
  :hook ((haskell-mode . lsp-haskell-enable)))


;; lisp

(use-package lisp-mode
  :preface
  (defun eval-last-sexp-or-region (prefix)
    "Eval region from BEG to END if active, otherwise the last sexp."
    (interactive "P")
    (if (and (mark) (use-region-p))
        (eval-region (min (point) (mark)) (max (point) (mark)))
      (pp-eval-last-sexp prefix)))
  :bind (("<remap> <eval-expression>" . pp-eval-expression)
         :map emacs-lisp-mode-map
         ("C-x C-e" . eval-last-sexp-or-region)))

(use-package highlight-quoted
  :defer t
  :straight t
  :hook ((emacs-lisp-mode . highlight-quoted-mode)))

;; markdown

(use-package markdown-mode
  :defer t
  :straight t
  :mode ("INSTALL\\'"
         "CONTRIBUTORS\\'"
         "LICENSE\\'"
         "README\\'"
         "\\.markdown\\'"
         "\\.md\\'"))


;; Org-mode
;;----------------------------------------------------------------------------


(use-package grab-mac-link
  :defer t
  :straight t)

(use-package org-cliplink
  :defer t
  :straight t)


(use-package org
  :straight t
  :bind (("C-c l" . org-store-link)
         ("C-c a" . org-agenda)))

(use-package org-clock
  :after org
  :preface
  (defun show-org-clock-in-header-line ()
    "Show the clocked-in task in header line"
    (setq-default header-line-format '((" " org-mode-line-string ""))))

  (defun hide-org-clock-from-header-line ()
    "Hide the clocked-in task from header line"
    (setq-default header-line-format nil))
  :init
  (setq org-clock-persist t)
  (setq org-clock-in-resume t)
  ;; Save clock data and notes in the LOGBOOK drawer
  (setq org-clock-into-drawer t)
  ;; Save state changes in the LOGBOOK drawer
  (setq org-log-into-drawer t)
  ;; Removes clocked tasks with 0:00 duration
  (setq org-clock-out-remove-zero-time-clocks t)
  ;; Show clock sums as hours and minutes, not "n days" etc.
  (setq org-time-clocksum-format
        '(:hours "%d" :require-hours t :minutes ":%02d" :require-minutes t))
  :hook ((org-clock-in . show-org-clock-in-header-line)
         ((org-clock-out . org-clock-cancel) . hide-org-clock-from-header))
  :bind (:map org-clock-mode-line-map
             ([header-line mouse-2] . org-clock-goto)
             ([header-line mouse-1] . org-clock-menu))
  :config
  (when (and *is-a-mac* (file-directory-p "/Applications/org-clock-statusbar.app"))
    (add-hook 'org-clock-in-hook
              (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                  (concat "tell application \"org-clock-statusbar\" to clock in \""
                                          org-clock-current-task "\""))))
    (add-hook 'org-clock-out-hook
              (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                  "tell application \"org-clock-statusbar\" to clock out")))))

(use-package org-pomodoro
  :straight t
  :after org-agenda
  :init (setq org-pomodoro-keep-killed-pomodoro-time t)
  :bind (:map org-agenda-mode-map
              ("P" . org-pomodoro)))

(use-package org-wc
  :straight t)


(use-package ob-ditaa
  :after org
  :preface
  (defun grab-ditaa (url jar-name)
    "Download URL and extract JAR-NAME as `org-ditaa-jar-path'."
    (message "Grabbing " jar-name " for org.")
    (let ((zip-temp (make-temp-name "emacs-ditaa")))
      (unwind-protect
          (progn
            (when (executable-find "unzip")
              (url-copy-file url zip-temp)
              (shell-command (concat "unzip -p " (shell-quote-argument zip-temp)
                                     " " (shell-quote-argument jar-name) " > "
                                     (shell-quote-argument org-ditaa-jar-path)))))
        (when (file-exists-p zip-temp)
          (delete-file zip-temp)))))
  :config (unless (and (boundp 'org-ditaa-jar-path)
                       (file-exists-p org-ditaa-jar-path))
            (let ((jar-name "ditaa0_9.jar")
                  (url "http://jaist.dl.sourceforge.net/project/ditaa/ditaa/0.9/ditaa0_9.zip"))
              (setq org-ditaa-jar-path (expand-file-name jar-name (file-name-directory user-init-file)))
              (unless (file-exists-p org-ditaa-jar-path)
                (grab-ditaa url jar-name)))))


(use-package ob-plantuml
  :after org
  :config (let ((jar-name "plantuml.jar")
                (url "http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar"))
            (setq org-plantuml-jar-path (expand-file-name jar-name (file-name-directory user-init-file)))
            (unless (file-exists-p org-plantuml-jar-path)
              (url-copy-file url org-plantuml-jar-path))))


(use-package org-agenda
  :after org
  :init (setq-default org-agenda-clockreport-parameter-plist '(:link t :maxlevel 3))
  :hook ((org-agenda-mode . (lambda () (add-hook 'window-configuration-change-hook 'org-agenda-align-tags nil t)))
         (org-agenda-mode . hl-line-mode))
  :config (add-to-list 'org-agenda-after-show-hook 'org-show-entry)
  (let ((active-project-match "-INBOX/PROJECT"))

    (setq org-stuck-projects
          `(,active-project-match ("NEXT")))

    (setq org-agenda-compact-blocks t
          org-agenda-sticky t
          org-agenda-start-on-weekday nil
          org-agenda-span 'day
          org-agenda-include-diary nil
          org-agenda-sorting-strategy
          '((agenda habit-down time-up user-defined-up effort-up category-keep)
            (todo category-up effort-up)
            (tags category-up effort-up)
            (search category-up))
          org-agenda-window-setup 'current-window
          org-agenda-custom-commands
          `(("N" "Notes" tags "NOTE"
             ((org-agenda-overriding-header "Notes")
              (org-tags-match-list-sublevels t)))
            ("g" "GTD"
             ((agenda "" nil)
              (tags "INBOX"
                    ((org-agenda-overriding-header "Inbox")
                     (org-tags-match-list-sublevels nil)))
              (stuck ""
                     ((org-agenda-overriding-header "Stuck Projects")
                      (org-agenda-tags-todo-honor-ignore-options t)
                      (org-tags-match-list-sublevels t)
                      (org-agenda-todo-ignore-scheduled 'future)))
              (tags-todo "-INBOX"
                         ((org-agenda-overriding-header "Next Actions")
                          (org-agenda-tags-todo-honor-ignore-options t)
                          (org-agenda-todo-ignore-scheduled 'future)
                          (org-agenda-skip-function
                           '(lambda ()
                              (or (org-agenda-skip-subtree-if 'todo '("HOLD" "WAITING"))
                                  (org-agenda-skip-entry-if 'nottodo '("NEXT")))))
                          (org-tags-match-list-sublevels t)
                          (org-agenda-sorting-strategy
                           '(todo-state-down effort-up category-keep))))
              (tags-todo ,active-project-match
                         ((org-agenda-overriding-header "Projects")
                          (org-tags-match-list-sublevels t)
                          (org-agenda-sorting-strategy
                           '(category-keep))))
              (tags-todo "-INBOX/-NEXT"
                         ((org-agenda-overriding-header "Orphaned Tasks")
                          (org-agenda-tags-todo-honor-ignore-options t)
                          (org-agenda-todo-ignore-scheduled 'future)
                          (org-agenda-skip-function
                           '(lambda ()
                              (or (org-agenda-skip-subtree-if 'todo '("PROJECT" "HOLD" "WAITING" "DELEGATED"))
                                  (org-agenda-skip-subtree-if 'nottododo '("TODO")))))
                          (org-tags-match-list-sublevels t)
                          (org-agenda-sorting-strategy
                           '(category-keep))))
              (tags-todo "/WAITING"
                         ((org-agenda-overriding-header "Waiting")
                          (org-agenda-tags-todo-honor-ignore-options t)
                          (org-agenda-todo-ignore-scheduled 'future)
                          (org-agenda-sorting-strategy
                           '(category-keep))))
              (tags-todo "/DELEGATED"
                         ((org-agenda-overriding-header "Delegated")
                          (org-agenda-tags-todo-honor-ignore-options t)
                          (org-agenda-todo-ignore-scheduled 'future)
                          (org-agenda-sorting-strategy
                           '(category-keep))))
              (tags-todo "-INBOX"
                         ((org-agenda-overriding-header "On Hold")
                          (org-agenda-skip-function
                           '(lambda ()
                              (or (org-agenda-skip-subtree-if 'todo '("WAITING"))
                                  (org-agenda-skip-entry-if 'nottodo '("HOLD")))))
                          (org-tags-match-list-sublevels nil)
                          (org-agenda-sorting-strategy
                           '(category-keep))))))))))

(use-package org-bullets
  :after org
  :straight t
  :hook ((org-mode . (lambda () (org-bullets-mode 1)))))

(use-package org
  :preface
  (defadvice org-refile (after save-all-after-refile activate)
    "Save all org buffers after each refile operation."
    (org-save-all-org-buffers))

  ;; Exclude DONE state tasks from refile targets
  (defun verify-refile-target ()
    "Exclude todo keywords with a done state from refile targets."
    (not (member (nth 2 (org-heading-components)) org-done-keywords)))
  (setq org-refile-target-verify-function 'verify-refile-target)

  (defun org-refile-anywhere (&optional goto default-buffer rfloc msg)
    "A version of `org-refile' which allows refiling to any subtree."
    (interactive "P")
    (let ((org-refile-target-verify-function))
      (org-refile goto default-buffer rfloc msg)))

  (defun org-agenda-refile-anywhere (&optional goto rfloc no-update)
    "A version of `org-agenda-refile' which allows refiling to any subtree."
    (interactive "P")
    (let ((org-refile-target-verify-function))
      (org-agenda-refile goto rfloc no-update)))

  :bind (:map org-mode-map
              ("C-M-<up>" . org-up-element)
              ("M-h" . nil)
              ("C-c g" . org-mac-grab-link))
  :init
  (setq
   org-archive-mark-done nil
   org-archive-location "%s_archive::* Archive"
   org-archive-mark-done nil
   org-catch-invisible-edits 'show
   org-edit-timestamp-down-means-later t
   org-export-coding-system 'utf-8
   org-export-kill-product-buffer-when-displayed t
   org-fast-tag-selection-single-key 'expert
   org-hide-emphasis-markers t
   org-hide-leading-stars nil
   org-html-with-latex (quote mathjax)
   org-html-validation-link nil
   org-indent-mode-turns-on-hiding-stars nil
   org-support-shift-select t
   org-refile-use-cache nil
   org-refile-targets '((nil :maxlevel . 5) (org-agenda-files :maxlevel . 5))
   org-refile-use-outline-path t
   org-outline-path-complete-in-steps nil
   org-refile-allow-creating-parent-nodes 'confirm
   ;; to-do settings
   org-todo-keywords (quote ((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!/!)")
                             (sequence "PROJECT(p)" "|" "DONE(d!/!)" "CANCELLED(c@/!)")
                             (sequence "WAITING(w@/!)" "DELEGATED(e!)" "HOLD(h)" "|" "CANCELLED(c@/!)")))
   org-todo-repeat-to-state "NEXT"
   org-todo-keyword-faces (quote (("NEXT" :inherit warning)
                                  ("PROJECT" :inherit font-lock-string-face)))

   ;; org latex
   org-latex-compiler "lualatex"
   org-latex-default-packages-alist
   (quote
    (("AUTO" "inputenc" t
      ("pdflatex"))
     ("T1" "fontenc" t
      ("pdflatex"))
     ("" "graphicx" t nil)
     ("" "grffile" t nil)
     ("" "longtable" t nil)
     ("" "wrapfig" nil nil)
     ("" "rotating" nil nil)
     ("normalem" "ulem" t nil)
     ("" "amsmath" t nil)
     ("" "textcomp" t nil)
     ("" "amssymb" t nil)
     ("" "capt-of" nil nil)
     ("colorlinks,linkcolor=blue,anchorcolor=blue,citecolor=green,filecolor=black,urlcolor=blue"
      "hyperref" t nil)
     ("" "luatexja-fontspec" t nil)
     ("" "listings" t nil)))
   org-latex-default-table-environment "longtable"
   org-latex-listings t
   org-latex-listings-langs
   (quote
    ((emacs-lisp "Lisp")
     (lisp "Lisp")
     (clojure "Lisp")
     (c "C")
     (cc "C++")
     (fortran "fortran")
     (perl "Perl")
     (cperl "Perl")
     (Python "python")
     (python "Python")
     (ruby "Ruby")
     (html "HTML")
     (xml "XML")
     (tex "TeX")
     (latex "[LaTeX]TeX")
     (sh "bash")
     (shell-script "bash")
     (gnuplot "Gnuplot")
     (ocaml "Caml")
     (caml "Caml")
     (sql "SQL")
     (sqlite "sql")
     (makefile "make")
     (R "r")))
   org-latex-pdf-process
   (quote
    ("lualatex -shell-escape -interaction nonstopmode %f"
     "lualatex -shell-escape -interaction nonstopmode %f"))
   org-latex-tables-booktabs t
   org-level-color-stars-only nil
   org-list-indent-offset 2
   org-log-done t
   org-refile-use-outline-path t
   org-startup-indented t
   org-startup-folded (quote content)
   org-startup-truncated nil
   org-tags-column 80)
  :hook ((org-mode-hook . auto-fill-mode))
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   `((R . t)
     (ditaa . t)
     (dot . t)
     (emacs-lisp . t)
     (gnuplot . t)
     (haskell . nil)
     (latex . t)
     (ledger . t)
     (ocaml . nil)
     (octave . t)
     (plantuml . t)
     (python . t)
     (ruby . t)
     (screen . nil)
     (,(if (locate-library "ob-sh") 'sh 'shell) . t)
     (sql . nil)
     (sqlite . t)))
  (setq luamagick
      '(luamagick
        :programs ("lualatex" "convert")
        :description "pdf > png"
        :message "you need to install lualatex and imagemagick."
        :use-xcolor t
        :image-input-type "pdf"
        :image-output-type "png"
        :image-size-adjust (1.0 . 1.0)
        :latex-compiler ("lualatex -interaction nonstopmode -output-directory %o %f")
        :image-converter ("convert -density %D -trim -antialias %f -quality 100 %O")))
  (add-to-list 'org-preview-latex-process-alist luamagick)
  (setq luasvg
      '(luasvg
        :programs ("lualatex" "dvisvgm")
        :description "dvi > svg"
        :message "you need to install lualatex and dvisvgm."
        :use-xcolor t
        :image-input-type "dvi"
        :image-output-type "svg"
        :image-size-adjust (1.7 . 1.5)
        :latex-compiler ("lualatex -interaction nonstopmode -output-format dvi -output-directory %o %f")
        :image-converter ("dvisvgm %f -n -b min -c %S -o %O")))
  (add-to-list 'org-preview-latex-process-alist luasvg)
  (setq org-preview-latex-default-process 'luasvg))


(use-package writeroom-mode
  :defer t
  :straight t
  :init
  (define-minor-mode prose-mode
    "Set up a buffer for prose editing.
This enables or modifies a number of settings so that the
experience of editing prose is a little more like that of a
typical word processor."
    nil " Prose" nil
    (if prose-mode
        (progn
          (when (fboundp 'writeroom-mode)
            (writeroom-mode 1))
          (setq truncate-lines nil)
          (setq word-wrap t)
          (setq cursor-type 'bar)
          (when (eq major-mode 'org)
            (kill-local-variable 'buffer-face-mode-face))
          (buffer-face-mode 1)
          ;;(delete-selection-mode 1)
          (set (make-local-variable 'blink-cursor-interval) 0.6)
          (set (make-local-variable 'show-trailing-whitespace) nil)
          (set (make-local-variable 'line-spacing) 0.2)
          (set (make-local-variable 'electric-pair-mode) nil)
          (ignore-errors (flyspell-mode 1))
          (visual-line-mode 1))
      (kill-local-variable 'truncate-lines)
      (kill-local-variable 'word-wrap)
      (kill-local-variable 'cursor-type)
      (kill-local-variable 'show-trailing-whitespace)
      (kill-local-variable 'line-spacing)
      (kill-local-variable 'electric-pair-mode)
      (buffer-face-mode -1)
      ;; (delete-selection-mode -1)
      (flyspell-mode -1)
      (visual-line-mode -1)
      (when (fboundp 'writeroom-mode)
        (writeroom-mode 0)))))


(use-package pdf-tools
  :straight t
  :config
  (setq-default pdf-view-display-size 'fit-width)
  (bind-keys :map pdf-view-mode-map
             ("\\" . hydra-pdftools/body)
             ("<s-spc>" .  pdf-view-scroll-down-or-next-page)
             ("g"  . pdf-view-first-page)
             ("G"  . pdf-view-last-page)
             ("l"  . image-forward-hscroll)
             ("h"  . image-backward-hscroll)
             ("j"  . pdf-view-next-page)
             ("k"  . pdf-view-previous-page)
             ("e"  . pdf-view-goto-page)
             ("u"  . pdf-view-revert-buffer)
             ("al" . pdf-annot-list-annotations)
             ("ad" . pdf-annot-delete)
             ("aa" . pdf-annot-attachment-dired)
             ("am" . pdf-annot-add-markup-annotation)
             ("at" . pdf-annot-add-text-annotation)
             ("y"  . pdf-view-kill-ring-save)
             ("i"  . pdf-misc-display-metadata)
             ("s"  . pdf-occur)
             ("b"  . pdf-view-set-slice-from-bounding-box)
             ("r"  . pdf-view-reset-slice)))

(use-package org-pdfview
  :after pdf-tools
  :straight t)

(use-package toc-org
  :straight t
  :hook ((org-mode . org-toc-enable)))

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


(use-package nyan-mode
  :demand t
  :straight t
  :init (setq nyan-animate-nyancat t
              nyan-bar-length 16
              nyan-wavy-trail t)
  :config (nyan-mode 1))


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
  (spaceline-helm-mode 1)
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
    (format-time-string "%b %d, %Y - %H:%M ")
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
               ((string-match "⚠" text) `(:height 0.9 :background ,(face-attribute 'spaceline-flycheck-warning :foreground)))
               ((string-match "✖ [0-9]" text) `(:height 0.9 :background ,(face-attribute 'spaceline-flycheck-error :foreground)))
               ((string-match "✖ Disabled" text) `(:height 0.9 :background ,(face-attribute 'font-lock-comment-face :foreground)))
               (t '(:height 0.9 :inherit)))))
      (propertize (format " %s " text)
                  'face f
                  'help-echo "Show Flycheck Errors"
                  'mouse-face '(:box 1)
                  'local-map (make-mode-line-mouse-map 'mouse-1 (lambda () (interactive) (flycheck-list-errors)))))
    :when active)

  (add-hook
   'after-init-hook
   (lambda () (spaceline-compile
           `(((buffer-modified major-mode buffer-size) :face highlight-face)
             (anzu)
             ((nasy:version-control projectile-root) :separator " in ")
             (buffer-id)
             ((flycheck-status (flycheck-error flycheck-warning flycheck-info)) :face powerline-active0 :when active)
             ((flycheck-status (flycheck-error flycheck-warning flycheck-info)) :face mode-line-inactive :when (not active))
             (selection-info :face powerline-active0 :when active)
             (nyan-cat :tight t :face mode-line-inactive))
           `((which-function)
             (global :when active)
             (line-column :face powerline-active0 :when active)
             (line-column :when (not active))
             ;; (minor-modes)
             (buffer-position
              hud)
             (nasy-time :face spaceline-modified :when active)
             (nasy-time :when (not active)))))))


(use-package doom-themes
  :demand t
  :straight t
  :init
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t)
  :config
  (load-theme 'doom-dracula t)
  (doom-themes-treemacs-config)
  (doom-themes-visual-bell-config)
  (doom-themes-org-config))

;; custom file
;;----------------------------------------------------------------------------

(when (file-exists-p custom-file)
  (load custom-file))

(add-hook 'after-init-hook #'benchmark-init/deactivate)

;;; init.el ends here
