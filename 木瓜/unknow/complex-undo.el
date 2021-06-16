;;; complex-undo.el --- Complex Undo (local history)  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Nasy

;; Author: Nasy <nasyxx@gmail.com>
;; Keywords: tools

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

;; I found the challenge interesting, so I implemented my version of it.

;; My solution takes a snapshot of changes regularly (when the user is idle for
;; a short while) during editing and adds description to them, listing the
;; commands used for editing.  This helps finding the relevant change if you want
;; to revert a flush line or query replace or similar operation done earlier.

;; You can browse your changes with description and timestamp, so it's a kind of
;; local history for your file, showing the editing commands used and the diffs
;; of the changes.  The diffs are in a diff buffer, so you can use regular Emacs
;; operations to apply/revert hunks.

;; Here's a demo: https://i.imgur.com/veJFXH6.gif

;; The code: https://pastebin.com/hnzN45sx

;;; Code:



(provide 'complex-undo)
;;; complex-undo.el ends here

(require 'cl-lib)
(require 'diff)

(defvar complex-undo-minimum-change-length 20
  "Minimum change length of complex-undo.
Changes with less than this many characters are ignored to avoid having too many
little undos stored.")


(defvar complex-undo-max-stored-diffs 50
  "Number of complex undos stored for a file.")

(defvar complex-undo-max-file-size 100000
  "Max file size of complex-undo.
Do not store undos for files bigger than this to avoid unnecessarily processing
large data files, for example.")

;; idle delay in seconds, before putting new undos into to the history
;; list, so that undo processing does not interfere with typing. you
;; do not need older undos instantly anyway, for instant undo of the
;; last operation you use regular Emacs undo as usual.
(defvar complex-undo-process-delay 2)

;; do not show the names of these trivial commands in undo history
;; descriptors
(defvar complex-undo-ignore-commands '(self-insert-command
                                       delete-char
                                       backward-char
                                       delete-backward-char
                                       backward-delete-char
                                       backward-delete-char-untabify
                                       kill-word
                                       backward-kill-word
                                       undo
                                       newline
                                       dabbrev-expand))


(make-variable-buffer-local 'complex-undo-buffer-tick)
(make-variable-buffer-local 'complex-undo-buffer-undo-state)
(make-variable-buffer-local 'complex-undo-unprocessed)
(make-variable-buffer-local 'complex-undo-items)


(defun complex-undo-store-current-state ()
  (setq complex-undo-buffer-tick (buffer-chars-modified-tick))
  (setq complex-undo-buffer-undo-state buffer-undo-list)
  (setq complex-undo-unprocessed nil))



(defun complex-undo-post-command ()
  (unless (eq complex-undo-buffer-tick
              (buffer-chars-modified-tick))
    (push real-this-command complex-undo-unprocessed)
    (setq complex-undo-buffer-tick (buffer-chars-modified-tick))))


(defun complex-undo-process-changes ()
  (when complex-undo-unprocessed
    (if (catch 'exitloop                 ;; only consider non-trivial changes
          (let ((undos buffer-undo-list)
                (count 0))
            (while (and undos
                        (not (eq undos complex-undo-buffer-undo-state)))
              (let ((undo (pop undos)))
                (when (listp undo)
                  (if (stringp (car undo))   ;; deleted text
                      (incf count (length (car undo)))

                    (if (numberp (car undo)) ;; inserted text
                        (incf count (- (cdr undo) (car undo)))))

                  (if (>= count complex-undo-minimum-change-length)
                      (throw 'exitloop t))))))
          nil)

        (let ((oldbuf (generate-new-buffer "undo"))
              (newbuf (current-buffer))
              (filename (buffer-file-name))
              (command (string-join
                        (delete-dups
                         (mapcar
                          (lambda (command)
                            (if (symbolp command)
                                (if (member command complex-undo-ignore-commands)
                                    "small commands"
                                  (symbol-name command))))
                          (reverse complex-undo-unprocessed)))
                        ", ")))


          (let ((text (buffer-string))
                (undo buffer-undo-list)
                (oldundo complex-undo-buffer-undo-state))
            (with-current-buffer oldbuf
              (insert text)
              (let (filtered-undo)
                (while (and undo
                            (not (eq undo oldundo)))
                  (unless (and (listp (car undo))
                               ;; skip marker movements which refer to the old
                               ;; buffer, so they are not useful here
                               (markerp (caar undo)))
                    (push (car undo) filtered-undo))
                  (setq undo (cdr undo)))
                (primitive-undo (length filtered-undo) (reverse filtered-undo)))))

          (let ((diff (with-temp-buffer
                        (diff-no-select oldbuf newbuf
                                        nil t (current-buffer))
                        (buffer-string))))
            (push (list 'diff (replace-regexp-in-string
                               (format "#<buffer %s>"
                                       (buffer-name newbuf))
                               filename
                               diff)
                        'command command
                        'time (format-time-string "%Y-%m-%d %H:%M"))
                  complex-undo-items)

            (kill-buffer oldbuf)

            (if (> (length complex-undo-items)
                   complex-undo-max-stored-diffs)
                (setq complex-undo-items
                      (butlast complex-undo-items))))))

    (complex-undo-store-current-state)))


(defun complex-undo-show-diffs ()
  (interactive)
  (unless complex-undo-items
    (if (buffer-file-name)
        (error "no stored undo diffs for this file")

      (error "Undo for buffers without an associated file is currently not supported. The file does not have to be saved, but the buffer has to have an associated file. If the buffer is opened with find-file then it has a file associated.")))

  (setq complex-undo-previous-window-cfg
        (current-window-configuration))

  (let ((items complex-undo-items)
        (file (buffer-file-name)))
    (pop-to-buffer "*undo diffs")
    (erase-buffer)
    (insert (propertize (concat " Undo items for file " file)
                        'face 'tool-bar)
         "\n\n")
    (save-excursion
      (dolist (item items)
        (insert (propertize (plist-get item 'time)
                            'face 'line-number)
                "   "
                (propertize (plist-get item 'command)
                            'face 'font-lock-function-name-face))
        (put-text-property (line-beginning-position)
                           (1+ (line-beginning-position))
                           'complex-undo-data
                           item)
        (insert "\n")))

    (local-set-key "q" (lambda ()
                         (interactive)
                         (set-window-configuration complex-undo-previous-window-cfg)))
    (local-set-key (kbd "<return>")
                   (lambda ()
                     (interactive)
                     (pop-to-buffer "*undo diff*")))

    (add-hook 'post-command-hook  'complex-undo-show-diff nil t)
    (setq complex-undo-diffs-current-line nil)))


(defun complex-undo-show-diff ()
  (interactive)
  (if (and (not (eq complex-undo-diffs-current-line (line-number-at-pos)))
           (sit-for 0.3))
      (let ((data (get-text-property (line-beginning-position) 'complex-undo-data)))
        (if data
            (save-selected-window
              (pop-to-buffer "*undo diff*")
              (let ((inhibit-read-only t))
                (erase-buffer)
                (unless (eq major-mode 'diff-mode)
                  (diff-mode))
                (save-excursion
                  (insert (plist-get data 'diff))))
              (read-only-mode 1)))

        (setq complex-undo-diffs-current-line (line-number-at-pos)))))


(define-minor-mode complex-undo-mode
  "Complex undo."
  :lighter " CU"

  (if complex-undo-mode
      (progn
        (if (> (buffer-size) complex-undo-max-file-size)
            (progn
              (setq complex-undo-mode nil)
              (message "File size is over the limit for complex undo."))

          (add-hook 'post-command-hook  'complex-undo-post-command nil t)
          (complex-undo-store-current-state)))

    (remove-hook 'post-command-hook  'complex-undo-post-command t)))


(run-with-idle-timer complex-undo-process-delay t 'complex-undo-process-changes)


(provide 'complex-undo)
;;; complex-undo.el ends here
