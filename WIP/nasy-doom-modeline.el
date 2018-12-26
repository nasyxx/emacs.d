(use-package powerline
  :straight t)

(use-package minions
  :straight t
  :hook ((after-init . minions-mode)))

(use-package doom-modeline
  :straight t
  :init (setq
         doom-modeline-minor-modes            t
         doom-modeline-height                 25
         doom-modeline-bar-width              13
         doom-modeline-buffer-file-name-style 'relative-from-project
         doom-modeline-python-executable      "python3"
         doom-modeline-enable-word-count      t
         doom-modeline-github                 t)
  :config
  (doom-modeline-def-segment nasy:major-mode
    "An `all-the-icons' segment indicating the current buffer's mode with an icon"
    (let ((icon (all-the-icons-icon-for-mode major-mode)))
      (if (not (symbolp icon))
          (propertize (format "%s" icon)
                      `face (when (doom-modeline--active)
                              `(:family ,(all-the-icons-icon-family-for-mode major-mode) :background "#6c567b" :inherit))
                      'help-echo (format "Major-mode: `%s'" major-mode)
                      'display '(raise -0.1))
        (propertize (format "%s " major-mode)
                    `face (when (doom-modeline--active)
                            `(:background "#6c567b" :inherit))
                    'help-echo (format "Major-mode: `%s'" major-mode)
                    'display '(raise -0.1)))))

  (doom-modeline-def-segment nasy:buffer-info
    "Combined information about the current buffer, including the current working
  directory, the file name, and its state (modified, read-only or non-existent)."
    (let ((active (doom-modeline--active)))
      (concat
       ;; major mode icon
       (when (and doom-modeline-icon doom-modeline-major-mode-icon)
         (when-let ((icon (or doom-modeline--buffer-file-icon
                              (doom-modeline-update-buffer-file-icon))))
           (concat
            (if (and active doom-modeline-major-mode-color-icon)
                (propertize icon 'face `(:background "#c06c84" :inherit))
              (propertize icon
                          'face `(:height 1.1 :family ,(all-the-icons-icon-family icon) :inherit)))
            doom-modeline-vspc)))

       ;; state icon
       (when doom-modeline-icon
         (when-let ((icon (or doom-modeline--buffer-file-state-icon
                              (doom-modeline-update-buffer-file-state-icon))))
           (concat
            (if active
                (propertize icon 'face `(:background "#c06c84" :inherit))
              (propertize icon
                          'face `(:height 1.2 :family ,(all-the-icons-icon-family icon) :inherit)))
            doom-modeline-vspc)))

       ;; buffer file name
       (let ((name (or doom-modeline--buffer-file-name
                       (doom-modeline-update-buffer-file-name))))
         (if active
             (propertize name 'face `(:background "#c06c84" :inherit))
           (propertize name 'face 'mode-line-inactive))))))

  (doom-modeline-def-segment nasy:vc
    "Version control information."
    (when vc-mode
      (let ((branch (mapconcat 'concat (cdr (split-string vc-mode "[:-]")) "-"))
            (status (when (buffer-file-name)
                      (pcase (vc-state (buffer-file-name))
                        (`up-to-date " ✓")
                        (`edited " ❓")
                        (`added " ➕")
                        (`unregistered " ■")
                        (`removed " ✘")
                        (`needs-merge " ↓")
                        (`needs-update " ↑")
                        (`ignored " ✦")
                        (_ " ⁇")))))
        (propertize (concat "  " branch status)
                    'face (cond
                           ((string-match " ✓" status) `(:foreground "#a1de93"))
                           ((string-match " ❓" status) `(:foreground "#fdffba"))
                           ((string-match " ➕" status) `(:foreground "#ffeab6"))
                           ((string-match " [✘⁇]" status) `(:foreground "#f69d9d"))
                           (t `(:foreground "#ffffff")))))))

  (doom-modeline-def-segment nasy:selection-info
    "Information about the current selection, such as how many characters and
  lines are selected, or the NxM dimensions of a block selection."
    (when (and (or mark-active (and (bound-and-true-p evil-local-mode)
                                    (eq evil-state 'visual)))
               (doom-modeline--active))
      (cl-destructuring-bind (beg . end)
          (if (and (bound-and-true-p evil-local-mode) (eq evil-state 'visual))
              (cons evil-visual-beginning evil-visual-end)
            (cons (region-beginning) (region-end)))
        (propertize
         (let ((lines (count-lines beg (min end (point-max)))))
           (concat (cond ((or (bound-and-true-p rectangle-mark-mode)
                              (and (bound-and-true-p evil-visual-selection)
                                   (eq 'block evil-visual-selection)))
                          (let ((cols (abs (- (doom-modeline-column end)
                                              (doom-modeline-column beg)))))
                            (format "%dx%dB" lines cols)))
                         ((and (bound-and-true-p evil-visual-selection)
                               (eq evil-visual-selection 'line))
                          (format "%dL" lines))
                         ((> lines 1)
                          (format " %dC dL " (- end beg) lines))
                         ((format " %dC " (- end beg))))
                   (when doom-modeline-enable-word-count
                     (format "%dW " (count-words beg end)))))
         'face `(:foreground "#f5ffcb" :background "#015051")))))

  (defun spaceline--pdfview-page-number ()
    "The current `pdf-view-mode' page number to display in the mode-line.
  Return a formated string containing the current and last page number for the
  currently displayed pdf file in `pdf-view-mode'."
    (format "(%d/%d)"
            ;; `pdf-view-current-page' is a macro in an optional dependency
            ;; any better solutions?
            (eval `(pdf-view-current-page))
            (pdf-cache-number-of-pages)))

  (doom-modeline-def-segment line-column
    "The current line and column numbers, or `(current page/number of pages)`
  in pdf-view mode (enabled by the `pdf-tools' package)."
    (if (eq major-mode 'pdf-view-mode)
        (spaceline--pdfview-page-number)
      (if (and
           (boundp 'column-number-indicator-zero-based)
           (not column-number-indicator-zero-based))
          (propertize " %l:%2C "
                      'face (when (doom-modeline--active) `(:background "#015051")))
        (propertize " %l:%2c "
                    'face (when (doom-modeline--active) `(:background "#015051"))))))

  (doom-modeline-def-segment hud
    "An `all-the-icons' segment to show the position through buffer HUD indicator."
    (let ((color (if (doom-modeline--active) "#fab95b" "#1e6262"))
          (height (frame-char-height))
          (ws (window-start))
          (we (window-end))
          pmax pmin)
      (save-restriction
        (widen)
        (setq pmax (point-max))
        (setq pmin (point-min)))
      (propertize "  "
                  'display (pl/percent-xpm height pmax pmin we ws (* (frame-char-width) 2) color nil)
                  'face (when (doom-modeline--active) `(:background "#015051")))))

  (doom-modeline-def-segment nasy:time
    "Time"
    (propertize
     (format-time-string " %b %d, %Y - %H:%M")
     'face (when (doom-modeline--active) `(:foreground "#1b335f" :background "#fab95b"))))

  (doom-modeline-def-segment nasy:separator-left
    "Separator left."
    (propertize (all-the-icons-alltheicon "wave-right")
                'face (if (doom-modeline--active)
                          `(:height 1.6 :foreground ,(face-attribute 'all-the-icons-dgreen :foreground) :background "#6c567b")
                        `(:height 1.6 :foreground "#333333"))
                'display '(raise -0.01)))
  (doom-modeline-def-segment nasy:separator-right
    "Separator left."
    (propertize (all-the-icons-alltheicon "wave-left")
                'face (if (doom-modeline--active)
                          `(:height 1.6 :foreground ,(face-attribute 'all-the-icons-dgreen :foreground) :background "#6c567b")
                        `(:height 1.6 :foreground "#333333"))
                'display '(raise -0.07)))

  (doom-modeline-def-segment nasy:separator-right-time
    "Separator right."
    (propertize (all-the-icons-alltheicon "wave-left")
                'face (if (doom-modeline--active)
                          `(:height 1.6 :foreground "#28544b" :background "#fab95b")
                        `(:height 1.6 :foreground ,(face-attribute 'all-the-icons-silver :foreground)))
                'display '(raise -0.07)))

  (doom-modeline-def-segment nasy:flycheck
    "An `all-the-icons' representaiton of `flycheck-status'"
    (when (doom-modeline--active)
      (let* ((text
              (pcase flycheck-last-status-change
                (`finished (if flycheck-current-errors
                               (let-alist (flycheck-count-errors flycheck-current-errors)
                                 (format "%s%s" (if .errors (format " %s" .errors) "") (if .warning (format " %s" .warning) "")))
                             "✔"))
                (`running     "⟲")
                (`no-checker  "❀")
                (`not-checked "✣")
                (`errored     "⚠")
                (`interrupted "⛔")
                (`suspicious  "")))
             (f (cond
                 ((string-match "[⚠❀]" text) `(:height 0.9 :foreground "#f5ffcb" :background "#1d5464"))
                 ((string-match "[] [0-9]" text) `(:height 0.9 :foreground "#333333" :background "#fa7f7f"))
                 ((string-match "✣" text) `(:height 0.9))
                 (t '(:height 0.9 :inherit)))))
        (concat
         (propertize (format " %s " text)
                     'face f
                     'help-echo "Show Flycheck Errors"
                     'mouse-face '(:box 1)
                     'local-map (make-mode-line-mouse-map 'mouse-1 (lambda () (interactive) (flycheck-list-errors))))
         (propertize (all-the-icons-alltheicon "wave-left")
                     'face (cond
                            ((string-match "❀" text) `(:height 1.6 :foreground "#015051" :background "#1d5464"))
                            ((string-match "[] [0-9]" text) `(:height 1.6 :foreground "#015051" :background "#fa7f7f"))
                            (t '(:height 1.6 :foreground "#015051")))
                     'display '(raise -0.07))))))

  (doom-modeline-def-modeline 'main
    '(nasy:separator-left nasy:major-mode nasy:separator-right workspace-number window-number god-state ryo-modal xah-fly-keys matches " " nasy:buffer-info nasy:vc remote-host nasy:selection-info)
    '(misc-info persp-name lsp github debug minor-modes process nasy:flycheck line-column hud nasy:time nasy:separator-right-time))

  (doom-modeline-def-modeline 'minimal
    '(nasy:separator-left nasy:major-mode nasy:separator-right matches " " line-column)
    '(media-info nasy:time nasy:separator-right-time))

  (doom-modeline-def-modeline 'special
    '(nasy:separator-left nasy:major-mode nasy:separator-right window-number evil-state god-state ryo-modal xah-fly-keys matches " " buffer-info nasy:selection-info)
    '(misc-info persp-name lsp debug minor-modes process nasy:flycheck line-column hud nasy:time nasy:separator-right-time))

  (doom-modeline-def-modeline 'project
    '(nasy:separator-left nasy:major-mode nasy:separator-right window-number buffer-default-directory)
    '(misc-info nasy:time nasy:separator-right-time))

  (doom-modeline-def-modeline 'media
    '(nasy:separator-left nasy:major-mode nasy:separator-right window-number " %b  ")
    '(misc-info media-info nasy:time nasy:separator-right-time))

  (doom-modeline-init))
