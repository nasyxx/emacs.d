; -*- Mode: Emacs-Lisp; -*-

;  Eric Beuscher
;  Tulane University
;  Department of Computer Science
;  flex-mode.el

(require 'derived)
;(require 'cc-mode)

(define-derived-mode flex-mode c-mode "Flex"
  "Major mode for editing flex files"

  ;; try to set the indentation correctly
  (setq-default c-basic-offset 4)
  (make-variable-buffer-local 'c-basic-offset)

  (c-set-offset 'knr-argdecl-intro 0)
  (make-variable-buffer-local 'c-offsets-alist)

  ;; remove auto and hungry anything
  (c-toggle-auto-hungry-state -1)
  (c-toggle-auto-state -1)
  (c-toggle-hungry-state -1)

  (use-local-map flex-mode-map)

  ;; get rid of that damn electric-brace which is not useful with flex
  (define-key flex-mode-map "{"         'self-insert-command)
  (define-key flex-mode-map "}"         'self-insert-command)

  (define-key flex-mode-map [tab] 'flex-indent-command)

  (setq comment-start "/*"
        comment-end "*/"))



(defalias 'flex-indent-command 'c-indent-command)

(provide 'flex-mode)
