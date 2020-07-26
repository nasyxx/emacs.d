;;; init.el --- Nasy's emacs.d init file.            -*- lexical-binding: t; -*-
;; Copyright (C) 2018  Nasy

;; Author: Nasy <nasyxx+emacs@gmail.com>

;;; Commentary:

;; Nasy's emacs.d init file.  For macOS and Emacs 26, Emacs 27.

(setq-default lexical-binding t)

(setq-default debug-on-error         t
  	    message-log-max        t
  	    load-prefer-newer      t
  	    ad-redefinition-action 'accept
  	    gc-cons-threshold      most-positive-fixnum)

(defconst *is-a-mac* (eq system-type 'darwin))

;;; Borrow from doom emacs.
(define-error 'n-error "Error in Nasy Emacs core")
(define-error 'n-hook-error "Error in a Nasy startup hook" 'Nasy-error)

(defun nasy-unquote (exp)
  "Return EXP unquoted."
  (declare (pure t) (side-effect-free t))
  (while (memq (car-safe exp) '(quote function))
    (setq exp (cadr exp)))
  exp)

(defun nasy-enlist (exp)
 "Return EXP wrapped in a list, or as-is if already a list."
 (declare (pure t) (side-effect-free t))
 (if (listp exp) exp (list exp)))

(defun nasy/try-run-hook (hook)
  "Run HOOK (a hook function), but handle errors better, to make debugging
issues easier.
Meant to be used with `run-hook-wrapped'."
  (message "Running hook: %s" hook)
  (condition-case e
      (funcall hook)
    ((debug error)
     (signal 'n-hook-error (list hook e))))
  ;; return nil so `run-hook-wrapped' won't short circuit
  nil)


;; File+dir local variables are initialized after the major mode and its hooks
;; have run. If you want hook functions to be aware of these customizations, add
;; them to MODE-local-vars-hook instead.
(defun nasy/run-local-var-hooks-h ()
  "Run MODE-local-vars-hook after local variables are initialized."
  (run-hook-wrapped (intern-soft (format "%s-local-vars-hook" major-mode))
  		  #'nasy/try-run-hook))
(add-hook 'hack-local-variables-hook #'nasy/run-local-var-hooks-h)

;; If the user has disabled `enable-local-variables', then
;; `hack-local-variables-hook' is never triggered, so we trigger it at the end
;; of `after-change-major-mode-hook':
(defun nasy/run-local-var-hooks-if-necessary-h ()
  "Run `nasy/run-local-var-hooks-h' if `enable-local-variables' is disabled."
  (unless enable-local-variables
    (nasy/run-local-var-hooks-h)))
(add-hook 'after-change-major-mode-hook
  	#'nasy/run-local-var-hooks-if-necessary-h
  	'append)

(defun nasy--resolve-hook-forms (hooks)
  "Converts a list of modes into a list of hook symbols.
If a mode is quoted, it is left as is. If the entire HOOKS list is quoted, the
list is returned as-is."
  (declare (pure t) (side-effect-free t))
  (let ((hook-list (nasy-enlist (nasy-unquote hooks))))
    (if (eq (car-safe hooks) 'quote)
      hook-list
      (cl-loop for hook in hook-list
  	     if (eq (car-safe hook) 'quote)
  	     collect (cadr hook)
  	     else collect (intern (format "%s-hook" (symbol-name hook)))))))

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

(defun nasy:insert-current-date ()
  "Insert current date."
  (interactive)
  (insert (shell-command-to-string "echo -n $(date +'%b %d, %Y')")))

(defun nasy:insert-current-filename ()
  "Insert current buffer filename."
  (interactive)
  (insert (file-relative-name buffer-file-name)))

(defun posframe-poshandler-frame-top-center (info)
  (cons (/ (- (plist-get info :parent-frame-width)
  	    (plist-get info :posframe-width))
  	 2)
      (round (* 0.02 (x-display-pixel-height)))))

;; Borrow from https://github.com/raxod502/radian/blob/bf23a07418b3d72a300b21dcdf9cb521423d9681/emacs/radian.el#L30-L49
(defmacro nasy/protect-macros (&rest body)
  "Eval BODY, protecting macros from incorrect expansion.
This macro should be used in the following situation:
Some form is being evaluated, and this form contains as a
sub-form some code that will not be evaluated immediately, but
will be evaluated later. The code uses a macro that is not
defined at the time the top-level form is evaluated, but will be
defined by time the sub-form's code is evaluated. This macro
handles its arguments in some way other than evaluating them
directly. And finally, one of the arguments of this macro could
be interpreted itself as a macro invocation, and expanding the
invocation would break the evaluation of the outer macro.
You might think this situation is such an edge case that it would
never happen, but you'd be wrong, unfortunately. In such a
situation, you must wrap at least the outer macro in this form,
but can wrap at any higher level up to the top-level form."
  (declare (indent 0))
  `(eval '(progn ,@body)))

(if (fboundp 'with-eval-after-load)
    (defalias 'after-x 'with-eval-after-load)
  (defmacro after-x (feature &rest body)
    "Eval BODY afetr FEATURE have loaded."
    (declare (indent defun))
    `(eval-after-load ,feature
       '(progn ,@body))))

(defmacro λ! (&rest body)
  "A shortcut for inline interactive lambdas."
  (declare (doc-string 1))
  `(lambda () (interactive) ,@body))

(defalias 'lambda! 'λ!)

(defmacro after! (package &rest body)
  "Evaluate BODY after PACKAGE have loaded.
PACKAGE is a symbol or list of them. These are package names, not modes,
functions or variables. It can be:
- An unquoted package symbol (the name of a package)
    (after! helm BODY...)
- An unquoted list of package symbols (i.e. BODY is evaluated once both magit
  and git-gutter have loaded)
    (after! (magit git-gutter) BODY...)
- An unquoted, nested list of compound package lists, using any combination of
  :or/:any and :and/:all
    (after! (:or package-a package-b ...)  BODY...)
    (after! (:and package-a package-b ...) BODY...)
    (after! (:and package-a (:or package-b package-c) ...) BODY...)
  Without :or/:any/:and/:all, :and/:all are implied.
This is a wrapper around `eval-after-load' that:
1. Suppresses warnings for disabled packages at compile-time
2. No-ops for package that are disabled by the user (via `package!')
3. Supports compound package statements (see below)
4. Prevents eager expansion pulling in autoloaded macros all at once"
  (declare (indent defun) (debug t))
  (if (symbolp package)
      (list (if (or (not (bound-and-true-p byte-compile-current-file))
  		  (require package nil 'noerror))
  	      #'progn
  	    #'with-no-warnings)
  	  (let ((body (macroexp-progn body)))
  	    `(if (featurep ',package)
  		 ,body
  	       ;; We intentionally avoid `with-eval-after-load' to prevent
  	       ;; eager macro expansion from pulling (or failing to pull) in
  	       ;; autoloaded macros/packages.
  	       (eval-after-load ',package ',body))))
    (let ((p (car package)))
      (cond ((not (keywordp p))
  	   `(after! (:and ,@package) ,@body))
  	  ((memq p '(:or :any))
  	   (macroexp-progn
  	    (cl-loop for next in (cdr package)
  		     collect `(after! ,next ,@body))))
  	  ((memq p '(:and :all))
  	   (dolist (next (cdr package))
  	     (setq body `((after! ,next ,@body))))
  	   (car body))))))


(defmacro prependq! (sym &rest lists)
  "Prepend LISTS to SYM in place."
  `(setq ,sym (append ,@lists ,sym)))

(defmacro appendq! (sym &rest lists)
  "Append LISTS to SYM in place."
  `(setq ,sym (append ,sym ,@lists)))

(defmacro delq! (elt list &optional fetcher)
  "`delq' ELT from LIST in-place.
If FETCHER is a function, ELT is used as the key in LIST (an alist)."
  `(setq ,list
       (delq ,(if fetcher
  		  `(funcall ,fetcher ,elt ,list)
  		elt)
  	     ,list)))


(defmacro defadvice! (symbol arglist &optional docstring &rest body)
  "Define an advice called SYMBOL and add it to PLACES.
ARGLIST is as in `defun'. WHERE is a keyword as passed to `advice-add', and
PLACE is the function to which to add the advice, like in `advice-add'.
DOCSTRING and BODY are as in `defun'.
\(fn SYMBOL ARGLIST &optional DOCSTRING &rest [WHERE PLACES...] BODY\)"
  (declare (doc-string 3) (indent defun))
  (unless (stringp docstring)
    (push docstring body)
    (setq docstring nil))
  (let (where-alist)
    (while (keywordp (car body))
      (push `(cons ,(pop body) (nasy-enlist ,(pop body)))
  	  where-alist))
    `(progn
       (defun ,symbol ,arglist ,docstring ,@body)
       (dolist (targets (list ,@(nreverse where-alist)))
       (dolist (target (cdr targets))
  	 (advice-add target (car targets) #',symbol))))))


(defmacro undefadvice! (symbol _arglist &optional docstring &rest body)
  "Undefine an advice called SYMBOL.
This has the same signature as `defadvice!' an exists as an easy undefiner when
testing advice (when combined with `rotate-text').
\(fn SYMBOL ARGLIST &optional DOCSTRING &rest [WHERE PLACES...] BODY\)"
  (declare (doc-string 3) (indent defun))
  (let (where-alist)
    (unless (stringp docstring)
      (push docstring body))
    (while (keywordp (car body))
      (push `(cons ,(pop body) (nasy-enlist ,(pop body)))
  	  where-alist))
    `(dolist (targets (list ,@(nreverse where-alist)))
       (dolist (target (cdr targets))
       (advice-remove target #',symbol)))))


(defmacro add-hook! (hooks &rest rest)
  "A convenience macro for adding N functions to M hooks.
If N and M = 1, there's no benefit to using this macro over `add-hook'.
This macro accepts, in order:
  1. The mode(s) or hook(s) to add to. This is either an unquoted mode, an
     unquoted list of modes, a quoted hook variable or a quoted list of hook
     variables.
  2. Optional properties :local and/or :append, which will make the hook
     buffer-local or append to the list of hooks (respectively),
  3. The function(s) to be added: this can be one function, a quoted list
     thereof, a list of `defun's, or body forms (implicitly wrapped in a
     lambda).
\(fn HOOKS [:append :local] FUNCTIONS)"
  (declare (indent (lambda (indent-point state)
  		   (goto-char indent-point)
  		   (when (looking-at-p "\\s-*(")
  		     (lisp-indent-defform state indent-point))))
  	 (debug t))
  (let* ((hook-forms (nasy--resolve-hook-forms hooks))
       (func-forms ())
       (defn-forms ())
       append-p
       local-p
       remove-p
       forms)
    (while (keywordp (car rest))
      (pcase (pop rest)
      (:append (setq append-p t))
      (:local  (setq local-p t))
      (:remove (setq remove-p t))))
    (let ((first (car-safe (car rest))))
      (cond ((null first)
  	   (setq func-forms rest))

  	  ((eq first 'defun)
  	   (setq func-forms (mapcar #'cadr rest)
  		 defn-forms rest))

  	  ((memq first '(quote function))
  	   (setq func-forms
  		 (if (cdr rest)
  		     (mapcar #'nasy-unquote rest)
  		   (nasy-enlist (nasy-unquote (car rest))))))

  	  ((setq func-forms (list `(lambda (&rest _) ,@rest)))))
      (dolist (hook hook-forms)
      (dolist (func func-forms)
  	(push (if remove-p
  		  `(remove-hook ',hook #',func ,local-p)
  		`(add-hook ',hook #',func ,append-p ,local-p))
  	      forms)))
      (macroexp-progn
       (append defn-forms
  	     (if append-p
  		 (nreverse forms)
  	       forms))))))

(defmacro remove-hook! (hooks &rest rest)
  "A convenience macro for removing N functions from M hooks.
Takes the same arguments as `add-hook!'.
If N and M = 1, there's no benefit to using this macro over `remove-hook'.
\(fn HOOKS [:append :local] FUNCTIONS)"
  (declare (indent defun) (debug t))
  `(add-hook! ,hooks :remove ,@rest))

;;;###autoload
(defun nasy/lsp-format-region-or-buffer ()
  "Format the buffer (or selection) with LSP."
  (interactive)
  (unless (bound-and-true-p lsp-mode)
    (user-error "Not in an LSP buffer"))
  (call-interactively
   (if (nasy/region-active-p)
       #'lsp-format-region
     #'lsp-format-buffer)))

;;;###autoload
(defvar nasy/real-buffer-functions
  '(nasy/dired-buffer-p)
  "A list of predicate functions run to determine if a buffer is real, unlike
`nasy/unreal-buffer-functions'. They are passed one argument: the buffer to be
tested.
Should any of its function returns non-nil, the rest of the functions are
ignored and the buffer is considered real.
See `nasy/real-buffer-p' for more information.")

;;;###autoload
(defvar nasy/unreal-buffer-functions
  '(minibufferp nasy/special-buffer-p nasy/non-file-visiting-buffer-p)
  "A list of predicate functions run to determine if a buffer is *not* real,
unlike `nasy/real-buffer-functions'. They are passed one argument: the buffer to
be tested.
Should any of these functions return non-nil, the rest of the functions are
ignored and the buffer is considered unreal.
See `nasy/real-buffer-p' for more information.")

;;;###autoload
(defvar-local nasy/real-buffer-p nil
  "If non-nil, this buffer should be considered real no matter what. See
`nasy/real-buffer-p' for more information.")

;;;###autoload
(defvar nasy/fallback-buffer-name "*scratch*"
  "The name of the buffer to fall back to if no other buffers exist (will create
it if it doesn't exist).")


;;
;; Functions

;;;###autoload
(defun nasy/buffer-frame-predicate (buf)
  "To be used as the default frame buffer-predicate parameter. Returns nil if
BUF should be skipped over by functions like `next-buffer' and `other-buffer'."
  (or (nasy/real-buffer-p buf)
      (eq buf (nasy/fallback-buffer))))

;;;###autoload
(defun nasy/fallback-buffer ()
  "Returns the fallback buffer, creating it if necessary. By default this is the
scratch buffer. See `nasy/fallback-buffer-name' to change this."
  (let (buffer-list-update-hook)
    (get-buffer-create nasy/fallback-buffer-name)))

;;;###autoload
(defalias 'nasy/buffer-list #'buffer-list)

;;;###autoload
(defun nasy/project-buffer-list (&optional project)
  "Return a list of buffers belonging to the specified PROJECT.
If PROJECT is nil, default to the current project.
If no project is active, return all buffers."
  (let ((buffers (nasy/buffer-list)))
    (if-let* ((project-root
  	     (if project (expand-file-name project)
  	       (nasy/project-root))))
      (cl-loop for buf in buffers
  	       if (projectile-project-buffer-p buf project-root)
  	       collect buf)
      buffers)))

;;;###autoload
(defun nasy/open-projects ()
  "Return a list of projects with open buffers."
  (cl-loop with projects = (make-hash-table :test 'equal :size 8)
  	 for buffer in (nasy/buffer-list)
  	 if (buffer-live-p buffer)
  	 if (nasy/real-buffer-p buffer)
  	 if (with-current-buffer buffer (nasy/project-root))
  	 do (puthash (abbreviate-file-name it) t projects)
  	 finally return (hash-table-keys projects)))

;;;###autoload
(defun nasy/dired-buffer-p (buf)
  "Returns non-nil if BUF is a dired buffer."
  (with-current-buffer buf (derived-mode-p 'dired-mode)))

;;;###autoload
(defun nasy/special-buffer-p (buf)
  "Returns non-nil if BUF's name starts and ends with an *."
  (equal (substring (buffer-name buf) 0 1) "*"))

;;;###autoload
(defun nasy/temp-buffer-p (buf)
  "Returns non-nil if BUF is temporary."
  (equal (substring (buffer-name buf) 0 1) " "))

;;;###autoload
(defun nasy/visible-buffer-p (buf)
  "Return non-nil if BUF is visible."
  (get-buffer-window buf))

;;;###autoload
(defun nasy/buried-buffer-p (buf)
  "Return non-nil if BUF is not visible."
  (not (nasy/visible-buffer-p buf)))

;;;###autoload
(defun nasy/non-file-visiting-buffer-p (buf)
  "Returns non-nil if BUF does not have a value for `buffer-file-name'."
  (not (buffer-file-name buf)))

;;;###autoload
(defun nasy/real-buffer-list (&optional buffer-list)
  "Return a list of buffers that satify `nasy/real-buffer-p'."
  (cl-remove-if-not #'nasy/real-buffer-p (or buffer-list (nasy/buffer-list))))

;;;###autoload
(defun nasy/real-buffer-p (buffer-or-name)
  "Returns t if BUFFER-OR-NAME is a 'real' buffer.
A real buffer is a useful buffer; a first class citizen in Doom. Real ones
should get special treatment, because we will be spending most of our time in
them. Unreal ones should be low-profile and easy to cast aside, so we can focus
on real ones.
The exact criteria for a real buffer is:
  1. A non-nil value for the buffer-local value of the `nasy/real-buffer-p'
     variable OR
  2. Any function in `nasy/real-buffer-functions' returns non-nil OR
  3. None of the functions in `nasy/unreal-buffer-functions' must return
     non-nil.
If BUFFER-OR-NAME is omitted or nil, the current buffer is tested."
  (or (bufferp buffer-or-name)
      (stringp buffer-or-name)
      (signal 'wrong-type-argument (list '(bufferp stringp) buffer-or-name)))
  (when-let (buf (get-buffer buffer-or-name))
    (and (buffer-live-p buf)
       (not (nasy/temp-buffer-p buf))
       (or (buffer-local-value 'nasy/real-buffer-p buf)
  	   (run-hook-with-args-until-success 'nasy/real-buffer-functions buf)
  	   (not (run-hook-with-args-until-success 'nasy/unreal-buffer-functions buf))))))

;;;###autoload
(defun nasy/unreal-buffer-p (buffer-or-name)
  "Return t if BUFFER-OR-NAME is an 'unreal' buffer.
See `nasy/real-buffer-p' for details on what that means."
  (not (nasy/real-buffer-p buffer-or-name)))

;;;###autoload
(defun nasy/buffers-in-mode (modes &optional buffer-list derived-p)
  "Return a list of buffers whose `major-mode' is `eq' to MODE(S).
If DERIVED-P, test with `derived-mode-p', otherwise use `eq'."
  (let ((modes (nasy/enlist modes)))
    (cl-remove-if-not (if derived-p
  			(lambda (buf)
  			  (with-current-buffer buf
  			    (apply #'derived-mode-p modes)))
  		      (lambda (buf)
  			(memq (buffer-local-value 'major-mode buf) modes)))
  		    (or buffer-list (nasy/buffer-list)))))

;;;###autoload
(defun nasy/visible-windows (&optional window-list)
  "Return a list of the visible, non-popup (dedicated) windows."
  (cl-loop for window in (or window-list (window-list))
  	 when (or (window-parameter window 'visible)
  		  (not (window-dedicated-p window)))
  	 collect window))

;;;###autoload
(defun nasy/visible-buffers (&optional buffer-list)
  "Return a list of visible buffers (i.e. not buried)."
  (if buffer-list
      (cl-remove-if-not #'get-buffer-window buffer-list)
    (delete-dups (mapcar #'window-buffer (window-list)))))

;;;###autoload
(defun nasy/buried-buffers (&optional buffer-list)
  "Get a list of buffers that are buried."
  (cl-remove-if #'get-buffer-window (or buffer-list (nasy/buffer-list))))

;;;###autoload
(defun nasy/matching-buffers (pattern &optional buffer-list)
  "Get a list of all buffers that match the regex PATTERN."
  (cl-loop for buf in (or buffer-list (nasy/buffer-list))
  	 when (string-match-p pattern (buffer-name buf))
  	 collect buf))

;;;###autoload
(defun nasy/set-buffer-real (buffer flag)
  "Forcibly mark BUFFER as FLAG (non-nil = real)."
  (with-current-buffer buffer
    (setq nasy/real-buffer-p flag)))

;;;###autoload
(defun nasy/kill-buffer-and-windows (buffer)
  "Kill the buffer and delete all the windows it's displayed in."
  (dolist (window (get-buffer-window-list buffer))
    (unless (one-window-p t)
      (delete-window window)))
  (kill-buffer buffer))

;;;###autoload
(defun nasy/fixup-windows (windows)
  "Ensure that each of WINDOWS is showing a real buffer or the fallback buffer."
  (dolist (window windows)
    (with-selected-window window
      (when (nasy/unreal-buffer-p (window-buffer))
      (previous-buffer)
      (when (nasy/unreal-buffer-p (window-buffer))
  	(switch-to-buffer (nasy/fallback-buffer)))))))

;;;###autoload
(defun nasy/kill-buffer-fixup-windows (buffer)
  "Kill the BUFFER and ensure all the windows it was displayed in have switched
to a real buffer or the fallback buffer."
  (let ((windows (get-buffer-window-list buffer)))
    (kill-buffer buffer)
    (nasy/fixup-windows (cl-remove-if-not #'window-live-p windows))))

;;;###autoload
(defun nasy/kill-buffers-fixup-windows (buffers)
  "Kill the BUFFERS and ensure all the windows they were displayed in have
switched to a real buffer or the fallback buffer."
  (let ((seen-windows (make-hash-table :test 'eq :size 8)))
    (dolist (buffer buffers)
      (let ((windows (get-buffer-window-list buffer)))
      (kill-buffer buffer)
      (dolist (window (cl-remove-if-not #'window-live-p windows))
  	(puthash window t seen-windows))))
    (nasy/fixup-windows (hash-table-keys seen-windows))))

;;;###autoload
(defun nasy/kill-matching-buffers (pattern &optional buffer-list)
  "Kill all buffers (in current workspace OR in BUFFER-LIST) that match the
regex PATTERN. Returns the number of killed buffers."
  (let ((buffers (nasy/matching-buffers pattern buffer-list)))
    (dolist (buf buffers (length buffers))
      (kill-buffer buf))))


;;
;; Hooks

;;;###autoload
(defun nasy/mark-buffer-as-real-h ()
  "Hook function that marks the current buffer as real."
  (nasy/set-buffer-real (current-buffer) t))


;;
;; Interactive commands

;;;###autoload
(defun nasy/kill-this-buffer-in-all-windows (buffer &optional dont-save)
  "Kill BUFFER globally and ensure all windows previously showing this buffer
have switched to a real buffer or the fallback buffer.
If DONT-SAVE, don't prompt to save modified buffers (discarding their changes)."
  (interactive
   (list (current-buffer) current-prefix-arg))
  (cl-assert (bufferp buffer) t)
  (when (and (buffer-modified-p buffer) dont-save)
    (with-current-buffer buffer
      (set-buffer-modified-p nil)))
  (nasy/kill-buffer-fixup-windows buffer))


(defun nasy/message-or-count (interactive message count)
  (if interactive
      (message message count)
    count))

;;;###autoload
(defun nasy/kill-all-buffers (&optional buffer-list interactive)
  "Kill all buffers and closes their windows.
If the prefix arg is passed, doesn't close windows and only kill buffers that
belong to the current project."
  (interactive
   (list (if current-prefix-arg
  	   (nasy/project-buffer-list)
  	 (nasy/buffer-list))
       t))
  (if (null buffer-list)
      (message "No buffers to kill")
    (save-some-buffers)
    (delete-other-windows)
    (when (memq (current-buffer) buffer-list)
      (switch-to-buffer (nasy/fallback-buffer)))
    (mapc #'kill-buffer buffer-list)
    (nasy/message-or-count
     interactive "Killed %d buffers"
     (- (length buffer-list)
      (length (cl-remove-if-not #'buffer-live-p buffer-list))))))

;;;###autoload
(defun nasy/kill-other-buffers (&optional buffer-list interactive)
  "Kill all other buffers (besides the current one).
If the prefix arg is passed, kill only buffers that belong to the current
project."
  (interactive
   (list (delq (current-buffer)
  	     (if current-prefix-arg
  		 (nasy/project-buffer-list)
  	       (nasy/buffer-list)))
       t))
  (mapc #'nasy/kill-buffer-and-windows buffer-list)
  (nasy/message-or-count
   interactive "Killed %d other buffers"
   (- (length buffer-list)
      (length (cl-remove-if-not #'buffer-live-p buffer-list)))))

;;;###autoload
(defun nasy/kill-matching-buffers (pattern &optional buffer-list interactive)
  "Kill buffers that match PATTERN in BUFFER-LIST.
If the prefix arg is passed, only kill matching buffers in the current project."
  (interactive
   (list (read-regexp "Buffer pattern: ")
       (if current-prefix-arg
  	   (nasy/project-buffer-list)
  	 (nasy/buffer-list))
       t))
  (nasy/kill-matching-buffers pattern buffer-list)
  (when interactive
    (message "Killed %d buffer(s)"
  	   (- (length buffer-list)
  	      (length (cl-remove-if-not #'buffer-live-p buffer-list))))))

;;;###autoload
(defun nasy/kill-buried-buffers (&optional buffer-list interactive)
  "Kill buffers that are buried.
If PROJECT-P (universal argument), only kill buried buffers belonging to the
current project."
  (interactive
   (list (nasy/buried-buffers
  	(if current-prefix-arg (nasy/project-buffer-list)))
       t))
  (mapc #'kill-buffer buffer-list)
  (nasy/message-or-count
   interactive "Killed %d buried buffers"
   (- (length buffer-list)
      (length (cl-remove-if-not #'buffer-live-p buffer-list)))))

;;;###autoload
(defun nasy/kill-project-buffers (project &optional interactive)
  "Kill buffers for the specified PROJECT."
  (interactive
   (list (if-let (open-projects (nasy/open-projects))
  	   (completing-read
  	    "Kill buffers for project: " open-projects
  	    nil t nil nil
  	    (if-let* ((project-root (nasy/project-root))
  		      (project-root (abbreviate-file-name project-root))
  		      ((member project-root open-projects)))
  		project-root))
  	 (message "No projects are open!")
  	 nil)
       t))
  (when project
    (let ((buffer-list (nasy/project-buffer-list project)))
      (nasy/kill-buffers-fixup-windows buffer-list)
      (nasy/message-or-count
       interactive "Killed %d project buffers"
       (- (length buffer-list)
  	(length (cl-remove-if-not #'buffer-live-p buffer-list)))))))

;;
;;; Library

;;;###autoload
(defun nasy/project-p (&optional dir)
  "Return t if DIR (defaults to `default-directory') is a valid project."
  (and (nasy/project-root dir)
       t))

;;;###autoload
(defun nasy/project-root (&optional dir)
  "Return the project root of DIR (defaults to `default-directory').
Returns nil if not in a project."
  (let ((projectile-project-root (unless dir projectile-project-root))
      projectile-require-project-root)
    (projectile-project-root dir)))

;;;###autoload
(defun nasy/delete-backward-word (arg)
  "Like `backward-kill-word', but doesn't affect the kill-ring."
  (interactive "p")
  (let (kill-ring)
    (backward-kill-word arg)))

;;;###autoload
(defun nasy/region-active-p ()
  "Return non-nil if selection is active."
  (declare (side-effect-free t))
  (use-region-p))

;;;###autoload
(defun nasy/region-beginning ()
  "Return beginning position of selection."
  (declare (side-effect-free t))
  (region-beginning))

;;;###autoload
(defun nasy/region-end ()
  "Return end position of selection."
  (declare (side-effect-free t))
  (region-end))

;;;###autoload
(defun nasy/thing-at-point-or-region (&optional thing prompt)
  "Grab the current selection, THING at point, or xref identifier at point.
Returns THING if it is a string. Otherwise, if nothing is found at point and
PROMPT is non-nil, prompt for a string (if PROMPT is a string it'll be used as
the prompting string). Returns nil if all else fails.
NOTE: Don't use THING for grabbing symbol-at-point. The xref fallback is smarter
in some cases."
  (declare (side-effect-free t))
  (cond ((stringp thing)
       thing)
      ((nasy/region-active-p)
       (buffer-substring-no-properties
  	(nasy/region-beginning)
  	(nasy/region-end)))
      (thing
       (thing-at-point thing t))
      ((require 'xref nil t)
       ;; A little smarter than using `symbol-at-point', though in most cases,
       ;; xref ends up using `symbol-at-point' anyway.
       (xref-backend-identifier-at-point (xref-find-backend)))
      (prompt
       (read-string (if (stringp prompt) prompt "")))))

;;;###autoload
(defalias 'default/newline #'newline)

;;;###autoload
(defun default/newline-above ()
  "Insert an indented new line before the current one."
  (interactive)
  (beginning-of-line)
  (save-excursion (newline))
  (indent-according-to-mode))

;;;###autoload
(defun default/newline-below ()
  "Insert an indented new line after the current one."
  (interactive)
  (end-of-line)
  (newline-and-indent))

;;;###autoload
(defun default/yank-pop ()
  "Interactively select what text to insert from the kill ring."
  (interactive)
  (call-interactively
   (cond ((fboundp 'counsel-yank-pop)    #'counsel-yank-pop)
       ((fboundp 'helm-show-kill-ring) #'helm-show-kill-ring)
       ((error "No kill-ring search backend available. Enable ivy or helm!")))))

;;;###autoload
(defun default/yank-buffer-filename ()
  "Copy the current buffer's path to the kill ring."
  (interactive)
  (if-let* ((filename (or buffer-file-name (bound-and-true-p list-buffers-directory))))
      (message (kill-new (abbreviate-file-name filename)))
    (error "Couldn't find filename in current buffer")))

;;;###autoload
(defun default/insert-file-path (arg)
  "Insert the file name (absolute path if prefix ARG).
If `buffer-file-name' isn't set, uses `default-directory'."
  (interactive "P")
  (let ((path (or buffer-file-name default-directory)))
    (insert
     (if arg
       (abbreviate-file-name path)
       (file-name-nondirectory path)))))

;;;###autoload
(defun default/newline-indent-and-continue-comments-a ()
  "A replacement for `newline-and-indent'.
Continues comments if executed from a commented line, with special support for
languages with weak native comment continuation support (like C-family
languages)."
  (interactive)
  (if (and (sp-point-in-comment)
  	 comment-line-break-function)
      (funcall comment-line-break-function nil)
    (delete-horizontal-space t)
    (newline nil t)
    (indent-according-to-mode)))

(setq straight-recipes-gnu-elpa-use-mirror    t
      straight-repository-branch              "develop"
      straight-vc-git-default-clone-depth     1
      straight-enable-use-package-integration nil
      straight-check-for-modifications        '(find-when-checking))

(defvar bootstrap-version)

(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
      (url-retrieve-synchronously
       "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
       'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)

(defmacro use-feature (name &rest args)
  "Like `use-package', but with `straight-use-package-by-default' disabled.
NAME and ARGS are as in `use-package'."
  (declare (indent defun))
  `(use-package ,name
     ,@args))

;; Feature `straight-x' from package `straight' provides
;; experimental/unstable extensions to straight.el which are not yet
;; ready for official inclusion.
(use-feature straight-x
  ;; Add an autoload for this extremely useful command.
  :commands (straight-x-fetch-all))

(defmacro nasy/s-u-p (&rest packages)
  "Straight use multiple PACKAGES."
  (unless (null packages)
    (let* ((package (car packages))
  	 (rest    (cdr packages))
  	 (q-p     (boundp package)))
      `(progn
       (if ,q-p
  	   (straight-use-package ,package)
  	 (straight-use-package ',package))
       (nasy/s-u-p ,@rest)))))

(straight-use-package 'gcmh)
(use-package gcmh
  :demand t
  :init
  (setq gcmh-verbose             t
      gcmh-lows-cons-threshold #x800000
      gcmh-high-cons-threshold most-positive-fixnum
      gcmh-idle-delay          3600)
  :config
  (gcmh-mode))

(straight-use-package 'benchmark-init)
(use-package benchmark-init
  :demand t
  :hook ((after-init . benchmark-init/deactivate)))

(straight-use-package 'no-littering)
(require 'no-littering)

(defvar nasy/config-before-hook nil
  "Hooks to run config functions before load custom.el.")

(defvar nasy/config-after-hook nil
  "Hooks to run config functions after.")

(add-hook 'nasy/config-after-hook
  	#'(lambda () (message "Hi~ Hope you have fun with this config.")))

(defgroup nasy nil
  "Nasy Emacs Custom Configurations."
  :group 'emacs)

(defcustom lisp-modes-hooks '(common-lisp-mode-hook
  			    emacs-lisp-mode-hook
  			    lisp-mode-hook
  			    racket-mode-hook
  			    scheme-mode-hook)
  "List of lisp-related modes hooks."
  :type '(repeat symbol)
  :group 'nasy)

(defcustom *clangd* (executable-find "clangd")
  "Clangd path.  If nil, will not use clangd."
  :group 'nasy
  :type 'string)

(defcustom *ccls* (executable-find "ccls")  ;; macOS
  "Ccls path.  If nil, will not use ccls."
  :group 'nasy
  :type 'string)

(defvar *eldoc-use* 'eldoc-overlay
  "Use eldoc-box, eldoc-overlay or not.

nil means use default.

box means use eldoc-box.

overlay means use eldoc-overlay.")

(defvar *flycheck-inline* t
  "Use flycheck-inline or not.")

(defcustom *nix* nil
  "Nix path.  If nil, will not use nix."
  :group 'nasy
  :type 'string)

(defcustom *rust* (or (executable-find "rustc")
  		    (executable-find "cargo")
  		    (executable-find "rustup"))
  "The Rust path.  If nil, will not use Rust."
  :group 'nasy
  :type 'string)

(defcustom *rls* (executable-find "rls")
  "The rls path.  If nil, will not use rls."
  :group 'nasy
  :type 'string)

(defcustom *highlight-indent-guides* t
  "Whether to use highlight-indent-guides or not."
  :group 'nasy
  :type 'boolean)

(defcustom *debug* t
  "Whether to use debug or not."
  :group 'nasy
  :type 'boolean)

(defcustom *server* t
  "Whether to use server or not."
  :group 'nasy
  :type 'boolean)

(defcustom *intero* t
  "Whether to use intero or not."
  :group 'nasy
  :type 'boolean)

(defcustom *struct-hs* (executable-find "structured-haskell-mode")
  "The structured-haskell-mode path.  If nil, will not use structured-haskell-mode."
  :group 'nasy
  :type 'string)

(defcustom *pyblack* nil
  "Whether to use black to reformat python or not."
  :group 'nasy
  :type 'boolean)

(defcustom *py-module* 'elpy
  "Select py module."
  :group 'nasy
  :type '(choice (const :tag "Use elpy"   elpy)
  	       (const :tag "Use pyls"   pyls)
  	       (const :tag "Use mspyls" mspyls)))


(defcustom *c-box* t
  "Whether to use company box or not."
  :group 'nasy
  :type 'boolean)

(defcustom *ivy/helm/selectrum* 'selectrum
  "Use ivy, helm or selectrum?"
  :group 'nasy
  :type '(choice (const :tag "Use ivy"       ivy)
  	       (const :tag "Use helm"      helm)
  	       (const :tag "Use selectrum" selectrum)))

(defcustom *ivy-or-helm* 'ivy
  "Use ivy or helm?"
  :group 'nasy
  :type '(choice (const :tag "Use ivy"  ivy)
  	       (const :tag "Use helm" helm)))

(defcustom *ivy-posframe* nil
  "Whether to use ivy-posframe or not."
  :group 'nasy
  :type 'boolean)

(defcustom *ivy-fuzzy* nil
  "Enables fuzzy completion for Ivy searches."
  :group 'nasy
  :type  'boolean)

(defcustom *ivy-prescient* nil
  "Enables prescient filtering and sorting for Ivy searches."
  :group 'nasy
  :type  'boolean)

(defcustom *vterm* nil
  "Whether to use vterm or not."
  :group 'nasy
  :type 'boolean)

(defcustom *org-headline-rescale* t
  "Whether to rescale org-headline or not."
  :group 'nasy
  :type 'boolean)

(defcustom *ispell* (executable-find "aspell")
  "The Ispell.  If nil, will not use Ispell."
  :group 'nasy
  :type 'string)

(defcustom *theme* 'doom-dracula
  "The Theme."
  :group 'nasy
  :type 'symbol)

(defcustom *dvorak* nil
  "Whether to use dvorak or not."
  :group 'nasy
  :type 'boolean)

(defcustom *dvorak-trans* nil
    "Whether to trans dvorak to qwerty key-bindings or not."
    :group 'nasy
    :type 'boolean)

(defcustom *mouse-color* "black"
  "Mouse color."
  :group 'nasy
  :type 'string)

(defcustom *font* "OperatorMonoSSmLig Nerd Font"
 "The main font.  After change it, run `M-x nasy/set-font' to see the effect."
 :group 'nasy
 :type 'string)

(defcustom *font-size* 12.0
 "The main font.  After change it, run `M-x nasy/set-font' to see the effect."
 :group 'nasy
 :type 'float)

(defcustom *font-weight* 'normal
 "The main font.  After change it, run `M-x nasy/set-font' to see the effect."
 :group 'nasy
 :type 'symbol)

(defcustom *font-cjk* "Xingkai SC"
 "The cjk font.  After change it, run `M-x nasy/set-font' to see the effect."
 :group 'nasy
 :type 'string)

(defcustom *font-size-cjk* 16.0
 "The cjk font.  After change it, run `M-x nasy/set-font' to see the effect."
 :group 'nasy
 :type 'float)

(defcustom *font-weight-cjk* 'light
 "The cjk font.  After change it, run `M-x nasy/set-font' to see the effect."
 :group 'nasy
 :type 'symbol)

(defcustom *lookup/offline* t
  "Install and prefer offline dictionary/thesaurus."
  :group 'nasy
  :type 'boolean)

(defvar nasy/projectile-fd-binary
  (or (cl-find-if #'executable-find '("fdfind" "fd"))
      "fd")
  "name of `fd-find' executable binary")

(setq-default
 company-idle-delay .5)

(setq-default
  blink-cursor-interval .6
  blink-matching-paren  t
  cursor-in-non-selected-windows t)

(blink-cursor-mode 1)

(add-hook 'nasy/config-after-hook
  	#'(lambda ()
  	    (when (fboundp 'set-mouse-color)
  	      (set-mouse-color *mouse-color*))))

(setq-default
 haskell-stylish-on-save nil
 lsp-rust-rls-command    '("rls"))

(setq-default
 org-pandoc-options-for-context     '((template . "~/.emacs.d/extra/nasy-context.tex"))  ;; I have no idea why I cannot set it as a variable.
 org-pandoc-options-for-context-pdf '((template . "~/.emacs.d/extra/nasy-context.tex")))

(setq-default
 show-paren-style                                'parenthesis
 sp-autoinsert-quote-if-followed-by-closing-pair t
 sp-base-key-bindings                            'paredit
 sp-show-pair-from-inside                        t)

(setq hscroll-margin                  7
      scroll-margin                   7
      hscroll-step                    7
      scroll-step                     7
      scroll-conservatively           100000
      scroll-preserve-screen-position 'always
      mac-mouse-wheel-smooth-scroll    nil)

(setq-default
 shell-file-name "/bin/zsh")

(setq-default
 initial-scratch-message     (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
 dashboard-banner-logo-title (concat ";; Happy hacking, " user-login-name " - Emacs ♥ you!\n\n")
 ;; initial-buffer-choice       #'(lambda () (get-buffer "*dashboard*"))  ;; It will cause error if you start emacs from Command line with file name
  									;; https://github.com/rakanalh/emacs-dashboard/issues/69
)

(setq-default
 fill-column                    80
 visual-fill-column-width       100
 word-wrap                      t
 highlight-indent-guides-method 'column
 tab-width                      8
 tooltip-delay                  1.5)

(setq-default
 whitespace-line-column 80
 whitespace-style       '(face spaces tabs newline
  			space-mark tab-mark newline-mark
  			lines-tail empty))

(setq-default
   bookmark-default-file (no-littering-expand-var-file-name ".bookmarks.el")
   buffers-menu-max-size 30
   case-fold-search      t
   column-number-mode    t
   dired-dwim-target     t
   ediff-split-window-function 'split-window-horizontally
   ediff-window-setup-function 'ediff-setup-windows-plain
   indent-tabs-mode      nil
   line-move-visual      t
   make-backup-files     nil
   mouse-yank-at-point   t
   require-final-newline t
   save-interprogram-paste-before-kill t
   set-mark-command-repeat-pop    t
   tab-always-indent              'complete
   truncate-lines                 nil
   truncate-partial-width-windows nil)

(when *is-a-mac*
  (setq line-move-visual nil))

(fset 'yes-or-no-p 'y-or-n-p)

(global-auto-revert-mode t)

(delete-selection-mode t)

(defun nasy/config-after ()
  "Set configuration need to be set after init."
  (setq-default
   ;; helm-allow-mouse                  t
   ;; helm-follow-mode-persistent       t
   ;; helm-move-to-line-cycle-in-source nil
   ;; helm-source-names-using-follow    '("Buffers" "kill-buffer" "Occur")
   debug-on-error *debug*))


(add-hook 'nasy/config-after-hook  #'nasy/config-after)

(defun nasy/set-face ()
  "Set custom face."
  (after! org
    (set-face-attribute 'org-meta-line        nil
  		      :slant 'italic)
    (set-face-attribute 'org-block-begin-line nil
  		      :slant 'italic)
    (set-face-attribute 'org-block-end-line   nil
  		      :slant 'italic)

    (when *org-headline-rescale*
      (set-face-attribute 'org-level-1 nil
  			:height  1.5
  			:inherit 'outline-1)
      (set-face-attribute 'org-level-2 nil
  			:height  1.3
  			:inherit 'outline-2)
      (set-face-attribute 'org-level-3 nil
  			:height  1.2
  			:inherit 'outline-3)
      (set-face-attribute 'org-level-4 nil
  			:height  1.1
  			:inherit 'outline-4)))

  (set-face-attribute 'font-lock-comment-face nil
  		    :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face nil
  		    :slant 'italic)
  (set-face-attribute 'font-lock-builtin-face nil
  		    :slant 'italic)
  (set-face-attribute 'show-paren-match       nil
  		    :background "#a1de93"
  		    :foreground "#705772"
  		    :weight     'ultra-bold)

  (after-x 'tab-line
    (set-face-attribute 'tab-line nil
  		      :background "#303946"
  		      :foreground "#F4FFC9")

    (set-face-attribute 'tab-line-tab nil
  		      :background "#3C78D8")

    (set-face-attribute 'tab-line-tab-current nil
  		      :background "#FFFC67"
  		      :foreground "#222831"
  		      :inherit    'tab-line-tab)

    (set-face-attribute 'tab-line-tab-inactive nil
  		      :background "#5FF967"
  		      :foreground "#222831"
  		      :inherit 'tab-line-tab))

  (after-x 'smartparens-config
    (set-face-attribute 'sp-show-pair-match-face nil
  		      :background "#a1de93"
  		      :foreground "#705772"
  		      :weight     'ultra-bold)))

(add-hook 'nasy/config-after-hook #'nasy/set-face)

(add-to-list 'load-path (expand-file-name "custom" user-emacs-directory))
(require 'user-config-example)
(require 'user-config nil t)

(straight-use-package 'general)
(use-package general
  :init
  (defalias 'gsetq #'general-setq)
  (defalias 'gsetq-local #'general-setq-local)
  (defalias 'gsetq-default #'general-setq-default))

(when *is-a-mac*
  (gsetq mac-option-modifier        'meta
       mac-command-modifier       'hyper
       mac-right-command-modifier 'super
       mac-function-modifier      'super)

  (general-define-key
   "C-z" 'stop-minimizing-window

   ;; cursor Movement
   "H-<up>"   'beginning-of-buffer
   "H-<down>" 'end-of-buffer
   "H-l"      'goto-line

   ;; text Operations
   "H-a" 'mark-whole-buffer
   "H-v" 'yank
   "H-c" 'kill-ring-save
   "H-s" 'save-buffer
   "H-z" 'undo
   "H-w" (lambda! (delete-window))
   "M-¥" (lambda! (insert "\\"))
   "H-<backspace>" (lambda! (kill-line 0)))

  ;; unset
  (global-unset-key (kbd "<magnify-down>"))
  (global-unset-key (kbd "<magnify-up>")))

(add-hook #'nasy/config-after-hook
  	#'(lambda ()
  	    (when *dvorak-trans*
  	      (general-define-key
  	       :keymaps 'key-translation-map
  	       "C-," "C-x"
  	       "C-x" "C-,"
  	       "M-," "M-x"
  	       "M-x" "M-,"
  	       "C-c" "C-."
  	       "C-." "C-c"
  	       "M-c" "M-."
  	       "M-." "M-c"))))

(defun nasy/toogle-dvorak ()
  "Toogle dvorak key bindings."
  (interactive)
  (if (not *dvorak-trans*)
      (progn
      (general-define-key
       :keymaps 'key-translation-map
       "C-," "C-x"
       "C-x" "C-,"
       "M-," "M-x"
       "M-x" "M-,"
       "C-c" "C-."
       "C-." "C-c"
       "M-c" "M-."
       "M-." "M-c")
      (gsetq *dvorak-trans* t)
      (message "Use Dvorak key bindings."))
    (progn
      (general-define-key
       :keymaps 'key-translation-map
       "C-," nil
       "C-x" nil
       "M-," nil
       "M-x" nil
       "C-c" nil
       "C-." nil
       "M-c" nil
       "M-." nil)
      (gsetq *dvorak-trans* nil)
      (message "Use normal key bindings."))))

(general-define-key
 "<mouse-4>" (lambda! (scroll-down 1))
 "<mouse-5>" (lambda! (scroll-up 1)))

(general-define-key
 "C-."  #'imenu

 ;;; newlines
 [remap newline]  #'newline-and-indent
 "C-j"            #'default/newline

 ;;; search
 "C-s"    (cond
  	 ((eq *ivy-or-helm* 'ivy)
  	  #'swiper-isearch)
  	 ((eq *ivy-or-helm* 'helm)
  	  #'swiper-helm)
  	 (t #'isearch-forward))
 "C-S-s"  (cond
  	 ((eq *ivy-or-helm* 'ivy)
  	  #'swiper-isearch-thing-at-point))
 "C-r"    (cond
  	 ((eq *ivy-or-helm* 'ivy)
  	  #'ivy-resume)
  	 ((eq *ivy-or-helm* 'helm)
  	  #'helm-resume)
  	 (t #'isearch-backward))

 ;;; buffers
 "C-x b"    #'switch-to-buffer
 "C-x 4 b"  #'switch-to-buffer-other-window
 "C-x C-b"  #'ibuffer-list-buffers
 "C-x K"    #'nasy/kill-this-buffer-in-all-windows)

(defvar nasy-map
  (let ((map (make-sparse-keymap)))
    map)
  "Nasy Keymaps.")

(general-create-definer nasy-def
  :prefix "C-c"
  :prefix-map 'nasy-map)


(defmacro n/map (key name desc &rest rest)
  "Nasy keymap define macro."
  (let ((n/name (format "nasy/%s" name)))
    (let ((keymap (intern (concat n/name "-map")))
  	(def    (intern (concat n/name "-def"))))
     `(progn
      (defvar ,keymap (make-sparse-keymap) ,desc)
      (nasy-def ,key '(:keymap ,keymap :wk ,n/name))
      (general-create-definer ,def
  	:keymaps ',keymap)
      (,def ,@rest)))))

(n/map
 "c" "code" "Nasy code keymap"
 "c" #'compile
 "C" #'recompile
 "k" #'nasy/lookup/documentation

 "x" #'flycheck-list-errors

 "a" #'lsp-excute-code-action
 "f" #'nasy/lsp-format-region-or-buffer
 "i" #'lsp-organize-imports
 "r" #'lsp-rename
 "j" (cond
      ((eq *ivy-or-helm* 'ivy)
       #'lsp-ivy-workspace-symbol)
      ((eq *ivy-or-helm* 'helm)
       #'helm-ivy-workspace-symbol))
 "J" (cond
      ((eq *ivy-or-helm* 'ivy)
       #'lsp-ivy-global-workspace-symbol)
      ((eq *ivy-or-helm* 'helm)
       #'helm-ivy-global-workspace-symbol)))

(general-define-key
 "C-;"  #'nasy/company-complete)

(general-define-key
 :keymaps 'company-active-map
 "C-o"        #'company-search-kill-others
 "C-n"        #'company-select-next
 "C-p"        #'company-select-previous
 "C-h"        #'company-quickhelp-manual-begin
 "C-S-h"      #'company-show-doc-buffer
 "C-s"        #'company-search-candidates
 "M-s"        #'company-filter-candidates
 [C-tab]      #'nasy/company-complete
 [tab]        #'company-complete-common-or-cycle
 [backtab]    #'company-select-previous
 [C-return]   #'counsel-company)

(general-define-key
 :keymaps 'company-search-map
 "C-n"        #'company-search-repeat-forward
 "C-p"        #'company-search-repeat-backward
 "C-s"        (λ! (company-search-abort) (company-filter-candidates)))

(n/map
 "f" "file" "Nasy file keymap")

(n/map
 "t" "n-treemacs" "Nasy treemacs keymap"
 "1" #'treemacs-delete-other-windows
 "t" #'treemacs
 "B" #'treemacs-bookmark
 "f" #'treemacs-find-file
 "T" #'treemacs-find-tag)

(straight-use-package 'session)
(straight-use-package 'super-save)

(defvar desktop-base-file-name)
(defvar desktop-dirname)
(defvar desktop-restore-eager)
(defvar desktop-file-modtime)

;;
;;; Helpers

;;;###autoload
(defun nasy-session-file (&optional name)
  "TODO"
  (cond ((require 'persp-mode nil t)
       (expand-file-name (or name persp-auto-save-fname) persp-save-dir))
      ((require 'desktop nil t)
       (if name
  	   (expand-file-name name (file-name-directory (desktop-full-file-name)))
  	 (desktop-full-file-name)))
      ((error "No session backend available"))))

;;;###autoload
(defun nasy-save-session (&optional file)
  "TODO"
  (setq file (expand-file-name (or file (nasy-session-file))))
  (cond ((require 'persp-mode nil t)
       (unless persp-mode (persp-mode +1))
       (setq persp-auto-save-opt 0)
       (persp-save-state-to-file file))
      ((and (require 'frameset nil t)
  	    (require 'restart-emacs nil t))
       (let ((frameset-filter-alist (append '((client . restart-emacs--record-tty-file))
  					    frameset-filter-alist))
  	     (desktop-base-file-name (file-name-nondirectory file))
  	     (desktop-dirname (file-name-directory file))
  	     (desktop-restore-eager t)
  	     desktop-file-modtime)
  	 (make-directory desktop-dirname t)
  	 ;; Prevents confirmation prompts
  	 (let ((desktop-file-modtime (nth 5 (file-attributes (desktop-full-file-name)))))
  	   (desktop-save desktop-dirname t))))
      ((error "No session backend to save session with"))))

;;;###autoload
(defun nasy-load-session (&optional file)
  "TODO"
  (setq file (expand-file-name (or file (nasy-session-file))))
  (message "Attempting to load %s" file)
  (cond ((not (file-readable-p file))
       (message "No session file at %S to read from" file))
      ((require 'persp-mode nil t)
       (unless persp-mode
  	 (persp-mode +1))
       (let ((allowed (persp-list-persp-names-in-file file)))
  	 (cl-loop for name being the hash-keys of *persp-hash*
  		  unless (member name allowed)
  		  do (persp-kill name))
  	 (persp-load-state-from-file file)))
      ((and (require 'frameset nil t)
  	    (require 'restart-emacs nil t))
       (restart-emacs--restore-frames-using-desktop file))
      ((error "No session backend to load session with"))))


;;
;;; Command line switch

;;;###autoload
(defun nasy-restore-session-handler (&rest _)
  "TODO"
  (add-hook 'window-setup-hook #'nasy-load-session 'append))


;;
;;; Commands

;;;###autoload
(defun nasy/quickload-session ()
  "TODO"
  (interactive)
  (message "Restoring session...")
  (nasy-load-session)
  (message "Session restored. Welcome back."))

;;;###autoload
(defun nasy/quicksave-session ()
  "TODO"
  (interactive)
  (message "Saving session")
  (nasy-save-session)
  (message "Saving session...DONE"))

;;;###autoload
(defun nasy/load-session (file)
  "TODO"
  (interactive
   (let ((session-file (nasy-session-file)))
     (list (or (read-file-name "Session to restore: "
  			     (file-name-directory session-file)
  			     (file-name-nondirectory session-file)
  			     t)
  	     (user-error "No session selected. Aborting")))))
  (unless file
    (error "No session file selected"))
  (message "Loading '%s' session" file)
  (nasy-load-session file)
  (message "Session restored. Welcome back."))

;;;###autoload
(defun nasy/save-session (file)
  "TODO"
  (interactive
   (let ((session-file (nasy-session-file)))
     (list (or (read-file-name "Save session to: "
  			     (file-name-directory session-file)
  			     (file-name-nondirectory session-file))
  	     (user-error "No session selected. Aborting")))))
  (unless file
    (error "No session file selected"))
  (message "Saving '%s' session" file)
  (nasy-save-session file))

;;;###autoload
(defalias 'nasy/restart #'restart-emacs)

;;;###autoload
(defun nasy/restart-and-restore (&optional debug)
  "TODO"
  (interactive "P")
  (setq nasy-autosave-session nil)
  (nasy/quicksave-session)
  (restart-emacs
   (append (if debug (list "--debug-init"))
  	 (when (boundp 'chemacs-current-emacs-profile)
  	   (list "--with-profile" chemacs-current-emacs-profile))
  	 (list "--restore"))))

(gsetq kill-ring-max 300)

(gsetq history-length 3000
       history-delete-duplicates t
       savehist-additional-variables
       '(mark-ring
       global-mark-ring
       search-ring
       regexp-search-ring
       extended-command-history)
       savehist-autosave-interval 60)

(add-hook #'after-init-hook #'savehist-mode)

(use-package session
  :defer    t
  :hook ((after-init . session-initialize))
  :init
  (gsetq session-save-file (no-littering-expand-var-file-name ".session")
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
  		 (ivy-history              . 100)
  		 (magit-revision-history   . 50)
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
  		 tags-table-list
  		 kill-ring))))

(use-package super-save
  :ghook 'after-init-hook
  :gfhook '(lambda () (remove-hook #'mouse-leave-buffer-hook #'super-save-command))
  :init (gsetq super-save-auto-save-when-idle nil
  	     super-save-remote-files        nil
  	     super-save-hook-triggers       nil
  	     super-save-triggers
  	     '(ibuffer other-window windmove-up windmove-down windmove-left windmove-right next-buffer previous-buffer)))

(straight-use-package 'org-plus-contrib)

(when *is-a-mac*
  (add-to-list 'default-frame-alist
  	     '(ns-transparent-titlebar . t))

  (add-to-list 'default-frame-alist
  	     '(ns-appearance . dark))

  (add-to-list 'default-frame-alist
  	     '(alpha . (80 . 75)))

  (defun stop-minimizing-window ()
    "Stop minimizing window under macOS."
    (interactive)
    (unless (and *is-a-mac*
  	       window-system)
      (suspend-frame))))

(setq use-file-dialog        nil
      use-dialog-box         nil
      inhibit-startup-screen t)

(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))

(when (fboundp 'set-scroll-bar-mode)
  (set-scroll-bar-mode nil))

;; https://github.com/jwiegley/emacs-async
(straight-use-package 'async)
(use-package dired-async
  :commands dired-async-mode)
(use-package async-bytecomp
  :config
  (gsetq async-bytecomp-allowed-packages '(all))
  (async-bytecomp-package-mode))

;; (straight-use-package 'auto-compile)
;; (require 'auto-compile)
;; (auto-compile-on-load-mode)
;; (auto-compile-on-save-mode)

(setq-default compilation-scroll-output t)

;; https://github.com/jwiegley/alert
(straight-use-package 'alert)
(use-package alert
  :defer    t
  :preface
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
  :defer t
  :preface
  (defvar nasy/last-compilation-buffer nil
    "The last buffer in which compilation took place.")

  (defun nasy/save-compilation-buffer (&rest _)
    "Save the compilation buffer to find it later."
    (setq nasy/last-compilation-buffer next-error-last-buffer))
  (advice-add 'compilation-start :after 'nasy/save-compilation-buffer)

  (defun nasy/find-prev-compilation (orig &rest args)
    "Find the previous compilation buffer, if present, and recompile there."
    (if (and (null edit-command)
  	   (not (derived-mode-p 'compilation-mode))
  	   nasy:last-compilation-buffer
  	   (buffer-live-p (get-buffer nasy/last-compilation-buffer)))
      (with-current-buffer nasy/last-compilation-buffer
  	(apply orig args))
      (apply orig args)))
  :bind (([f6] . recompile))
  :hook ((compilation-finish-functions . alert-after-compilation-finish)))

(use-package ansi-color
  :defer    t
  :preface
  (defun colourise-compilation-buffer ()
    (when (eq major-mode 'compilation-mode)
      (ansi-cOLOR-APPLY-on-region compilation-filter-start (point-max))))
  :hook ((compilation-filter . colourise-compilation-buffer)))

(require 'jka-compr)
(auto-compression-mode)

(gsetq kill-ring-max 300)

(gsetq history-length 3000
       history-delete-duplicates t
       savehist-additional-variables
       '(mark-ring
       global-mark-ring
       search-ring
       regexp-search-ring
       extended-command-history)
       savehist-autosave-interval 60)

(add-hook #'after-init-hook #'savehist-mode)

(straight-use-package 'session)
(use-package session
  :defer    t
  :hook ((after-init . session-initialize))
  :init
  (gsetq session-save-file (no-littering-expand-var-file-name ".session")
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
  		 (ivy-history              . 100)
  		 (magit-revision-history   . 50)
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
  		 tags-table-list
  		 kill-ring))))

(straight-use-package 'super-save)
(use-package super-save
  :ghook 'after-init-hook
  :gfhook '(lambda () (remove-hook #'mouse-leave-buffer-hook #'super-save-command))
  :init (gsetq super-save-auto-save-when-idle nil
  	     super-save-remote-files        nil
  	     super-save-hook-triggers       nil
  	     super-save-triggers
  	     '(ibuffer other-window windmove-up windmove-down windmove-left windmove-right next-buffer previous-buffer)))

(straight-use-package 'default-text-scale)
(use-package default-text-scale
  :commands default-text-scale-mode
  :ghook 'after-init-hook)

(straight-use-package 'ace-window)
(use-package ace-window
  :bind (("M-o" . ace-window))
  :config
  (set-face-attribute
   'aw-leading-char-face nil
   :foreground "deep sky blue"
   :weight 'bold
   :height 3.0)
  (set-face-attribute
   'aw-mode-line-face nil
   :inherit 'mode-line-buffer-id
   :foreground "lawn green")
  (gsetq-default cursor-in-non-selected-windows 'hollow)
  (gsetq aw-reverse-frame-list t
       aw-keys '(?a ?s ?d ?f ?j ?k ?l)
       aw-dispatch-always t
       aw-dispatch-alist
       '((?w hydra-window-size/body)
  	 (?o hydra-window-scroll/body)
  	 (?\; hydra-frame-window/body)
  	 (?0 delete-frame)
  	 (?1 delete-other-frames)
  	 (?2 make-frame)
  	 (?x aw-delete-window "Ace - Delete Window")
  	 (?c aw-swap-window "Ace - Swap Window")
  	 (?n aw-flip-window)
  	 (?v aw-split-window-vert "Ace - Split Vert Window")
  	 (?h aw-split-window-horz "Ace - Split Horz Window")
  	 (?\- aw-split-window-vert "Ace - Split Vert Window")
  	 (?\| aw-split-window-horz "Ace - Split Horz Window")
  	 (?m delete-other-windows "Ace - Maximize Window")
  	 (?g delete-other-windows)
  	 (?b balance-windows)
  	 (?u (lambda ()
  	       (progn
  		 (winner-undo)
  		 (setq this-command 'winner-undo)))
  	     (?r winner-redo))))

  (after! hydra
    (defhydra hydra-window-size (:color violet)
      "Windows size"
      ("h" shrink-window-horizontally "shrink horizontal")
      ("j" shrink-window "shrink vertical")
      ("k" enlarge-window "enlarge vertical")
      ("l" enlarge-window-horizontally "enlarge horizontal"))
    (defhydra hydra-window-scroll (:color violet)
      "Scroll other window"
      ("n" joe-scroll-other-window "scroll")
      ("p" joe-scroll-other-window-down "scroll down"))
    (defhydra hydra-frame-window (:color violet :hint nil)
      "
^Delete^                       ^Frame resize^             ^Window^                Window Size^^^^^^   ^Text^                         (__)
_0_: delete-frame              _g_: resize-frame-right    _t_: toggle               ^ ^ _k_ ^ ^        _K_                           (oo)
_1_: delete-other-frames       _H_: resize-frame-left     _e_: ace-swap-win         _h_ ^+^ _l_        ^+^                     /------\\/
_2_: make-frame                _F_: fullscreen            ^ ^                       ^ ^ _j_ ^ ^        _J_                    / |    ||
_d_: kill-and-delete-frame     _n_: new-frame-right       _w_: ace-delete-window    _b_alance^^^^      ^ ^                   *  /\\---/\\  ~~  C-x f ;
"
      ("0" delete-frame :exit t)
      ("1" delete-other-frames :exit t)
      ("2" make-frame  :exit t)
      ("b" balance-windows)
      ("d" kill-and-delete-frame :exit t)
      ("e" ace-swap-window)
      ("F" toggle-frame-fullscreen)   ;; is <f11>
      ("g" resize-frame-right :exit t)
      ("H" resize-frame-left :exit t)  ;; aw-dispatch-alist uses h, I rebind here so hjkl can be used for size
      ("n" new-frame-right :exit t)
      ("r" reverse-windows)
      ("t" toggle-window-spilt)
      ("w" ace-delete-window :exit t)
      ("x" delete-frame :exit t)
      ("K" text-scale-decrease)
      ("J" text-scale-increase)
      ("h" shrink-window-horizontally)
      ("k" shrink-window)
      ("j" enlarge-window)
      ("l" enlarge-window-horizontally)))
  (ace-window-display-mode t))

(straight-use-package 'switch-window)
(use-package switch-window
  :init (gsetq-default switch-window-shortcut-style 'alphabet
  		     switch-window-timeout nil)
  :config
  ;; When splitting window, show (other-buffer) in the new window
  (defun split-window-func-with-other-buffer (split-function)
    "Split window with `SPLIT-FUNCTION'."
    (lambda (&optional arg)
      "Split this window and switch to the new window unless ARG is provided."
      (interactive "P")
      (funcall split-function)
      (let ((target-window (next-window)))
      (set-window-buffer target-window (other-buffer))
      (unless arg
  	(select-window target-window)))))

  (defun toggle-delete-other-windows ()
    "Delete other windows in frame if any, or restore previous window config."
    (interactive)
    (if (and winner-mode
  	   (equal (selected-window) (next-window)))
      (winner-undo)
      (delete-other-windows)))

  (defun split-window-horizontally-instead ()
    "Kill any other windows and re-split such that the current window is on the top half of the frame."
    (interactive)
    (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
      (delete-other-windows)
      (split-window-horizontally)
      (when other-buffer
      (set-window-buffer (next-window) other-buffer))))

  (defun split-window-vertically-instead ()
    "Kill any other windows and re-split such that the current window is on the left half of the frame."
    (interactive)
    (let ((other-buffer (and (next-window) (window-buffer (next-window)))))
      (delete-other-windows)
      (split-window-vertically)
      (when other-buffer
      (set-window-buffer (next-window) other-buffer))))

  ;; Borrowed from http://postmomentum.ch/blog/201304/blog-on-emacs
  (defun nasy/split-window()
    "Split the window to see the most recent buffer in the other window.
  Call a second time to restore the original window configuration."
    (interactive)
    (if (eq last-command 'nasy-split-window)
      (progn
  	(jump-to-register :nasy-split-window)
  	(setq this-command 'nasy-unsplit-window))
      (window-configuration-to-register :nasy/split-window)
      (switch-to-buffer-other-window nil)))

  (general-define-key
   :prefix "C-x"
   "1" 'toggle-delete-other-windows
   "2" (split-window-func-with-other-buffer 'split-window-vertically)
   "3" (split-window-func-with-other-buffer 'split-window-horizontally)
   "|" 'split-window-horizontally-instead
   "_" 'split-window-vertically-instead
   "x" 'nasy/split-window
   "o" 'switch-window))

(straight-use-package 'disable-mouse)

(setq enable-recursive-minibuffers t)

(minibuffer-depth-indicate-mode)

;; https://www.reddit.com/r/emacs/comments/4d8gvt/how_do_i_automatically_close_the_minibuffer_after/
(defun helper/kill-minibuffer ()
  "Exit the minibuffer if it is active."
  (when (and (>= (recursion-depth) 1)
  	 (active-minibuffer-window))
    (abort-recursive-edit)))

(add-hook #'mouse-leave-buffer-hook #'helper/kill-minibuffer)

(straight-use-package 'scratch)

(straight-use-package 'shell)

(straight-use-package 'cmd-to-echo)


(straight-use-package 'command-log-mode)

(straight-use-package 'noflet)

(use-package noflet
  :commands (noflet)
  :defer t)

(defun nasy:shell-command-in-view-mode (start end command &optional output-buffer replace &rest other-args)
  "Put \"*Shell Command Output*\" buffers into view-mode."
  (unless (or output-buffer replace)
    (with-current-buffer "*Shell Command Output*"
      (view-mode 1))))
(advice-add 'shell-command-on-region :after 'nasy:shell-command-in-view-mode)


(straight-use-package 'exec-path-from-shell)
(use-package exec-path-from-shell
  :demand   *is-a-mac*
  :preface
  ;; Non-Forking Shell Command To String
  ;; https://github.com/bbatsov/projectile/issues/1044
  ;;--------------------------------------------------------------------------

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
  	 (get-call-process-args-from-shell-command command)))
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
    (noflet ((shell-command-to-string
  	    (&rest args)
  	    (or (apply 'try-call-process args) (apply this-fn args))))
  	  (apply fn args)))

  (advice-add 'projectile-find-file :around 'call-with-quick-shell-command)
  :init (gsetq shell-command-switch "-ic"
  	     shell-file-name      "zsh")
  :config
  ;; (when nil (message "PATH: %s, INFO: %s" (getenv "PATH")
  ;;                    (getenv "ENVIRONMENT_SETUP_DONE"))
  ;;       (setq exec-path-from-shell-debug t))
  (gsetq exec-path-from-shell-arguments nil
       exec-path-from-shell-check-startup-files nil)
  (add-to-list 'exec-path-from-shell-variables "SHELL")
  (exec-path-from-shell-initialize)
  (add-to-list 'exec-path "~/.pyenv/shims/"))

(when *vterm*
  (straight-use-package 'vterm))

;;----------------------------------------------------------------------------
;; Editor
;;----------------------------------------------------------------------------

(straight-register-package
 '(tree-sitter :host github
  	     :repo "ubolonton/emacs-tree-sitter"
  	     :files ("lisp/*.el" "langs/*.el" "langs/queries")))

(nasy/s-u-p anzu avy diminish
  	  explain-pause-mode
  	  flx
  	  prescient
  	  quick-peek
  	  tree-sitter
  	  which-key)

(when *eldoc-use*
  (nasy/s-u-p *eldoc-use*))

(explain-pause-mode 1)

(use-package anzu
  :defer    t
  :hook ((after-init . global-anzu-mode))
  :bind ([remap query-replace] . anzu-query-replace-regexp))

(use-package autoinsert
  :init
  (define-auto-insert
    '("\\.py" . "Python Language")
    '("Python Language"
      "#!/usr/bin/env python3\n"
      "# -*- coding: utf-8 -*-\n\n"
      "r\"\"\"\n"
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
      "date     : " (format-time-string "%b %e, %Y") "\n"
      "email    : Nasy <nasyxx+python@gmail.com>" "\n"
      "filename : " (file-name-nondirectory (buffer-file-name)) "\n"
      "project  : " (file-name-nondirectory (directory-file-name (or projectile-project-root default-directory))) "\n"
      "license  : GPL-3.0+\n\n"
      "At pick'd leisure\n"
      "  Which shall be shortly, single I'll resolve you,\n"
      "Which to you shall seem probable, of every\n"
      "  These happen'd accidents\n"
      "                          -- The Tempest\n"
      "\"\"\"\n"))

  (define-auto-insert
    '("\\.hs" . "Haskell Language")
    '("Haskell Language"
      "{-\n"
      " Excited without bugs, have fun (\"▔□▔)/hi~♡ Nasy.\n"
      " ------------------------------------------------\n"
      " |             *         *\n"
      " |                  .                .\n"
      " |           .\n"
      " |     *                      ,\n"
      " |                   .\n"
      " |\n"
      " |                               *\n"
      " |          |\\___/|\n"
      " |          )    -(             .              ·\n"
      " |         =\\ -   /=\n"
      " |           )===(       *\n"
      " |          /   - \\\n"
      " |          |-    |\n"
      " |         /   -   \\     0.|.0\n"
      " |  NASY___\\__( (__/_____(\\=/)__+1s____________\n"
      " |  ______|____) )______|______|______|______|_\n"
      " |  ___|______( (____|______|______|______|____\n"
      " |  ______|____\\_|______|______|______|______|_\n"
      " |  ___|______|______|______|______|______|____\n"
      " |  ______|______|______|______|______|______|_\n"
      " |  ___|______|______|______|______|______|____\n\n"
      " At pick'd leisure\n"
      "   Which shall be shortly, single I'll resolve you,\n"
      " Which to you shall seem probable, of every\n"
      "   These happen'd accidents\n"
      "                           -- The Tempest\n"
      "--------------------------------------------------------------------------------\n\n-}\n\n"
      "--------------------------------------------------------------------------------\n-- |\n"
      "-- Filename   : " (file-name-nondirectory (buffer-file-name)) \n
      "-- Project    : " (file-name-nondirectory (directory-file-name (or projectile-project-root default-directory))) \n
      "-- Author     : Nasy\n"
      "-- License    : GPL-3.0+\n--\n"
      "-- Maintainer : Nasy <nasyxx+haskell@gmail.com>\n"
      "--\n--\n--\n--------------------------------------------------------------------------------\n")))

(use-package avy
  :defer t
  :init
  (general-define-key
   "C-:"     #'avy-goto-char
   "C-'"     #'avy-goto-char-2
   "C-`"     #'avy-goto-char-2
   "M-g e"   #'avy-goto-word-0
   "M-g w"   #'avy-goto-word-1
   "C-~"     #'avy-goto-word-1
   "C-c C-j" #'avy-resume)
  (when *dvorak*
    (gsetq avy-keys '(?a ?o ?e ?u ?i ?d ?h ?t ?n ?s))))

(straight-use-package 'beginend)
(use-package beginend
  :hook ((after-init . beginend-global-mode)))

(straight-use-package 'better-jumper)
(use-package better-jumper
  :defer t
  :hook (((org-mode org-src-mode prog-mode) . turn-on-better-jumper-mode)
       (better-jumper-post-jump           . recenter))
  :init
  (general-define-key
   [remap xref-pop-marker-stack] #'better-jumper-jump-backward))

;; Emacs to carbon.now.sh integration
;; https://github.com/veelenga/carbon-now-sh.el
;; (carbon-now-sh)
(straight-use-package 'carbon-now-sh)

(straight-use-package 'cheat-sh)

(nasy/s-u-p
 company
 company-dict
 company-flx
 company-math
 company-prescient
 company-quickhelp
 company-tabnine
 prescient)
(when *c-box*
  (straight-use-package 'company-box))

;; Borrow from doom emacs.

;;;###autoload
(defvar nasy/company-backend-alist
 '((text-mode company-dabbrev company-yasnippet company-ispell company-files)
   (prog-mode company-capf company-yasnippet company-files)
   (conf-mode company-capf company-dabbrev-code company-yasnippet company-files))
 "An alist matching modes to company backends. The backends for any mode is
built from this.")


;;;###autoload
(defun nasy/add-company-backend (modes &rest backends)
 "Prepends BACKENDS (in order) to `company-backends' in MODES.

MODES should be one symbol or a list of them, representing major or minor modes.
This will overwrite backends for MODES on consecutive uses.

If the car of BACKENDS is nil, unset the backends for MODES.
Examples:
 (nasy/add-company-backend 'js2-mode
   'company-tide 'company-yasnippet)
 (nasy/add-company-backend 'sh-mode
   '(company-shell :with company-yasnippet))
 (nasy/add-company-backend '(c-mode c++-mode)
   '(:separate company-irony-c-headers company-irony))
 (nasy/add-company-backend 'sh-mode nil)  ; unsets backends for sh-mode"

 (declare (indent defun))
 (dolist (mode (nasy-enlist modes))
   (if (null (car backends))
       (setq nasy/company-backend-alist
  	   (delq (assq mode nasy/company-backend-alist)
  		 nasy/company-backend-alist))
     (setf (alist-get mode nasy/company-backend-alist)
  	 backends))))


;;;###autoload
(defun nasy/company-backends ()
 (let (backends)
   (let ((mode major-mode)
       (modes (list major-mode)))
     (while (setq mode (get mode 'derived-mode-parent))
       (push mode modes))
     (dolist (mode modes)
       (dolist (backend (append (cdr (assq mode nasy/company-backend-alist))
  			      (default-value 'company-backends)))
       (push backend backends)))
     (delete-dups
      (append (cl-loop for (mode . backends) in nasy/company-backend-alist
  		     if (or (eq major-mode mode)  ; major modes
  			    (and (boundp mode)
  				 (symbol-value mode))) ; minor modes
  		     append backends)
  	    (nreverse backends))))))


;;;###autoload
(defun nasy/company-init-backends-h ()
 "Set `company-backends' for the current buffer."
 (if (not company-mode)
     (remove-hook 'change-major-mode-after-body-hook #'nasy/company-init-backends-h 'local)
   (unless (eq major-mode 'fundamental-mode)
     (setq-local company-backends (nasy/company-backends)))
   (add-hook 'change-major-mode-after-body-hook #'nasy/company-init-backends-h nil 'local)))

(put 'nasy/company-init-backends-h 'permanent-local-hook t)


;;;###autoload
(defun nasy/company-complete ()
  "Bring up the completion popup. If only one result, complete it."
  (interactive)
  (require 'company)
  (when (ignore-errors
  	(/= (point)
  	    (cdr (bounds-of-thing-at-point 'symbol))))
    (save-excursion (insert " ")))
  (when (and (company-manual-begin)
  	   (= company-candidates-length 1))
    (company-complete-common)))

(use-package company
  :defer t
  :commands (nasy/company-backends
  	   nasy/company-init-backends-h
  	   nasy/company-has-completion-p
  	   nasy/company-toggle-auto-completion
  	   nasy/company-complete
  	   nasy/company-dabbrev
  	   nasy/company-whole-lines
  	   nasy/company-dict-or-keywords
  	   nasy/company-dabbrev-code-previous)
  :preface
  (defun nasy/company-has-completion-p ()
    "Return non-nil if a completion candidate exists at point."
    (and (company-manual-begin)
       (= company-candidates-length 1)))

  (defun nasy/company-toggle-auto-completion ()
    "Toggle as-you-type code completion."
    (interactive)
    (require 'company)
    (setq company-idle-delay (unless company-idle-delay 0.2))
    (message "Auto completion %s"
  	   (if company-idle-delay "enabled" "disabled")))

  (defun nasy/company-complete ()
    "Bring up the completion popup. If only one result, complete it."
    (interactive)
    (require 'company)
    (when (ignore-errors
  	  (/= (point)
  	      (cdr (bounds-of-thing-at-point 'symbol))))
      (save-excursion (insert " ")))
    (when (and (company-manual-begin)
  	     (= company-candidates-length 1))
      (company-complete-common)))

  (defun nasy/company-dabbrev ()
    "Invokes `company-dabbrev-code' in prog-mode buffers and `company-dabbrev'
  everywhere else."
    (interactive)
    (call-interactively
     (if (derived-mode-p 'prog-mode)
       #'company-dabbrev-code
       #'company-dabbrev)))

  (defun nasy/company-whole-lines (command &optional arg &rest ignored)
    "`company-mode' completion backend that completes whole-lines, akin to vim's
  C-x C-l."
    (interactive (list 'interactive))
    (require 'company)
    (pcase command
      (`interactive (company-begin-backend 'nasy/company-whole-lines))
      (`prefix      (company-grab-line "^[\t\s]*\\(.+\\)" 1))
      (`candidates
       (all-completions
      arg
      (delete-dups
       (split-string
  	(replace-regexp-in-string
  	 "^[\t\s]+" ""
  	 (concat (buffer-substring-no-properties (point-min) (line-beginning-position))
  		 (buffer-substring-no-properties (line-end-position) (point-max))))
  	"\\(\r\n\\|[\n\r]\\)" t))))))

  (defun nasy/company-dict-or-keywords ()
    "`company-mode' completion combining `company-dict' and `company-keywords'."
    (interactive)
    (require 'company-dict)
    (require 'company-keywords)
    (let ((company-backends '((company-keywords company-dict))))
      (call-interactively #'company-complete)))

  (defun nasy/company-dabbrev-code-previous ()
    "TODO"
    (interactive)
    (require 'company-dabbrev)
    (let ((company-selection-wrap-around t))
      (call-interactively #'nasy/company-dabbrev)
      (company-select-previous-or-abort)))

  :init
  (add-to-list 'completion-styles 'initials t)
  (gsetq company-tooltip-limit             10
       company-dabbrev-downcase          nil
       company-dabbrev-ignore-case       t
       company-global-modes
       '(not erc-mode message-mode help-mode gud-mode eshell-mode)
       company-frontends
       '(company-pseudo-tooltip-frontend
  	 company-echo-metadata-frontend)
       company-dabbrev-other-buffers     'all
       company-tooltip-align-annotations t
       company-minimum-prefix-length     2
       company-idle-delay                .2
       company-tooltip-idle-delay        .2
       company-require-match             'never)
  :hook ((company-mode . nasy/company-init-backends-h)
       (prog-mode    . company-mode))
  :bind (("M-/"     . company-files)
       ("M-C-/"   . nasy/company-complete)
       ("C-<tab>" . nasy/company-complete)
       :map company-mode-map
       ("M-/" . nasy/company-complete)
       :map company-active-map
       ("M-/" . company-other-backend)
       ("C-n" . company-select-next)
       ("C-p" . company-select-previous))
  :config
  (setq company-backends '(company-capf))
  (defvar nasy/prev-whitespace-mode nil)
  (make-variable-buffer-local 'nasy/prev-whitespace-mode)
  (defvar nasy/show-trailing-whitespace nil)
  (make-variable-buffer-local 'nasy/show-trailing-whitespace)
  (defun pre-popup-draw ()
    "Turn off whitespace mode before showing company complete tooltip"
    (if whitespace-mode
      (progn
  	(gsetq my-prev-whitespace-mode t)
  	(whitespace-mode -1)))
    (gsetq nasy/show-trailing-whitespace show-trailing-whitespace)
    (gsetq show-trailing-whitespace nil))
  (defun post-popup-draw ()
    "Restore previous whitespace mode after showing company tooltip"
    (if nasy/prev-whitespace-mode
      (progn
  	(whitespace-mode 1)
  	(gsetq nasy/prev-whitespace-mode nil)))
    (gsetq show-trailing-whitespace nasy/show-trailing-whitespace))
  (advice-add 'company-pseudo-tooltip-unhide :before #'pre-popup-draw)
  (advice-add 'company-pseudo-tooltip-hide :after #'post-popup-draw))

(use-package company-prescient
  :defer t
  :ghook 'company-prescient-mode)

(use-package company-quickhelp
  :defer t
  :bind (:map company-active-map
  	    ("C-c h" . company-quickhelp-manual-begin))
  :config
  (after-x 'company
  	      (company-quickhelp-mode))
  (gsetq pos-tip-use-relative-coordinates t))

(gsetq company-tabnine-log-file-path
       (concat company-tabnine-binaries-folder "/log"))

(after-x 'company
  (company-flx-mode +1))

(when *c-box*
  (use-package company-box
    :defer t
    :ghook 'company-mode-hook
    :config
    (gsetq company-box-show-single-candidate t
  	 company-box-backends-colors       nil
  	 company-box-max-candidates        50
  	 company-box-icons-alist           'company-box-icons-all-the-icons
  	 company-box-icons-functions
  	 (cons #'nasy/company-box-icons--elisp-fn
  	       (delq 'company-box-icons--elisp
  		     company-box-icons-functions)))

    (after-x 'all-the-icons
      (gsetq
       company-box-icons-all-the-icons
       (let ((all-the-icons-scale-factor 0.8))
       `((Unknown       . ,(all-the-icons-material "find_in_page"             :face 'all-the-icons-purple))
  	 (Text          . ,(all-the-icons-material "text_fields"              :face 'all-the-icons-green))
  	 (Method        . ,(all-the-icons-material "functions"                :face 'all-the-icons-yellow))
  	 (Function      . ,(all-the-icons-material "functions"                :face 'all-the-icons-yellow))
  	 (Constructor   . ,(all-the-icons-material "functions"                :face 'all-the-icons-yellow))
  	 (Field         . ,(all-the-icons-material "functions"                :face 'all-the-icons-yellow))
  	 (Variable      . ,(all-the-icons-material "adjust"                   :face 'all-the-icons-blue))
  	 (Class         . ,(all-the-icons-material "class"                    :face 'all-the-icons-cyan))
  	 (Interface     . ,(all-the-icons-material "settings_input_component" :face 'all-the-icons-cyan))
  	 (Module        . ,(all-the-icons-material "view_module"              :face 'all-the-icons-cyan))
  	 (Property      . ,(all-the-icons-material "settings"                 :face 'all-the-icons-lorange))
  	 (Unit          . ,(all-the-icons-material "straighten"               :face 'all-the-icons-red))
  	 (Value         . ,(all-the-icons-material "filter_1"                 :face 'all-the-icons-red))
  	 (Enum          . ,(all-the-icons-material "plus_one"                 :face 'all-the-icons-lorange))
  	 (Keyword       . ,(all-the-icons-material "filter_center_focus"      :face 'all-the-icons-lgreen))
  	 (Snippet       . ,(all-the-icons-material "short_text"               :face 'all-the-icons-lblue))
  	 (Color         . ,(all-the-icons-material "color_lens"               :face 'all-the-icons-green))
  	 (File          . ,(all-the-icons-material "insert_drive_file"        :face 'all-the-icons-green))
  	 (Reference     . ,(all-the-icons-material "collections_bookmark"     :face 'all-the-icons-silver))
  	 (Folder        . ,(all-the-icons-material "folder"                   :face 'all-the-icons-green))
  	 (EnumMember    . ,(all-the-icons-material "people"                   :face 'all-the-icons-lorange))
  	 (Constant      . ,(all-the-icons-material "pause_circle_filled"      :face 'all-the-icons-blue))
  	 (Struct        . ,(all-the-icons-material "streetview"               :face 'all-the-icons-blue))
  	 (Event         . ,(all-the-icons-material "event"                    :face 'all-the-icons-yellow))
  	 (Operator      . ,(all-the-icons-material "control_point"            :face 'all-the-icons-red))
  	 (TypeParameter . ,(all-the-icons-material "class"                    :face 'all-the-icons-red))
  	 (Template      . ,(all-the-icons-material "short_text"               :face 'all-the-icons-green))
  	 (ElispFunction . ,(all-the-icons-material "functions"                :face 'all-the-icons-red))
  	 (ElispVariable . ,(all-the-icons-material "check_circle"             :face 'all-the-icons-blue))
  	 (ElispFeature  . ,(all-the-icons-material "stars"                    :face 'all-the-icons-orange))
  	 (ElispFace     . ,(all-the-icons-material "format_paint"             :face 'all-the-icons-pink))))))

    (defun nasy/company-box-icons--elisp-fn (candidate)
      (when (derived-mode-p 'emacs-lisp-mode)
      (let ((sym (intern candidate)))
  	(cond ((fboundp  sym) 'ElispFunction)
  	      ((boundp   sym) 'ElispVariable)
  	      ((featurep sym) 'ElispFeature)
  	      ((facep    sym) 'ElispFace)))))

    (defadvice! nasy/company-remove-scrollbar-a (orig-fn &rest args)
      "This disables the company-box scrollbar, because:
https://github.com/sebastiencs/company-box/issues/44"
      :around #'company-box--update-scrollbar
      (cl-letf (((symbol-function #'display-buffer-in-side-window)
  	       (symbol-function #'ignore)))
      (apply orig-fn args)))))

(straight-use-package 'dash)

(straight-use-package 'dash-functional)

(use-package dired
  :init
  (let ((gls (executable-find "gls")))
    (when gls (setq insert-directory-program gls)))
  (setq dired-recursive-deletes 'top)
  :bind (:map dired-mode-map
  	    ([mouse-2] . dired-find-file             )
  	    ("C-c C-p" . wdired-change-to-wdired-mode)))

(straight-use-package 'diredfl)
(use-package diredfl
  :after dired
  :hook ((after-init . diredfl-global-mode)))

(use-package uniquify
  :init  ;; nicer naming of buffers for files with identical names
  (gsetq uniquify-buffer-name-style   'reverse
       uniquify-separator           " • "
       uniquify-after-kill-buffer-p t
       uniquify-ignore-buffers-re   "^\\*"))

(straight-use-package 'diff-hl)
(use-package diff-hl
  :after dired
  :hook ((dired-mode . diff-hl-dired-mode)
       (magit-post-refresh . diff-hl-magit-post-refresh)))

(straight-use-package 'dired-hacks-utils)

(straight-use-package 'dired-filter)
(use-package dired-filter
  :after    dired
  :bind (:map dired-mode-map
  	    ("/" . dired-filter-map))
  :hook ((dired-mode . dired-filter-mode)
       (dired-mode . dired-filter-group-mode))
  :init (gsetq dired-filter-revert 'never
  	     dired-filter-group-saved-groups
  	     '(("default"
  		("Git"
  		 (directory . ".git")
  		 (file . ".gitignore"))
  		("Directory"
  		 (directory))
  		("PDF"
  		 (extension . "pdf"))
  		("LaTeX"
  		 (extension "tex" "bib"))
  		("Source"
  		 (extension "c" "cpp" "hs" "rb" "py" "r" "cs" "el" "lisp" "html" "js" "css"))
  		("Doc"
  		 (extension "md" "rst" "txt"))
  		("Org"
  		 (extension . "org"))
  		("Archives"
  		 (extension "zip" "rar" "gz" "bz2" "tar"))
  		("Images"
  		 (extension "jpg" "JPG" "webp" "png" "PNG" "jpeg" "JPEG" "bmp" "BMP" "TIFF" "tiff" "gif" "GIF"))))))

(when (executable-find "avfsd")
  (straight-use-package 'dired-avfs))

(straight-use-package 'dired-rainbow)
(use-package dired-rainbow
  :after dired
  :config
  (dired-rainbow-define-chmod directory "#6cb2eb" "d.*")
  (dired-rainbow-define html        "#eb5286" ("css" "less" "sass" "scss" "htm" "html" "jhtm" "mht" "eml" "mustache" "xhtml"))
  (dired-rainbow-define xml         "#f2d024" ("xml" "xsd" "xsl" "xslt" "wsdl" "bib" "json" "msg" "pgn" "rss" "yaml" "yml" "rdata"))
  (dired-rainbow-define document    "#9561e2" ("docm" "doc" "docx" "odb" "odt" "pdb" "pdf" "ps" "rtf" "djvu" "epub" "odp" "ppt" "pptx"))
  (dired-rainbow-define markdown    "#ffed4a" ("org" "etx" "info" "markdown" "md" "mkd" "nfo" "pod" "rst" "tex" "textfile" "txt"))
  (dired-rainbow-define database    "#6574cd" ("xlsx" "xls" "csv" "accdb" "db" "mdb" "sqlite" "nc"))
  (dired-rainbow-define media       "#de751f" ("mp3" "mp4" "MP3" "MP4" "avi" "mpeg" "mpg" "flv" "ogg" "mov" "mid" "midi" "wav" "aiff" "flac"))
  (dired-rainbow-define image       "#f66d9b" ("tiff" "tif" "cdr" "gif" "ico" "jpeg" "jpg" "png" "psd" "eps" "svg"))
  (dired-rainbow-define log         "#c17d11" ("log"))
  (dired-rainbow-define shell       "#f6993f" ("awk" "bash" "bat" "sed" "sh" "zsh" "vim"))
  (dired-rainbow-define interpreted "#38c172" ("py" "ipynb" "rb" "pl" "t" "msql" "mysql" "pgsql" "sql" "r" "clj" "cljs" "scala" "js"))
  (dired-rainbow-define compiled    "#4dc0b5" ("asm" "cl" "lisp" "el" "c" "h" "c++" "h++" "hpp" "hxx" "m" "cc" "cs" "cp" "cpp" "go" "f" "for" "ftn" "f90" "f95" "f03" "f08" "s" "rs" "hi" "hs" "pyc" ".java"))
  (dired-rainbow-define executable  "#8cc4ff" ("exe" "msi"))
  (dired-rainbow-define compressed  "#51d88a" ("7z" "zip" "bz2" "tgz" "txz" "gz" "xz" "z" "Z" "jar" "war" "ear" "rar" "sar" "xpi" "apk" "xz" "tar"))
  (dired-rainbow-define packaged    "#faad63" ("deb" "rpm" "apk" "jad" "jar" "cab" "pak" "pk3" "vdf" "vpk" "bsp"))
  (dired-rainbow-define encrypted   "#ffed4a" ("gpg" "pgp" "asc" "bfe" "enc" "signature" "sig" "p12" "pem"))
  (dired-rainbow-define fonts       "#6cb2eb" ("afm" "fon" "fnt" "pfb" "pfm" "ttf" "otf"))
  (dired-rainbow-define partition   "#e3342f" ("dmg" "iso" "bin" "nrg" "qcow" "toast" "vcd" "vmdk" "bak"))
  (dired-rainbow-define vc          "#0074d9" ("git" "gitignore" "gitattributes" "gitmodules"))
  (dired-rainbow-define-chmod executable-unix "#38c172" "-.*x.*"))

(straight-use-package 'dired-subtree)

(straight-use-package 'dired-ranger)

(straight-use-package 'dired-narrow)
(use-package dired-narrow
  :after    dired
  :bind (:map dired-narrow-map
  	    ("<down>"  . dired-narrow-next-file)
  	    ("<up>"    . dired-narrow-previous-file)
  	    ("<right>" . dired-narrow-enter-directory)))

(straight-use-package 'dired-collapse)
(use-package dired-collapse
  :ghook 'dired-mode-hook)

(straight-use-package 'easy-kill)
(use-package easy-kill
  :bind (([remap kill-ring-save] . easy-kill)
       ([remap mark-sexp]      . easy-mark)))

(straight-use-package 'thingopt)

(use-package eldoc-overlay
  :if (eq *eldoc-use* 'eldoc-overlay)
  :defer t
  :ghook 'eldoc-mode-hook)

(use-package eldoc-box
  :if (eq *eldoc-use* 'eldoc-box)
  :defer t
  :hook ((eldoc-mode . eldoc-box-hover-mode)
       (eldoc-mode . eldoc-box-hover-at-point-mode)))

(straight-use-package 'expand-region)
(general-define-key
 "C-=" #'er/expand-region)

(straight-use-package 'unfill)
(use-package unfill
  :bind (("M-q" . unfill-toggle)))

(straight-use-package 'visual-fill-column)
(use-package visual-fill-column
  :preface
  (defun maybe-adjust-visual-fill-column ()
    "Readjust visual fill column when the global font size is modified.
This is helpful for writeroom-mode, in particular."
    (if visual-fill-column-mode
      (add-hook 'after-setting-font-hook 'visual-fill-column--adjust-window nil t)
      (remove-hook 'after-setting-font-hook 'visual-fill-column--adjust-window t)))
  :hook ((visual-line-mode        . visual-fill-column-mode        )
       (visual-fill-column-mode . maybe-adjust-visual-fill-column)))

(straight-use-package 'find-file-in-project)
(gsetq ffip-use-rust-fd t)

(nasy/s-u-p flycheck
  	  flycheck-package)
(when *flycheck-inline*
  (nasy/s-u-p quick-peek
  	    flycheck-inline))

;;;###autoload
(defun save-buffer-maybe-show-errors ()
  "Save buffer and show errors if any."
  (interactive)
  (save-buffer)
  (when (not flycheck-current-errors)
    (flycheck-list-errors)))

(use-package flycheck
  :commands (flycheck-mode
  	   flycheck-next-error
  	   flycheck-previous-error
  	   flycheck-add-next-checker
  	   save-buffer-maybe-show-errors)
  ;; :bind (("C-x C-s" . save-buffer-maybe-show-errors))
  :hook ((prog-mode . flycheck-mode))
  :init (gsetq flycheck-display-errors-function
  	     #'flycheck-display-error-messages-unless-error-list
  	     flycheck-check-syntax-automatically '(save idle-change mode-enabled)
  	     flycheck-display-errors-delay       0.25)
  :general
  (:keymaps 'flycheck-error-list-mode-map
  	  "C-n" #'flycheck-error-list-next-error
  	  "C-p" #'flycheck-error-list-previous-error
  	  "RET" #'flycheck-error-list-goto-error
  	  [return]  #'flycheck-error-list-goto-error)
  :config (defalias 'show-error-at-point-soon
  	  'flycheck-show-error-at-point)
  (add-to-list 'flycheck-emacs-lisp-checkdoc-variables 'sentence-end-double-space))

(use-package flycheck-package
  :after flycheck
  :init
  (after! elisp-mode
    (flycheck-package-setup)))

(use-package flycheck-inline
  :defer t
  :preface
  (defun nasy/flycheck-inline-init ()
    "Flycheck-inline-mode init function"
    (gsetq flycheck-inline-display-function
  	 (lambda (msg pos)
  	   (let* ((ov (quick-peek-overlay-ensure-at pos))
  		  (contents (quick-peek-overlay-contents ov)))
  	     (setf (quick-peek-overlay-contents ov)
  		   (concat contents (when contents "\n") msg))
  	     (quick-peek-update ov)))
  	 flycheck-inline-clear-function #'quick-peek-hide))
  :ghook 'flycheck-mode-hook
  :gfhook 'nasy/flycheck-inline-init)

;; (straight-use-package 'fuz)
(use-package fuz
  :disabled t
  :defer t
  :init
  (defun load-fuz ()
    "Load fuz.el."
    (require 'fuz)
    (unless (require 'fuz-core nil t)
      (fuz-build-and-load-dymod)))
  :hook ((after-init . load-fuz)))

(straight-use-package 'grab-mac-link)

(gsetq-default grep-highlight-matches t
  	     grep-scroll-output t)

(when *is-a-mac*
  (gsetq-default locate-command "mdfind"))

(straight-use-package 'color-identifiers-mode)
(use-package color-identifiers-mode
  :defer t
  :ghook prog-mode-hook)

(straight-use-package 'hl-line)
(use-package hl-line
  :defer t
  :hook ((after-init . global-hl-line-mode)))

(when *highlight-indent-guides*
  (straight-use-package 'highlight-indent-guides)
  (use-package highlight-indent-guides
    :init (gsetq highlight-indent-guides-responsive nil
  	       highlight-indent-guides-delay      0.5)
    :ghook '(prog-mode-hook text-mode-hook org-mode-hook)))

(straight-use-package 'rainbow-mode)
(use-package rainbow-mode
  :hook (((after-init
  	 text-mode
  	 org-mode
  	 css-mode
  	 html-mode
  	 prog-mode). rainbow-mode))
  :diminish rainbow-mode)

(straight-use-package 'helpful)
(use-package helpful
  :bind (("C-c C-d" . helpful-at-point))
  :init (general-define-key
       :prefix "C-h"
       "f" 'helpful-callable
       "v" 'helpful-variable
       "k" 'helpful-key
       "F" 'helpful-function
       "C" 'helpful-command))

(straight-use-package 'htmlize)
(use-package htmlize
  :defer t
  :init (gsetq htmlize-pre-style t))

(straight-use-package 'hydra)
(use-package hydra
  :defer t
  :config
  (general-define-key
   :prefix "C-x"
   "9" 'hydra-unicode/body)
  (general-define-key
   :keymaps 'dired-mode-map
   "." 'hydra-dired/body)
  ;; insert unicode
  (defun nasy:insert-unicode (unicode-name)
    "Same as C-x 8 enter UNICODE-NAME."
    (insert-char (gethash unicode-name (ucs-names))))
  (defhydra hydra-unicode (:hint nil)
    "
    Unicode  _e_ €  _s_ ZERO WIDTH SPACE
  	   _f_ ♀  _o_ °   _m_ µ
  	   _r_ ♂  _a_ →   _l_ λ
    "
    ("e" (nasy:insert-unicode "EURO SIGN"))
    ("r" (nasy:insert-unicode "MALE SIGN"))
    ("f" (nasy:insert-unicode "FEMALE SIGN"))
    ("s" (nasy:insert-unicode "ZERO WIDTH SPACE"))
    ("o" (nasy:insert-unicode "DEGREE SIGN"))
    ("a" (nasy:insert-unicode "RIGHTWARDS ARROW"))
    ("m" (nasy:insert-unicode "MICRO SIGN"))
    ("l" (nasy:insert-unicode "GREEK SMALL LETTER LAMBDA")))


  (defhydra hydra-dired (:hint nil :color pink)
    "
  _+_ mkdir          _v_iew           _m_ark             _(_ details        _i_nsert-subdir    wdired
  _C_opy             _O_ view other   _U_nmark all       _)_ omit-mode      _$_ hide-subdir    C-x C-q : edit
  _D_elete           _o_pen other     _u_nmark           _l_ redisplay      _w_ kill-subdir    C-c C-c : commit
  _R_ename           _M_ chmod        _t_oggle           _g_ revert buf     _e_ ediff          C-c ESC : abort
  _Y_ rel symlink    _G_ chgrp        _E_xtension mark   _s_ort             _=_ pdiff
  _S_ymlink          ^ ^              _F_ind marked      _._ toggle hydra   \\ flyspell
  _r_sync            ^ ^              ^ ^                ^ ^                _?_ summary
  _z_ compress-file  _A_ find regexp
  _Z_ compress       _Q_ repl regexp

  T - tag prefix
  "
    ("\\" dired-do-ispell)
    ("(" dired-hide-details-mode)
    (")" dired-omit-mode)
    ("+" dired-create-directory)
    ("=" diredp-ediff)         ;; smart diff
    ("?" dired-summary)
    ("$" diredp-hide-subdir-nomove)
    ("A" dired-do-find-regexp)
    ("C" dired-do-copy)        ;; Copy all marked files
    ("D" dired-do-delete)
    ("E" dired-mark-extension)
    ("e" dired-ediff-files)
    ("F" dired-do-find-marked-files)
    ("G" dired-do-chgrp)
    ("g" revert-buffer)        ;; read all directories again (refresh)
    ("i" dired-maybe-insert-subdir)
    ("l" dired-do-redisplay)   ;; relist the marked or singel directory
    ("M" dired-do-chmod)
    ("m" dired-mark)
    ("O" dired-display-file)
    ("o" dired-find-file-other-window)
    ("Q" dired-do-find-regexp-and-replace)
    ("R" dired-do-rename)
    ("r" dired-do-rsynch)
    ("S" dired-do-symlink)
    ("s" dired-sort-toggle-or-edit)
    ("t" dired-toggle-marks)
    ("U" dired-unmark-all-marks)
    ("u" dired-unmark)
    ("v" dired-view-file)      ;; q to exit, s to search, = gets line #
    ("w" dired-kill-subdir)
    ("Y" dired-do-relsymlink)
    ("z" diredp-compress-this-file)
    ("Z" dired-do-compress)
    ("q" nil)
    ("." nil :color blue)))

(use-package ibuffer
  :bind (("C-x C-b" . ibuffer))
  :preface
  (defun ibuffer-switch-to-normal ()
    "ibuffer swith to normal filter groups."
    (ibuffer-switch-to-saved-filter-groups "Normal"))
  :init
  (gsetq ibuffer-saved-filter-groups
       '(("Normal"
  	  ("Dired"      (mode . dired-mode))
  	  ("Emacs"     (or
  			(name . "^\\*dashboard\\*$" )
  			(name . "^\\*scratch\\*$"   )
  			(name . "^\\*Messages\\*$"  )
  			(name . "^\\*Backtrace\\*$" )))
  	  ("Term"       (mode . vterm-mode))
  	  ("Text"      (or
  			(mode . org-mode)
  			(mode . markdown)
  			(mode . rst-mode)
  			(mode . text-mode)))
  	  ("TeX"        (mode . tex-mode))
  	  ("Languages" (or
  			(mode . emacs-lisp-mode)
  			(mode . haskell-mode)
  			(mode . javascript-mode)
  			(mode . lisp-mode)
  			(mode . python-mode)
  			(mode . ruby-mode)
  			(mode . rust-mode)
  			(mode . html-mode)
  			(mode . css-mode)
  			(mode . prog-mode)))
  	  ("GNUs"      (or
  			(mode . message-mode)
  			(mode . bbdb-mode)
  			(mode . mail-mode)
  			(mode . gnus-group-mode)
  			(mode . gnus-summary-mode)
  			(mode . gnus-article-mode)
  			(name . "^\\.bbdb$")
  			(name . "^\\.newsrc-dribble")))
  	  ("Magit"      (name . "^magit"))
  	  ("Help"      (or
  			(name . "^\\*Help\\*$")
  			(name . "^\\*Apropos\\*$")
  			(name . "^\\*info\\*$")
  			(name . "^\\*helpful")))
  	  ("Custom"    (or
  			(mode . custom-mode)
  			(name . "^\\*Customize")))
  	  ("Helm"       (mode . helm-major-mode))
  	  ))
       ibuffer-show-empty-filter-groups nil
       ibuffer-default-sorting-mode     'filename/process)
  :hook ((ibuffer-mode . ibuffer-switch-to-normal)))

(straight-use-package 'ibuffer-vc)

(straight-use-package 'all-the-icons-ibuffer)

(use-package all-the-icons-ibuffer
  :defer t
  :ghook 'after-init-hook)

(use-package ibuffer
  :defer t
  :config
  (define-ibuffer-column size-h
    (:name "Size" :inline t)
    (file-size-human-readable (buffer-size)))
  (setq
   ibuffer-formats
   '((mark modified read-only vc-status-mini " "
  	 (name 22 22 :left :elide)
  	 " "
  	 (size-h 9 -1 :right)
  	 " "
  	 (mode 12 12 :left :elide)
  	 " "
  	 vc-relative-file)
     (mark modified read-only vc-status-mini " "
  	 (name 22 22 :left :elide)
  	 " "
  	 (size-h 9 -1 :right)
  	 " "
  	 (mode 14 14 :left :elide)
  	 " "
  	 (vc-status 12 12 :left)
  	 " "
  	 vc-relative-file))))

(straight-use-package 'imenu-list)
(use-package imenu-list
  :bind (("C-." . imenu-list-smart-toggle))
  :init (setq imenu-list-auto-resize t))

(straight-use-package 'indent-tools)
(use-package indent-tools
  :bind (("C-c TAB" . indent-tools-hydra/body)))

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
  	  (setq isearch-regexp    t
  		isearch-string    (regexp-quote sym)
  		isearch-message   (mapconcat 'isearch-text-char-description isearch-string "")
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

  :init
  (general-define-key
   :keymaps 'isearch-mode-map
   [remap isearch-delete-char] #'isearch-del-char
   "C-w"                       #'isearch-yank-symbol
   [(control return)]              #'isearch-exit-other-end
   "C-o"                       #'isearch-occur))

(straight-use-package 'swiper)
(straight-use-package 'ivy)
(straight-use-package 'ivy-xref)
(straight-use-package 'ivy-hydra)
(straight-use-package 'counsel)

(straight-use-package 'counsel-projectile)

(straight-use-package 'prescient)
(straight-use-package 'ivy-prescient)

(straight-use-package 'ivy-rich)
(straight-use-package 'all-the-icons-ivy-rich)

;;; lisp/autoload/ivy.el -*- lexical-binding: t; -*-

(defun nasy/ivy-is-workspace-buffer-p (buffer)
  (let ((buffer (car buffer)))
    (when (stringp buffer)
    (setq buffer (get-buffer buffer)))
    (nasy/workspace-contains-buffer-p buffer)))

(defun nasy/ivy-is-workspace-other-buffer-p (buffer)
  (let ((buffer (car buffer)))
    (when (stringp buffer)
    (setq buffer (get-buffer buffer)))
    (and (not (eq buffer (current-buffer)))
       (nasy/workspace-contains-buffer-p buffer))))

;;;###autoload
(defun nasy/ivy-rich-buffer-name (candidate)
  "Display the buffer name.
Buffers that are considered unreal (see `nasy-real-buffer-p') are dimmed with
`nasy/ivy-buffer-unreal-face'."
  (let ((b (get-buffer candidate)))
    (when (null uniquify-buffer-name-style)
    (setq candidate (replace-regexp-in-string "<[0-9]+>$" "" candidate)))
    (cond ((ignore-errors
  	 (file-remote-p
  	  (buffer-local-value 'default-directory b)))
       (ivy-append-face candidate 'ivy-remote))
      ((nasy-unreal-buffer-p b)
       (ivy-append-face candidate nasy/ivy-buffer-unreal-face))
      ((not (buffer-file-name b))
       (ivy-append-face candidate 'ivy-subdir))
      ((buffer-modified-p b)
       (ivy-append-face candidate 'ivy-modified-buffer))
      (candidate))))

;;;###autoload
(defun nasy/ivy-rich-buffer-icon (candidate)
  "Display the icon for CANDIDATE buffer."
  ;; NOTE This is inspired by `all-the-icons-ivy-buffer-transformer', minus the
  ;; buffer name and extra padding as those are handled by `ivy-rich'.
  (propertize "\t" 'display
  	  (if-let* ((buffer (get-buffer candidate))
  		    (mode (buffer-local-value 'major-mode buffer)))
  	      (or
  	       (all-the-icons-ivy--icon-for-mode mode)
  	       (all-the-icons-ivy--icon-for-mode (get mode 'derived-mode-parent))
  	       (funcall
  		all-the-icons-ivy-family-fallback-for-buffer
  		all-the-icons-ivy-name-fallback-for-buffer))
  	    (all-the-icons-icon-for-file candidate))))

;;;###autoload
(defun nasy/ivy-rich-describe-variable-transformer (cand)
  "Previews the value of the variable in the minibuffer"
  (let* ((sym (intern cand))
       (val (and (boundp sym) (symbol-value sym)))
       (print-level 3))
    (replace-regexp-in-string
     "[\n\t\^[\^M\^@\^G]" " "
     (cond ((booleanp val)
  	(propertize (format "%s" val) 'face
  		    (if (null val)
  			'font-lock-comment-face
  		      'success)))
       ((symbolp val)
  	(propertize (format "'%s" val)
  		    'face 'highlight-quoted-symbol))
       ((keymapp val)
  	(propertize "<keymap>" 'face 'font-lock-constant-face))
       ((listp val)
  	(prin1-to-string val))
       ((stringp val)
  	(propertize (format "%S" val) 'face 'font-lock-string-face))
       ((numberp val)
  	(propertize (format "%s" val) 'face 'highlight-numbers-number))
       ((format "%s" val)))
     t)))


;;
;; Library

(defun nasy/ivy/switch-buffer-preview ()
  (let (ivy-use-virtual-buffers ivy--virtual-buffers)
    (counsel--switch-buffer-update-fn)))

(defalias 'nasy/ivy/switch-buffer-preview-all #'counsel--switch-buffer-update-fn)
(defalias 'nasy/ivy/switch-buffer-unwind      #'counsel--switch-buffer-unwind)

(defun nasy/ivy--switch-buffer (workspace other)
  (let ((current (not other))
      prompt action filter update unwind)
    (cond ((and workspace current)
  	 (setq prompt "Switch to workspace buffer: "
  	       action #'ivy--switch-buffer-action
  	       filter #'nasy/ivy-is-workspace-other-buffer-p))
  	(workspace
  	 (setq prompt "Switch to workspace buffer in other window: "
  	       action #'ivy--switch-buffer-other-window-action
  	       filter #'nasy/ivy-is-workspace-buffer-p))
  	(current
  	 (setq prompt "Switch to buffer: "
  	       action #'ivy--switch-buffer-action))
  	((setq prompt "Switch to buffer in other window: "
  	       action #'ivy--switch-buffer-other-window-action)))
    (when nasy/ivy-buffer-preview
      (cond ((not (and ivy-use-virtual-buffers
  		  (eq nasy/ivy-buffer-preview 'everything)))
  	   (setq update #'nasy/ivy/switch-buffer-preview
  		 unwind #'nasy/ivy/switch-buffer-unwind))
  	  ((setq update #'nasy/ivy/switch-buffer-preview-all
  		 unwind #'nasy/ivy/switch-buffer-unwind))))
    (ivy-read prompt 'internal-complete-buffer
  	    :action action
  	    :predicate filter
  	    :update-fn update
  	    :unwind unwind
  	    :preselect (buffer-name (other-buffer (current-buffer)))
  	    :matcher #'ivy--switch-buffer-matcher
  	    :keymap ivy-switch-buffer-map
  	    ;; NOTE A clever disguise, needed for virtual buffers.
  	    :caller #'ivy-switch-buffer)))

;;;###autoload
(defun nasy/ivy/switch-workspace-buffer (&optional arg)
  "Switch to another buffer within the current workspace.
If ARG (universal argument), open selection in other-window."
  (interactive "P")
  (nasy/ivy--switch-buffer t arg))

;;;###autoload
(defun nasy/ivy/switch-workspace-buffer-other-window ()
  "Switch another window to a buffer within the current workspace."
  (interactive)
  (nasy/ivy--switch-buffer t t))

;;;###autoload
(defun nasy/ivy/switch-buffer ()
  "Switch to another buffer."
  (interactive)
  (nasy/ivy--switch-buffer nil nil))

;;;###autoload
(defun nasy/ivy/switch-buffer-other-window ()
  "Switch to another buffer in another window."
  (interactive)
  (nasy/ivy--switch-buffer nil t))

;;;###autoload
(defun nasy/ivy-woccur ()
  "Invoke a wgrep buffer on the current ivy results, if supported."
  (interactive)
  (unless (window-minibuffer-p)
    (user-error "No completion session is active"))
  (require 'wgrep)
  (let ((caller (ivy-state-caller ivy-last)))
    (if-let (occur-fn (plist-get nasy/ivy-edit-functions caller))
      (ivy-exit-with-action
       (lambda (_) (funcall occur-fn)))
    (if-let (occur-fn (plist-get ivy--occurs-list caller))
      (let ((buffer (generate-new-buffer
  		     (format "*ivy-occur%s \"%s\"*"
  			     (if caller (concat " " (prin1-to-string caller)) "")
  			     ivy-text))))
  	(with-current-buffer buffer
  	  (let ((inhibit-read-only t))
  	    (erase-buffer)
  	    (funcall occur-fn))
  	  (setf (ivy-state-text ivy-last) ivy-text)
  	  (setq ivy-occur-last ivy-last)
  	  (setq-local ivy--directory ivy--directory))
  	(ivy-exit-with-action
  	 `(lambda (_)
  	    (pop-to-buffer ,buffer)
  	    (ivy-wgrep-change-to-wgrep-mode))))
      (user-error "%S doesn't support wgrep" caller)))))

;;;###autoload
(defun nasy/ivy-yas-prompt (prompt choices &optional display-fn)
  (yas-completing-prompt prompt choices display-fn #'ivy-completing-read))

;;;###autoload
(defun nasy/ivy-git-grep-other-window-action (x)
  "Opens the current candidate in another window."
  (when (string-match "\\`\\(.*?\\):\\([0-9]+\\):\\(.*\\)\\'" x)
    (select-window
     (with-ivy-window
     (let ((file-name   (match-string-no-properties 1 x))
  	 (line-number (match-string-no-properties 2 x)))
       (find-file-other-window (expand-file-name file-name (ivy-state-directory ivy-last)))
       (goto-char (point-min))
       (forward-line (1- (string-to-number line-number)))
       (re-search-forward (ivy--regex ivy-text t) (line-end-position) t)
       (run-hooks 'counsel-grep-post-action-hook)
       (selected-window))))))

;;;###autoload
(defun nasy/ivy-confirm-delete-file (x)
  (dired-delete-file x 'confirm-each-subdirectory))


;;
;;; File searching

;;;###autoload
(defun nasy/ivy/projectile-find-file ()
  "A more sensible `counsel-projectile-find-file', which will revert to
`counsel-find-file' if invoked from $HOME, `counsel-file-jump' if invoked from a
non-project, `projectile-find-file' if in a big project (more than
`ivy-sort-max-size' files), or `counsel-projectile-find-file' otherwise.
The point of this is to avoid Emacs locking up indexing massive file trees."
  (interactive)
  ;; Spoof the command so that ivy/counsel will display the (well fleshed-out)
  ;; actions list for `counsel-find-file' on C-o. The actions list for the other
  ;; commands aren't as well configured or are empty.
  (let ((this-command 'counsel-find-file))
    (call-interactively
     (cond ((or (file-equal-p default-directory "~")
  	    (when-let (proot (nasy/project-root))
  	      (file-equal-p proot "~")))
  	#'counsel-find-file)

       ((nasy/project-p)
  	(let ((files (projectile-current-project-files)))
  	  (if (<= (length files) ivy-sort-max-size)
  	      #'counsel-projectile-find-file
  	    #'projectile-find-file)))

       (#'counsel-file-jump)))))

;;;###autoload
(cl-defun nasy/ivy-file-search (&key query in all-files (recursive t) prompt args)
  "Conduct a file search using ripgrep.
:query STRING
  Determines the initial input to search for.
:in PATH
  Sets what directory to base the search out of. Defaults to the current
  project's root.
:recursive BOOL
  Whether or not to search files recursively from the base directory."
  (declare (indent defun))
  (unless (executable-find "rg")
    (user-error "Couldn't find ripgrep in your PATH"))
  (require 'counsel)
  (let* ((this-command 'counsel-rg)
       (project-root (or (nasy/project-root) default-directory))
       (directory (or in project-root))
       (args (concat (if all-files " -uu")
  		   (unless recursive " --maxdepth 1")
  		   " "
  		   (mapconcat #'shell-quote-argument args " "))))
    (setq deactivate-mark t)
    (counsel-rg
     (or query
       (when (nasy/region-active-p)
       (replace-regexp-in-string
  	"[! |]" (lambda (substr)
  		  (cond ((and (string= substr " ")
  			    (not *ivy-fuzzy*))
  			 "  ")
  			((string= substr "|")
  			 "\\\\\\\\|")
  			((concat "\\\\" substr))))
  	(rxt-quote-pcre (nasy/thing-at-point-or-region)))))
     directory args
     (or prompt
       (format "rg%s [%s]: "
  	     args
  	     (cond ((equal directory default-directory)
  		    "./")
  		   ((equal directory project-root)
  		    (projectile-project-name))
  		   ((file-relative-name directory project-root))))))))

;;;###autoload
(defun nasy/ivy/project-search (&optional arg initial-query directory)
  "Performs a live project search from the project root using ripgrep.
If ARG (universal argument), include all files, even hidden or compressed ones,
in the search."
  (interactive "P")
  (nasy/ivy-file-search :query initial-query :in directory :all-files arg))

;;;###autoload
(defun nasy/ivy/project-search-from-cwd (&optional arg initial-query)
  "Performs a project search recursively from the current directory.
If ARG (universal argument), include all files, even hidden or compressed ones."
  (interactive "P")
  (nasy/ivy/project-search arg initial-query default-directory))


;;
;;; Wrappers around `counsel-compile'

;;;###autoload
(defun nasy/ivy/compile ()
  "Execute a compile command from the current buffer's directory."
  (interactive)
  (counsel-compile default-directory))

;;;###autoload
(defun nasy/ivy/project-compile ()
  "Execute a compile command from the current project's root."
  (interactive)
  (counsel-compile (projectile-project-root)))

;;;###autoload
(defun nasy/ivy/git-grep-other-window-action ()
  "Open the current counsel-{ag,rg,git-grep} candidate in other-window."
  (interactive)
  (ivy-set-action #'nasy/ivy-git-grep-other-window-action)
  (setq ivy-exit 'done)
  (exit-minibuffer))

(defvar nasy/ivy-buffer-preview 'everything
  "If non-nil, preview buffers while switching, à la `counsel-switch-buffer'.
When nil, don't preview anything.
When non-nil, preview non-virtual buffers.
When 'everything, also preview virtual buffers")

(defvar nasy/ivy-buffer-unreal-face 'font-lock-comment-face
  "The face for unreal buffers in `ivy-switch-to-buffer'.")

(defvar nasy/ivy-edit-functions nil
  "A plist mapping ivy/counsel commands to commands that generate an editable
results buffer.")

(use-package ivy
  :defer t
  :ghook 'after-init-hook
  :init
  (let ((standard-search-fn
       (if *ivy-prescient*
  	   #'+ivy-prescient-non-fuzzy
  	 #'ivy--regex-plus))
      (alt-search-fn
       (if *ivy-fuzzy*
  	   #'ivy--regex-fuzzy
  	 ;; Ignore order for non-fuzzy searches by default
  	 #'ivy--regex-ignore-order)))
    (gsetq ivy-re-builders-alist
  	 `((counsel-rg     . ,standard-search-fn)
  	   (swiper         . ,standard-search-fn)
  	   (swiper-isearch . ,standard-search-fn)
  	   (t . ,alt-search-fn))
  	 ivy-more-chars-alist
  	 '((counsel-rg . 1)
  	   (counsel-search . 2)
  	   (t . 3))))
  (gsetq ivy-wrap                         t
       ivy-auto-shrink-minibuffer-alist '((t . t))
       ivy-height                       15
       ivy-fixed-height-minibuffer      nil
       projectile-completion-system     'ivy
       ;; disable magic slash on non-match
       ivy-magic-slash-non-match-action nil
       ;; don't show recent files in switch-buffer
       ivy-use-virtual-buffers          nil
       ;; ...but if that ever changes, show their full path
       ivy-virtual-abbreviate           'full
       ;; don't quit minibuffer on delete-error
       ivy-on-del-error-function        #'ignore
       ;; enable ability to select prompt (alternative to `ivy-immediate-done')
       ivy-use-selectable-prompt        t)
  (general-define-key
   [remap switch-to-buffer]              #'nasy/ivy/switch-buffer
   [remap switch-to-buffer-other-window] #'nasy/ivy/switch-buffer-other-window
   [remap persp-switch-to-buffer]        #'nasy/ivy/switch-workspace-buffer)
  (general-define-key
   :keymaps 'ivy-mode-map
   [remap switch-to-buffer]              #'nasy/ivy/switch-buffer
   [remap switch-to-buffer-other-window] #'nasy/ivy/switch-buffer-other-window
   [remap persp-switch-to-buffer]        #'nasy/ivy/switch-workspace-buffer)
  :config
  ;; Counsel changes a lot of ivy's state at startup; to control for that, we
  ;; need to load it as early as possible. Some packages (like `ivy-prescient')
  ;; require this.
  (require 'counsel nil t)

  ;; Highlight each ivy candidate including the following newline, so that it
  ;; extends to the right edge of the window
  (setf (alist-get 't ivy-format-functions-alist)
      #'ivy-format-function-line)

  ;; Integrate `ivy' with `better-jumper'; ensure a jump point is registered
  ;; before jumping to new locations with ivy
  (setf (alist-get 't ivy-hooks-alist)
      (lambda ()
  	(with-ivy-window
  	  (setq nasy/ivy--origin (point-marker)))))

  (add-hook 'minibuffer-exit-hook
    (defun nasy/ivy--set-jump-point-maybe-h ()
      (and (markerp (bound-and-true-p nasy/ivy--origin))
  	 (not (equal (ignore-errors (with-ivy-window (point-marker)))
  		     nasy/ivy--origin))
  	 (with-current-buffer (marker-buffer nasy/ivy--origin)
  	   (better-jumper-set-jump nasy/ivy--origin)))
      (setq nasy/ivy--origin nil)))

  (after! yasnippet
    (add-hook 'yas-prompt-functions #'nasy/ivy-yas-prompt))

  (general-define-key
    :keymaps 'ivy-minibuffer-map
    "C-c C-e" #'nasy/ivy-woccur
    [remap nasy/delete-backward-word] #'ivy-backward-kill-word)

  (ivy-mode +1))

(use-package ivy-xref
  :defer t
  :init (gsetq xref-show-xrefs-function #'ivy-xref-show-xrefs))

(after! ivy
  (use-package ivy-hydra
    :commands (ivy-dispatching-done ivy--matcher-desc ivy-hydra/body)
    :init
    (general-define-key
     :keymaps 'ivy-minibuffer-map
     "C-o" #'ivy-dispatching-done
     "M-o" #'hydra-ivy/body)
    :config
    ;; ivy-hydra rebinds this, so we have to do so again
    (define-key ivy-minibuffer-map (kbd "M-o") #'hydra-ivy/body)))

(use-package counsel
  :init
  (gsetq
   counsel-find-file-at-point         t
   ;; Don't use ^ as initial input. Set this here because `counsel' defines more
   ;; of its own, on top of the defaults.
   ivy-initial-inputs-alist           nil
   ;; helpful
   counsel-describe-function-function #'helpful-callable
   counsel-describe-variable-function #'helpful-variable)
  (general-define-key
   [remap apropos]                    #'counsel-apropos
   [remap bookmark-jump]              #'counsel-bookmark
   [remap compile]                    #'nasy/ivy/compile
   [remap describe-bindings]          #'counsel-descbinds
   [remap describe-face]              #'counsel-faces
   [remap describe-function]          #'counsel-describe-function
   [remap describe-variable]          #'counsel-describe-variable
   [remap execute-extended-command]   #'counsel-M-x
   [remap find-file]                  #'counsel-find-file
   [remap find-library]               #'counsel-find-library
   [remap imenu]                      #'counsel-imenu
   [remap info-lookup-symbol]         #'counsel-info-lookup-symbol
   [remap load-theme]                 #'counsel-load-theme
   [remap locate]                     #'counsel-locate
   [remap org-set-tags-command]       #'counsel-org-tag
   [remap projectile-compile-project] #'nasy/ivy/project-compile
   [remap recentf-open-files]         #'counsel-recentf
   [remap set-variable]               #'counsel-set-variable
   [remap swiper]                     #'counsel-grep-or-swiper
   [remap unicode-chars-list-chars]   #'counsel-unicode-char
   [remap yank-pop]                   #'counsel-yank-pop)
  (general-define-key
   :keymaps 'counsel-find-file-map
   "<left>"  #'counsel-up-directory
   "<right>" #'counsel-down-directory)
  :config
  ;; (set-popup-rule! "^\\*ivy-occur" :size 0.35 :ttl 0 :quit nil)

  ;; HACK Fix an issue where `counsel-projectile-find-file-action' would try to
  ;;      open a candidate in an occur buffer relative to the wrong buffer,
  ;;      causing it to fail to find the file we want.
  (defadvice! nasy/ivy--run-from-ivy-directory-a (orig-fn &rest args)
    :around #'counsel-projectile-find-file-action
    (let ((default-directory (ivy-state-directory ivy-last)))
      (apply orig-fn args)))

  ;; Record in jumplist when opening files via counsel-{ag,rg,pt,git-grep}
  (add-hook 'counsel-grep-post-action-hook #'better-jumper-set-jump)
  (ivy-add-actions
   'counsel-rg ; also applies to `counsel-rg'
   '(("O" nasy/ivy-git-grep-other-window-action "open in other window")))

  ;; Make `counsel-compile' projectile-aware (if you prefer it over
  ;; `nasy/ivy/compile' and `nasy/ivy/project-compile')
  (add-to-list 'counsel-compile-root-functions #'projectile-project-root)
  (after! savehist
    ;; Persist `counsel-compile' history
    (add-to-list 'savehist-additional-variables 'counsel-compile-history))

  ;; `counsel-imenu' -- no sorting for imenu. Sort it by appearance in page.
  (add-to-list 'ivy-sort-functions-alist '(counsel-imenu))

  ;; `counsel-locate'
  (when *is-a-mac*
    ;; Use spotlight on mac by default since it doesn't need any additional setup
    (setq counsel-locate-cmd #'counsel-locate-cmd-mdfind))

  ;; `swiper'
  ;; Don't mess with font-locking on the dashboard; it causes breakages
  ;; (add-to-list 'swiper-font-lock-exclude #'+doom-dashboard-mode)

  ;; `counsel-find-file'
  (setq counsel-find-file-ignore-regexp "\\(?:^[#.]\\)\\|\\(?:[#~]$\\)\\|\\(?:^Icon?\\)")
  (dolist (fn '(counsel-rg counsel-find-file))
    (ivy-add-actions
     fn '(("p" (lambda (path) (with-ivy-window (insert (file-relative-name path default-directory))))
  	 "insert relative path")
  	("P" (lambda (path) (with-ivy-window (insert path)))
  	 "insert absolute path")
  	("l" (lambda (path) (with-ivy-window (insert (format "[[./%s]]" (file-relative-name path default-directory)))))
  	 "insert relative org-link")
  	("L" (lambda (path) (with-ivy-window (insert (format "[[%s]]" path))))
  	 "Insert absolute org-link"))))

  (ivy-add-actions 'counsel-file-jump (plist-get ivy--actions-list 'counsel-find-file))

  ;; `counsel-search': use normal page for displaying results, so that we see
  ;; custom ddg themes (if one is set).
  (setf (nth 1 (alist-get 'ddg counsel-search-engines-alist))
      "https://duckduckgo.com/?q=")

  ;; REVIEW Move this somewhere else and perhaps generalize this so both
  ;;        ivy/helm users can enjoy it.
  (defadvice! nasy/ivy--counsel-file-jump-use-fd-rg-a (args)
    "Change `counsel-file-jump' to use fd or ripgrep, if they are available."
    :override #'counsel--find-return-list
    (cl-destructuring-bind (find-program . args)
      (cond ((executable-find nasy/projectile-fd-binary)
  	     (cons nasy/projectile-fd-binary (list "-t" "f" "-E" ".git")))
  	    ((executable-find "rg")
  	     (cons "rg" (list "--files" "--hidden" "--no-messages")))
  	    ((cons find-program args)))
      (unless (listp args)
      (user-error "`counsel-file-jump-args' is a list now, please customize accordingly."))
      (counsel--call
       (cons find-program args)
       (lambda ()
       (goto-char (point-min))
       (let ((offset (if (member find-program (list "rg" nasy/projectile-fd-binary)) 0 2))
  	     files)
  	 (while (< (point) (point-max))
  	   (push (buffer-substring
  		  (+ offset (line-beginning-position)) (line-end-position)) files)
  	   (forward-line 1))
  	 (nreverse files)))))))

(use-package counsel-projectile
  :defer t
  :init
  (general-define-key
    [remap projectile-find-file]        #'nasy/ivy/projectile-find-file
    [remap projectile-find-dir]         #'counsel-projectile-find-dir
    [remap projectile-switch-to-buffer] #'counsel-projectile-switch-to-buffer
    [remap projectile-grep]             #'counsel-projectile-grep
    [remap projectile-ag]               #'counsel-projectile-ag
    [remap projectile-switch-project]   #'counsel-projectile-switch-project)
  :config
  ;; A more sensible `counsel-projectile-find-file' that reverts to
  ;; `counsel-find-file' if invoked from $HOME, `counsel-file-jump' if invoked
  ;; from a non-project, `projectile-find-file' if in a big project (more than
  ;; `ivy-sort-max-size' files), or `counsel-projectile-find-file' otherwise.
  (setf (alist-get 'projectile-find-file counsel-projectile-key-bindings)
      #'nasy/ivy/projectile-find-file)

  ;; no highlighting visited files; slows down the filtering
  (ivy-set-display-transformer #'counsel-projectile-find-file nil)

  ;;
  (setq counsel-projectile-sort-files t))

(use-package ivy-prescient
  :defer t
  :ghook 'after-init-hook)

(use-package all-the-icons-ivy-rich
  :defer t
  :init
  (gsetq all-the-icons-ivy-rich-icon-size 0.7)
  (all-the-icons-ivy-rich-mode 1)
  (advice-add #'counsel-M-x :before #'all-the-icons-ivy-rich-reload))

(use-package ivy-rich
  :defer t
  :init (ivy-rich-mode 1))

(straight-use-package 'vlf)
(use-package vlf
  :init
  (defun ffap-vlf ()
    "Find file at point with VLF."
    (interactive)
    (let ((file (ffap-file-at-point)))
      (unless (file-exists-p file)
      (error "File does not exist: %s" file))
      (vlf file))))

(straight-use-package 'link-hint)
(use-package link-hint
  :bind (("C-c l o" . link-hint-open-link)
       ("C-c l c" . link-hint-copy-link))
  :config
  (general-define-key
   :prefix "C-c l")
  "o" 'link-hint-open-link
  "c" 'link-hint-copy-link)

(straight-use-package 'list-unicode-display)

(straight-use-package 'mmm-mode)
(use-package mmm-auto
  :init (gsetq
       mmm-global-mode
       'buffers-with-submode-classes
       mmm-submode-decoration-level 2))

(straight-use-package 'multiple-cursors)
(use-package multiple-cursors
  :bind (("C-<"     . mc/mark-previous-like-this)
       ("C->"     . mc/mark-next-like-this)
       ("C-+"     . mc/mark-next-like-this)
       ("C-c C-<" . mc/mark-all-like-this))
  :config
  ;; From active region to multiple cursors:
  (general-define-key
   :preface "C-c m"
   "r" 'set=rectangular-region-anchor
   "c" 'mc/edit-lines
   "e" 'mc/edit-ends-of-lines
   "a" 'mc/edit-beginnings-of-lines))

(straight-use-package 'page-break-lines)
(use-package page-break-lines
  :hook ((after-init . global-page-break-lines-mode))
  :diminish page-break-lines-mode)

(add-hook 'after-init-hook 'show-paren-mode)

(straight-use-package 'smartparens)
(use-package smartparens-config
  :hook ((after-init . smartparens-global-mode))
  :init (gsetq sp-hybrid-kill-entire-symbol nil))

(straight-use-package 'rainbow-delimiters)
(use-package rainbow-delimiters
  :defer t
  :ghook '(prog-mode-hook org-src-mode-hook))

(straight-use-package 'pdf-tools)
(use-package pdf-tools
  :defer t
  :config
  (gsetq-default pdf-view-display-size 'fit-width)
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

(straight-use-package 'pretty-mode)
(use-package pretty-mode
  :commands (turn-on-pretty-mode global-prettify-symbols-mode)
  :hook (((text-mode
  	 org-mode)  . turn-on-pretty-mode)
       (after-init  . global-prettify-symbols-mode)
       (prog-mode . (lambda () (mapc (lambda (pair) (push pair prettify-symbols-alist))
  				'(;; Data Type             P N
  				  ("Float"  . #x211d)  ;; ℝxxxx
  				  ("float"  . #x211d)  ;; ℝxxx
  				  ("Int"    . #x2124)  ;; ℤxxx
  				  ("int"    . #x2124)  ;; 𝕫xxx
  				  ;; ("String" . #x1d57e)  ;; 𝕊 𝕾
  				  ;; ("string" . #x1d598)  ;; 𝕤 𝖘
  				  ;; ("str"    . #x1d598)  ;; 𝕤 𝖘
  				  ("String" . (#x1d54a (Br . Bl) #x2006))  ;; 𝕊 xxxxxx
  				  ("string" . (#x1d564 (Br . Bl) #x2006))  ;; 𝕤 xxxxxx
  				  ("str"    . (#x1d564 (Br . Bl) #x2006))  ;; 𝕤 xxxx
  				  ("Char"   . #x2102)   ;; ℂx
  				  ("char"   . (#x1d554 (Br . Bl) #x2006))  ;; 𝕔 x

  				  ("False"  . #x1d53d)  ;; 𝕱 𝔽
  				  ("True"   . #x1d54b)  ;; 𝕿 𝕋

  				  ("Any"    . #x2203)  ;; ∃
  				  ("any"    . #x2203)  ;; ∃
  				  ("any_"   . #x2203)  ;; ∃
  				  ("And"    . (#x2000 (Br . Bl) #x22c0 (Br . Bl) #x2005))  ;; ⋀
  				  ("and"    . (#x2000 (Br . Bl) #x22cf (Br . Bl) #x2005))  ;; ⋏
  				  ("Or"     . #x22c1)  ;; ⋁
  				  ("or"     . #x22cE)  ;; ⋎
  				  ("not"    . #x00ac)  ;; ¬
  				  ("not_"   . #x00ac)  ;; ¬

  				  ("All"    . #x2200)  ;; ∀
  				  ("all"    . #x2200)  ;; ∀
  				  ("all_"   . #x2200)  ;; ∀
  				  ("for"    . #x2200)  ;; ∀
  				  ("forall" . #x2200)  ;; ∀
  				  ("forM"   . #x2200)  ;; ∀

  				  ("pi"     . #x03c0)  ;; π

  				  ("sum"    . #x2211)  ;; ∑
  				  ("Sum"    . #x2211)  ;; ∑
  				  ("Product" . #x220F) ;; ∏
  				  ("product" . #x220F) ;; ∏

  				  ("None"   . #x2205)  ;; ∅
  				  ("none"   . #x2205)  ;; ∅

  				  ("in"     . #x2286)  ;; ⊆
  				  ("`elem`" . #x2286)  ;; ⊆
  				  ("not in"    . #x2288)  ;; ⊈
  				  ("`notElem`" . #x2288)  ;; ⊈

  				  ("return" . (#x21d2 (Br . Bl) #x2006 (Br . Bl) #x2004))  ;; ⇒  x
  				  ("yield"  . (#x21d4 (Br . Bl) #x2004))  ;; ⇔ x
  				  ("pure"   . (#x21f0 (Br . Bl)))))))          ;; ⇰ x

       ((prog-mode
  	 emacs-lisp-mode
  	 org-mode) . (lambda () (mapc (lambda (pair) (push pair prettify-symbols-alist))
  				 '(;; Global
  				   ;; Pipes
  				   ("<|"  . (?\s (Br . Bl) #Xe14d))
  				   ("<>"  . (?\s (Br . Bl) #Xe15b))
  				   ("<|>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe14e))
  				   ("|>"  . (?\s (Br . Bl) #Xe135))

  				   ;; Brackets
  				   ("<*"  . (?\s (Br . Bl) #Xe14b))
  				   ("<*>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe14c))
  				   ("*>"  . (?\s (Br . Bl) #Xe104))
  				   ("<$"  . (?\s (Br . Bl) #Xe14f))
  				   ("<$>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe150))
  				   ("$>"  . (?\s (Br . Bl) #Xe137))
  				   ("<+"  . (?\s (Br . Bl) #Xe155))
  				   ("<+>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe156))
  				   ("+>"  . (?\s (Br . Bl) #Xe13a))
  				   ("[]"  . (#x2005 (Br . Bl) #x1d731 (Br . Bl) #x2005))

  				   ;; Equality
  				   ("=/="  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe143))
  				   ("/="   . (?\s (Br . Bl) #Xe12c))
  				   ("/=="  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe12d))
  				   ("/==>" . (?\s (Br . Bl) ?\s (Br . Bl) ?\s (Br . Bl) #Xe13c))
  				   ("!==>" . (?\s (Br . Bl) ?\s (Br . Bl) ?\s (Br . Bl) #Xe13c))
  				   ;; Special
  				   ("||="  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe133))
  				   ("|="   . (?\s (Br . Bl) #Xe134))
  				   ("~="   . (?\s (Br . Bl) #Xe166))
  				   ("^="   . (?\s (Br . Bl) #Xe136))
  				   ("=:="  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe13b))

  				   ;; Comparisons
  				   ("</"   . (?\s (Br . Bl) #Xe162))
  				   ("</>"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe163))

  				   ;; Shifts
  				   ("=>>"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe147))
  				   ("->>"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe147))
  				   (">>>"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe14a))
  				   (">>>"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe14a))
  				   ("=<<"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe15c))
  				   ("-<<"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe15c))
  				   ("<<<"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe15f))

  				   ;; Dots
  				   (".-"   . (?\s (Br . Bl) #Xe122))
  				   (".="   . (?\s (Br . Bl) #Xe123))
  				   ("..<"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe125))

  				   ;; Hashes
  				   ("#{"   . (?\s (Br . Bl) #Xe119))
  				   ("#("   . (?\s (Br . Bl) #Xe11e))
  				   ("#_"   . (?\s (Br . Bl) #Xe120))
  				   ("#_("  . (?\s (Br . Bl) #Xe121))
  				   ("#?"   . (?\s (Br . Bl) #Xe11f))
  				   ("#["   . (?\s (Br . Bl) #Xe11a))

  				   ;; REPEATED CHARACTERS
  				   ;; 2-Repeats
  				   ("!!"   . (?\s (Br . Bl) #Xe10d))
  				   ("%%"   . (?\s (Br . Bl) #Xe16a))

  				   ;; 2+3-Repeats
  				   ("##"   . (?\s (Br . Bl) #Xe11b))
  				   ("###"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe11c))
  				   ("####" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe11d))
  				   ("---"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe112))
  				   ("{-"   . (?\s (Br . Bl) #Xe108))
  				   ("-}"   . (?\s (Br . Bl) #Xe110))
  				   ("\\\\" . (?\s (Br . Bl) #Xe106))
  				   ("\\\\\\" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe107))
  				   (".."   . (?\s (Br . Bl) #Xe124))
  				   ("..."  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe126))
  				   ("+++"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe139))
  				   ("//"   . (?\s (Br . Bl) #Xe12f))
  				   ("///"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe130))
  				   ("::"   . (?\s (Br . Bl) #Xe10a))  ;; 
  				   (":::"  . (?\s (Br . Bl) ?\s (Br . Bl) #Xe10b))

  				   ;; Arrows
  				   ;; Direct
  				   ;; ("->"  . (?\s (Br . Bl) #Xe114))  ;; 
  				   ;; ("=>"  . (?\s (Br . Bl) #Xe13f))
  				   ("->>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe115))
  				   ("=>>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe140))
  				   ("<<-" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe15d))
  				   ("<<=" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe15e))
  				   ("<->" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe154))
  				   ("<=>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe159))
  				   ;; Branches
  				   ("-<"  . (?\s (Br . Bl) #Xe116))
  				   ("-<<" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe117))
  				   (">-"  . (?\s (Br . Bl) #Xe144))
  				   (">>-" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe148))
  				   ("=<<" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe142))
  				   (">=>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe146))
  				   (">>=" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe149))
  				   ("<=<" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe15a))
  				   ;; Squiggly
  				   ("<~"  . (?\s (Br . Bl) #Xe160))
  				   ("<~~" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe161))
  				   ("~>"  . (?\s (Br . Bl) #Xe167))
  				   ("~~>" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe169))
  				   ("-~"  . (?\s (Br . Bl) #Xe118))
  				   ("~-"  . (?\s (Br . Bl) #Xe165))

  				   ;; MISC
  				   ("www" . (?\s (Br . Bl) ?\s (Br . Bl) #Xe100))
  				   ("~@"  . (?\s (Br . Bl) #Xe164))
  				   ("~~"  . (?\s (Br . Bl) #Xe168))
  				   ("?="  . (?\s (Br . Bl) #Xe127))
  				   (":="  . (?\s (Br . Bl) #Xe10c))
  				   ("/>"  . (?\s (Br . Bl) #Xe12e))
  				   ("+"   . #Xe16d)
  				   ("(:"  . (?\s (Br . Bl) #Xe16c))))))


       (python-mode . (lambda ()
  			(mapc (lambda (pair) (push pair prettify-symbols-alist))
  			      '(;; Syntax
  				;;("def"    . (#x1d521 (Br . Bl) #x1d522 (Br . Bl) #x1d523))
  				("def"    . #x1D487)  ;; 𝒇 1 111
  				("List"   . #x1d543)  ;; 𝕃 𝕷
  				("list"   . (#x1d55d (Br . Bl) #x2006 (Br . Bl) #x2005))  ;; 𝕝   𝖑
  				("Dict"   . #x1d53B)  ;; 𝔻 𝕯
  				("dict"   . #x1d555)  ;; 𝕕 𝖉
  				("Set"    . #x1d61a)  ;; 𝔖 𝘚
  				("set"    . #x1d634)  ;; 𝔰 𝘴
  				("Tuple"  . #x1d61b)  ;; 𝕋 𝕿 𝘛
  				("tuple"  . #x1d635)  ;; 𝕥 𝖙 𝘵

  				("Union"  . #x22c3)  ;; ⋃
  				("union"  . #x22c3)))))  ;; ⋃

       (haskell-mode . (lambda ()
  			 (mapc (lambda (pair) (push pair prettify-symbols-alist))
  			       '(;; Syntax
  				 ("pure" . (#x21f0 (Br . Bl) #x2006))))))) ;; ⇰  x
  				 ;; (" . "  . (?\s (Br . Bl) #x2218 (Br . Bl) ?\s (Br . Bl) #x2006)) ;; ∘

  :config
  (pretty-activate-groups
   '(:sub-and-superscripts :greek :arithmetic))

  (pretty-deactivate-groups
   '(:equality :ordering :ordering-double :ordering-triple
  	     :arrows :arrows-twoheaded :punctuation
  	     :logic :sets :arithmetic-double :arithmetic-triple)))

(straight-use-package 'ipretty)
(use-package ipretty
  :defer    t
  :ghook 'after-init-hook)

;; https://github.com/tonsky/FiraCode/wiki/Emacs-instructions
;; This works when using emacs --daemon + emacsclient
(add-hook 'after-make-frame-functions (lambda (frame) (set-fontset-font t '(#Xe100 . #Xe16f) "Fira Code Symbol")))
;; This works when using emacs without server/client
(set-fontset-font t '(#Xe100 . #Xe16f) "Fira Code Symbol")
;; I haven't found one statement that makes both of the above situations work, so I use both for now

(defun pretty-fonts-set-fontsets (CODE-FONT-ALIST)
  "Utility to associate many unicode points with specified `CODE-FONT-ALIST'."
  (--each CODE-FONT-ALIST
    (-let (((font . codes) it))
      (--each codes
      (set-fontset-font nil `(,it . ,it) font)
      (set-fontset-font t `(,it . ,it) font)))))

(defun pretty-fonts--add-kwds (FONT-LOCK-ALIST)
  "Exploits `font-lock-add-keywords'(`FONT-LOCK-ALIST') to apply regex-unicode replacements."
  (font-lock-add-keywords
   nil (--map (-let (((rgx uni-point) it))
  	     `(,rgx (0 (progn
  			 (compose-region
  			  (match-beginning 1) (match-end 1)
  			  ,(concat "\t" (list uni-point)))
  			 nil))))
  	   FONT-LOCK-ALIST)))

(defmacro pretty-fonts-set-kwds (FONT-LOCK-HOOKS-ALIST)
  "Set regex-unicode replacements to many modes(`FONT-LOCK-HOOKS-ALIST')."
  `(--each ,FONT-LOCK-HOOKS-ALIST
     (-let (((font-locks . mode-hooks) it))
       (--each mode-hooks
       (add-hook it (-partial 'pretty-fonts--add-kwds
  			      (symbol-value font-locks)))))))

(defconst pretty-fonts-fira-font
  '(;; OPERATORS
    ;; Pipes
    ("\\(<|\\)" #Xe14d) ("\\(<>\\)" #Xe15b) ("\\(<|>\\)" #Xe14e) ("\\(|>\\)" #Xe135)

    ;; Brackets
    ("\\(<\\*\\)" #Xe14b) ("\\(<\\*>\\)" #Xe14c) ("\\(\\*>\\)" #Xe104)
    ("\\(<\\$\\)" #Xe14f) ("\\(<\\$>\\)" #Xe150) ("\\(\\$>\\)" #Xe137)
    ("\\(<\\+\\)" #Xe155) ("\\(<\\+>\\)" #Xe156) ("\\(\\+>\\)" #Xe13a)

    ;; Equality
    ("\\(!=\\)" #Xe10e) ("\\(!==\\)"         #Xe10f) ("\\(=/=\\)" #Xe143)
    ("\\(/=\\)" #Xe12c) ("\\(/==\\)"         #Xe12d)
    ("\\(===\\)" #Xe13d) ("[^!/]\\(==\\)[^>]" #Xe13c)

    ;; Equality Special
    ("\\(||=\\)"  #Xe133) ("[^|]\\(|=\\)" #Xe134)
    ("\\(~=\\)"   #Xe166)
    ("\\(\\^=\\)" #Xe136)
    ("\\(=:=\\)"  #Xe13b)

    ;; Comparisons
    ("\\(<=\\)" #Xe141) ("\\(>=\\)" #Xe145)
    ("\\(</\\)" #Xe162) ("\\(</>\\)" #Xe163)

    ;; Shifts
    ("[^-=]\\(>>\\)" #Xe147) ("\\(>>>\\)" #Xe14a)
    ("[^-=]\\(<<\\)" #Xe15c) ("\\(<<<\\)" #Xe15f)

    ;; Dots
    ("\\(\\.-\\)"    #Xe122) ("\\(\\.=\\)" #Xe123)
    ("\\(\\.\\.<\\)" #Xe125)

    ;; Hashes
    ("\\(#{\\)"  #Xe119) ("\\(#(\\)"   #Xe11e) ("\\(#_\\)"   #Xe120)
    ("\\(#_(\\)" #Xe121) ("\\(#\\?\\)" #Xe11f) ("\\(#\\[\\)" #Xe11a)

    ;; REPEATED CHARACTERS
    ;; 2-Repeats
    ("\\(||\\)" #Xe132)
    ("\\(!!\\)" #Xe10d)
    ("\\(%%\\)" #Xe16a)
    ("\\(&&\\)" #Xe131)

    ;; 2+3-Repeats
    ("\\(##\\)"       #Xe11b) ("\\(###\\)"          #Xe11c) ("\\(####\\)" #Xe11d)
    ("\\(--\\)"       #Xe111) ("\\(---\\)"          #Xe112)
    ("\\({-\\)"       #Xe108) ("\\(-}\\)"           #Xe110)
    ("\\(\\\\\\\\\\)" #Xe106) ("\\(\\\\\\\\\\\\\\)" #Xe107)
    ("\\(\\.\\.\\)"   #Xe124) ("\\(\\.\\.\\.\\)"    #Xe126)
    ("\\(\\+\\+\\)"   #Xe138) ("\\(\\+\\+\\+\\)"    #Xe139)
    ("\\(//\\)"       #Xe12f) ("\\(///\\)"          #Xe130)
    ("\\(::\\)"       #Xe10a) ("\\(:::\\)"          #Xe10b)

    ;; ARROWS
    ;; Direct
    ("[^-]\\(->\\)" #Xe114) ("[^=]\\(=>\\)" #Xe13f)
    ("\\(<-\\)"     #Xe152)
    ("\\(-->\\)"    #Xe113) ("\\(->>\\)"    #Xe115)
    ("\\(==>\\)"    #Xe13e) ("\\(=>>\\)"    #Xe140)
    ("\\(<--\\)"    #Xe153) ("\\(<<-\\)"    #Xe15d)
    ("\\(<==\\)"    #Xe158) ("\\(<<=\\)"    #Xe15e)
    ("\\(<->\\)"    #Xe154) ("\\(<=>\\)"    #Xe159)

    ;; Branches
    ("\\(-<\\)"  #Xe116) ("\\(-<<\\)" #Xe117)
    ("\\(>-\\)"  #Xe144) ("\\(>>-\\)" #Xe148)
    ("\\(=<<\\)" #Xe142) ("\\(>>=\\)" #Xe149)
    ("\\(>=>\\)" #Xe146) ("\\(<=<\\)" #Xe15a)

    ;; Squiggly
    ("\\(<~\\)" #Xe160) ("\\(<~~\\)" #Xe161)
    ("\\(~>\\)" #Xe167) ("\\(~~>\\)" #Xe169)
    ("\\(-~\\)" #Xe118) ("\\(~-\\)"  #Xe165)

    ;; MISC
    ("\\(www\\)"                   #Xe100)
    ("\\(<!--\\)"                  #Xe151)
    ("\\(~@\\)"                    #Xe164)
    ("[^<]\\(~~\\)"                #Xe168)
    ("\\(\\?=\\)"                  #Xe127)
    ("[^=]\\(:=\\)"                #Xe10c)
    ("\\(/>\\)"                    #Xe12e)
    ("[^\\+<>]\\(\\+\\)[^\\+<>]"   #Xe16d)
    ("[^:=]\\(:\\)[^:=]"           #Xe16c)
    ("\\(<=\\)"                    #Xe157))
  "Fira font ligatures and their regexes.")

(if (fboundp 'mac-auto-operator-composition-mode)
    (mac-auto-operator-composition-mode)
  (pretty-fonts-set-kwds
   '((pretty-fonts-fira-font prog-mode-hook org-mode-hook))))

(straight-use-package 'projectile)
(use-package projectile
  :defer t
  :diminish
  :commands (projectile-project-root
  	   projectile-project-name
  	   projectile-project-p
  	   projectile-locate-dominating-file)
  :bind-keymap ("C-c C-p" . projectile-command-map)
  :ghook '(after-find-file dired-before-readin-hook minibuffer-setup-hook after-init-hook)
  :init
  (gsetq projectile-indexing-method      'hybrid
       projectile-require-project-root 'prompt)
  (general-define-key
   [remap find-tag] #'projectile-find-tag)
  :config
  (gsetq projectile-project-root-files-top-down-recurring
       (append '("compile_commands.json"
  		 ".cquery")
  	       projectile-project-root-files-top-down-recurring)))

(use-package prescient
  :defer t
  :hook ((after-init . prescient-persist-mode)))

(use-package quick-peek
  :defer t
  :config
  (set-face-attribute 'quick-peek-border-face nil
  		    :background "#75b79e"
  		    :height 0.1)
  (set-face-attribute 'quick-peek-padding-face nil
  		    :height 0.1))

(use-package recentf
  :init (gsetq
       recentf-save-file       "~/.emacs.d/var/recentf"
       recentf-max-saved-items 100
       recentf-exclude         '("/tmp/" "/ssh:"))
  :config
  (add-to-list 'recentf-exclude no-littering-var-directory)
  (add-to-list 'recentf-exclude no-littering-etc-directory))

(use-package subword
  :defer t
  :diminish (subword-mode))

(straight-use-package 'symbol-overlay)
(use-package symbol-overlay
  :bind (("M-i"  . symbol-overlay-put)
       ("M-n"  . symbol-overlay-switch-forward)
       ("M-p"  . symbol-overlay-switch-backward)
       ("<f8>" . symbol-overlay-remove-all)
       ("<f7>" . symbol-overlay-mode)))

(straight-use-package 'treemacs)
(use-package treemacs
  :defer t
  :init
  (after! winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window))
  :config
  (gsetq treemacs-collapse-dirs                 (if treemacs-python-executable 3 0)
       treemacs-deferred-git-apply-delay      0.5
       treemacs-directory-name-transformer    #'identity
       treemacs-display-in-side-window        t
       treemacs-eldoc-display                 t
       treemacs-file-event-delay              5000
       treemacs-file-extension-regex          treemacs-last-period-regex-value
       treemacs-file-follow-delay             0.2
       treemacs-file-name-transformer         #'identity
       treemacs-follow-after-init             t
       treemacs-git-command-pipe              ""
       treemacs-goto-tag-strategy             'refetch-index
       treemacs-indentation                   2
       treemacs-indentation-string            " "
       treemacs-is-never-other-window         nil
       treemacs-max-git-entries               5000
       treemacs-missing-project-action        'ask
       treemacs-move-forward-on-expand        t
       treemacs-no-png-images                 nil
       treemacs-no-delete-other-windows       t
       treemacs-project-follow-cleanup        nil
       treemacs-persist-file                  (no-littering-expand-var-file-name "treemacs-persist")
       treemacs-position                      'left
       treemacs-recenter-distance             0.1
       treemacs-recenter-after-file-follow    nil
       treemacs-recenter-after-tag-follow     nil
       treemacs-recenter-after-project-jump   'always
       treemacs-recenter-after-project-expand 'on-distance
       treemacs-show-cursor                   nil
       treemacs-show-hidden-files             t
       treemacs-silent-filewatch              nil
       treemacs-silent-refresh                nil
       treemacs-sorting                       'alphabetic-desc
       treemacs-space-between-root-nodes      t
       treemacs-tag-follow-cleanup            t
       treemacs-tag-follow-delay              1.5
       treemacs-user-mode-line-format         nil
       treemacs-user-header-line-format       nil
       treemacs-width                         35)

  ;; The default width and height of the icons is 22 pixels. If you are
  ;; using a Hi-DPI display, uncomment this to double the icon size.
  ;; (treemacs-resize-icons 44)
  (treemacs-follow-mode t)
  (treemacs-filewatch-mode t)
  (treemacs-fringe-indicator-mode t)
  (pcase (cons (not (null (executable-find "git")))
  	     (not (null treemacs-python-executable)))
    (`(t . t)
     (treemacs-git-mode 'deferred))
    (`(t . _)
     (treemacs-git-mode 'simple))))

(straight-use-package 'treemacs-projectile)
(straight-use-package 'treemacs-icons-dired)
(straight-use-package 'treemacs-magit)

(use-package treemacs-projectile
  :after treemacs projectile)

(use-package treemacs-icons-dired
  :after treemacs dired
  :config (treemacs-icons-dired-mode))

(use-package treemacs-magit
  :after treemacs magit)

(use-package tree-sitter
  :defer t
  :ghook '(agda-mode-hook
  	 shell-mode-hook
  	 c-mode-hook
  	 c++-mode-hook
  	 css-mode-hook
  	 haskell-mode-hook
  	 html-mode-hook
  	 js-mode-hook
  	 js2-mode-hook
  	 son-mode-hook
  	 python-mode-hook
  	 ruby-mode-hook
  	 rust-mode-hook
  	 typescript-mode-hook)
  :config (require 'tree-sitter-langs))

(use-package tree-sitter-hl
  :defer t
  :ghook 'tree-sitter-after-on-hook)

(straight-use-package '(point-history :type git :host github :repo "blue0513/point-history"))
(use-package point-history
  :ghook 'after-init-hook
  :bind (("C-c C-/" . point-history-show))
  :init (gsetq point-history-ignore-buffer "^ \\*Minibuf\\|^ \\*point-history-show*"))

(straight-use-package 'undo-propose)
(use-package undo-propose
  :defer
  :config (undo-propose-wrap redo))

(dolist (package '(git-blamed
  		 git-timemachine))
  (straight-use-package package))

(straight-use-package 'git-modes)

(straight-use-package 'magit)
(use-package magit
  :defer t
  :commands magit-status
  :hook ((magit-popup-mode-hook . no-trailing-whitespace)
       (git-commit-mode . goto-address-mode))
  :init (gsetq magit-diff-refine-hunk t)
  :bind (([(meta f12)] . magit-status)  ;; Hint: customize `magit-repository-directories' so that you can use C-u M-F12 to
       ("C-x g"      . magit-status)
       ("C-x M-g"    . magit-dispatch-popup)
       :map magit-status-mode-map
       ("C-M-<up>"   . magit-section-up)
       :map vc-prefix-map
       ("f"          . vc-git-grep))
  :config
  (gsetq vc-handled-backends nil)
  (when *is-a-mac* (add-hook 'magit-mode-hook (lambda () (local-unset-key [(meta h)])))))

(straight-use-package 'magit-todos)
(use-package magit-todos
  :defer t
  :init
  (gsetq magit-todos-exclude-globs '("*.map")))

(straight-use-package 'magit-org-todos)
(use-package magit-org-todos
  :defer t
  :config (magit-org-todos-autoinsert))

(straight-use-package 'forge)

(straight-use-package 'transient)
(gsetq transient-default-level 5)

(straight-use-package 'git-messenger)
(use-package git-messenger
  :init (gsetq git-messenger:show-detail t)
  :bind (:map vc-prefix-map
       ("p" . git-messenger:popup-message)))

(straight-use-package 'git-gutter)
(use-package git-gutter
  :diminish
  :hook (after-init . global-git-gutter-mode)
  :init (gsetq git-gutter:visual-line t
  	     git-gutter:disabled-modes '(asm-mode image-mode)
  	     git-gutter:modified-sign "❚"
  	     git-gutter:added-sign "✚"
  	     git-gutter:deleted-sign "✘")

  :config (general-define-key
  	 :prefix "C-x"
  	 "v =" 'git-gutter:popup-hunk
  	 "p"   'git-gutter:previous-hunk
  	 "n"   'git-gutter:next-hunk))

(straight-use-package 'gist)

(use-package which-func
  :defer t
  :ghook 'after-init-hook)

(use-package which-key
  :init (gsetq which-key-allow-imprecise-window-fit nil)
  :ghook 'after-init-hook)

(use-package whitespace
  :preface
  (defun no-trailing-whitespace ()
    "Turn off display of trailing whitespace in this buffer."
    (setq show-trailing-whitespace nil))
  :init
  ;; But don't show trailing whitespace in SQLi, inf-ruby etc.
  (dolist (hook '(artist-mode-hook
  		picture-mode-hook
  		special-mode-hook
  		Info-mode-hook
  		eww-mode-hook
  		term-mode-hook
  		vterm-mode-hook
  		comint-mode-hook
  		compilation-mode-hook
  		twittering-mode-hook
  		minibuffer-setup-hook
  		fundamental-mode))
    (add-hook hook #'no-trailing-whitespace))
  :diminish whitespace-mode)

(straight-use-package 'whitespace-cleanup-mode)
(use-package whitespace-cleanup-mode
  :init
  (gsetq whitespace-cleanup-mode-only-if-initially-clean nil)
  (gsetq-default whitespace-style
  	       '(face tabs spaces trailing space-before-tab
  		      newline indentation empty space-after-tab
  		      space-mark tab-mark newline-mark))
  :hook ((after-init . global-whitespace-cleanup-mode))
  :diminish (whitespace-cleanup-mode)
  :bind (("<remap> <just-one-space>" . cycle-spacing)))

(straight-use-package 'writeroom-mode)
(use-package writeroom-mode
  :defer t
  :preface
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

(straight-use-package 'yasnippet)
(straight-use-package 'yasnippet-snippets)

(use-package yasnippet
  :defer t
  :commands (yas-minor-mode)
  :hook (((prog-mode text-mode) . yas-minor-mode))
  :config
  (add-to-list 'yas-snippet-dirs
  	     (concat user-emacs-directory "extra/snippets"))
  (yas-reload-all))

(nasy/s-u-p all-the-icons ob-restclient restclient)

(when (version< emacs-version "27")
  (nasy/s-u-p emojify))

(after-x 'company
  (nasy/s-u-p company-restclient))

(when (version< emacs-version "27")
  (use-package emojify
    :commands emojify-mode
    :hook ((after-init . global-emojify-mode))
    :init (gsetq emojify-emoji-styles '(unicode github)
  	       emojify-display-style 'unicode)))

(use-package all-the-icons
  :init (gsetq inhibit-compacting-font-caches t))

(straight-use-package 'dumb-jump)
(if *is-a-mac*
    (straight-use-package 'osx-dictionary)
  (mapcar 'straight-use-package
  	'(define-word
  	  powerthesaurus
  	  wordnut
  	  synosaurus)))

;;;###autodef
(defun set-lookup-handlers! (modes &rest plist)
  "Define jump handlers for major or minor MODES.
A handler is either an interactive command that changes the current buffer
and/or location of the cursor, or a function that takes one argument: the
identifier being looked up, and returns either nil (failed to find it), t
(succeeded at changing the buffer/moving the cursor), or 'deferred (assume this
handler has succeeded, but expect changes not to be visible yet).
There are several kinds of handlers, which can be defined with the following
properties:
:definition FN
  Run when jumping to a symbol's definition. Used by `nasy/lookup/definition'.
:implementations FN
  Run when looking for implementations of a symbol in the current project. Used
  by `nasy/lookup/implementations'.
:type-definition FN
  Run when jumping to a symbol's type definition. Used by
  `nasy/lookup/type-definition'.
:references FN
  Run when looking for usage references of a symbol in the current project. Used
  by `nasy/lookup/references'.
:documentation FN
  Run when looking up documentation for a symbol. Used by
  `nasy/lookup/documentation'.
:file FN
  Run when looking up the file for a symbol/string. Typically a file path. Used
  by `nasy/lookup/file'.
:xref-backend FN
  Defines an xref backend for a major-mode. A :definition and :references
  handler isn't necessary with a :xref-backend, but will have higher precedence
  if they exist.
:async BOOL
  Indicates that *all* supplied FNs are asynchronous. Note: lookups will not try
  any handlers after async ones, due to their nature. To get around this, you
  must write a specialized wrapper to await the async response, or use a
  different heuristic to determine, ahead of time, whether the async call will
  succeed or not.
  If you only want to specify one FN is async, declare it inline instead:
    (set-lookup-handlers! 'rust-mode
      :definition '(racer-find-definition :async t))
Handlers can either be interactive or non-interactive. Non-interactive handlers
must take one argument: the identifier being looked up. This function must
change the current buffer or window or return non-nil when it succeeds.
If it doesn't change the current buffer, or it returns nil, the lookup module
will fall back to the next handler in `nasy/lookup-definition-functions',
`nasy/lookup-implementations-functions', `nasy/lookup-type-definition-functions',
`nasy/lookup-references-functions', `nasy/lookup-file-functions' or
`nasy/lookup-documentation-functions'.
Consecutive `set-lookup-handlers!' calls will overwrite previously defined
handlers for MODES. If used on minor modes, they are stacked onto handlers
defined for other minor modes or the major mode it's activated in.
This can be passed nil as its second argument to unset handlers for MODES. e.g.
  (set-lookup-handlers! 'python-mode nil)
\(fn MODES &key DEFINITION IMPLEMENTATIONS TYPE-DEFINITION REFERENCES DOCUMENTATION FILE XREF-BACKEND ASYNC)"
  (declare (indent defun))
  (dolist (mode (nasy-enlist modes))
    (let ((hook (intern (format "%s-hook" mode)))
  	(fn   (intern (format "nasy/lookup--init-%s-handlers-h" mode))))
      (if (null (car plist))
  	(progn
  	  (remove-hook hook fn)
  	  (unintern fn nil))
      (fset
       fn
       (lambda ()
  	 (cl-destructuring-bind (&key definition implementations type-definition references documentation file xref-backend async)
  	     plist
  	   (cl-mapc #'nasy/lookup--set-handler
  		    (list definition
  			  implementations
  			  type-definition
  			  references
  			  documentation
  			  file
  			  xref-backend)
  		    (list 'nasy/lookup-definition-functions
  			  'nasy/lookup-implementations-functions
  			  'nasy/lookup-type-definition-functions
  			  'nasy/lookup-references-functions
  			  'nasy/lookup-documentation-functions
  			  'nasy/lookup-file-functions
  			  'xref-backend-functions)
  		    (make-list 5 async)
  		    (make-list 5 (or (eq major-mode mode)
  				     (and (boundp mode)
  					  (symbol-value mode))))))))
      (add-hook hook fn)))))


;;
;;; Helpers

(defun nasy/lookup--set-handler (spec functions-var &optional async enable)
  (when spec
    (cl-destructuring-bind (fn . plist)
      (nasy-enlist spec)
      (if (not enable)
  	(remove-hook functions-var fn 'local)
      (put fn 'nasy/lookup-async (or (plist-get plist :async) async))
      (add-hook functions-var fn nil 'local)))))

(defun nasy/lookup--run-handler (handler identifier)
  (if (commandp handler)
      (call-interactively handler)
    (funcall handler identifier)))

(defun nasy/lookup--run-handlers (handler identifier origin)
  (message (format "Looking up '%s' with '%s'" identifier handler))
  (condition-case-unless-debug e
      (let ((wconf (current-window-configuration))
  	  (result (condition-case-unless-debug e
  		      (nasy/lookup--run-handler handler identifier)
  		    (error
  		     (message (format "Lookup handler %S threw an error: %s" handler e))
  		     'fail))))
      (cond ((eq result 'fail)
  	     (set-window-configuration wconf)
  	     nil)
  	    ((or (get handler 'nasy/lookup-async)
  		 (eq result 'deferred)))
  	    ((or result
  		 (null origin)
  		 (/= (point-marker) origin))
  	     (prog1 (point-marker)
  	       (set-window-configuration wconf)))))
    ((error user-error)
     (message "Lookup handler %S: %s" handler e)
     nil)))

(defun nasy/lookup--jump-to (prop identifier &optional display-fn arg)
  (let* ((origin (point-marker))
       (handlers
  	(plist-get (list :definition 'nasy/lookup-definition-functions
  			 :implementations 'nasy/lookup-implementations-functions
  			 :type-definition 'nasy/lookup-type-definition-functions
  			 :references 'nasy/lookup-references-functions
  			 :documentation 'nasy/lookup-documentation-functions
  			 :file 'nasy/lookup-file-functions)
  		   prop))
       (result
  	(if arg
  	    (if-let
  		(handler
  		 (intern-soft
  		  (completing-read "Select lookup handler: "
  				   (delete-dups
  				    (remq t (append (symbol-value handlers)
  						    (default-value handlers))))
  				   nil t)))
  		(nasy/lookup--run-handlers handler identifier origin)
  	      (user-error "No lookup handler selected"))
  	  (run-hook-wrapped handlers #'nasy/lookup--run-handlers identifier origin))))
    (when (cond ((null result)
  	       (message "No lookup handler could find %S" identifier)
  	       nil)
  	      ((markerp result)
  	       (funcall (or display-fn #'switch-to-buffer)
  			(marker-buffer result))
  	       (goto-char result)
  	       result)
  	      (result))
      (with-current-buffer (marker-buffer origin)
      (better-jumper-set-jump (marker-position origin)))
      result)))


;;
;;; Lookup backends

(defun nasy/lookup--xref-show (fn identifier &optional show-fn)
  (let ((xrefs (funcall fn
  		      (xref-find-backend)
  		      identifier)))
    (when xrefs
      (funcall (or show-fn #'xref--show-defs)
  	     (lambda () xrefs)
  	     nil)
      (if (cdr xrefs)
  	'deferred
      t))))

(defun nasy/lookup-xref-definitions-backend-fn (identifier)
  "Non-interactive wrapper for `xref-find-definitions'"
  (nasy/lookup--xref-show 'xref-backend-definitions identifier xref--show-defs))

(defun nasy/lookup-xref-references-backend-fn (identifier)
  "Non-interactive wrapper for `xref-find-references'"
  (nasy/lookup--xref-show 'xref-backend-references identifier xref--show-defs))

(defun nasy/lookup-dumb-jump-backend-fn (_identifier)
  "Look up the symbol at point (or selection) with `dumb-jump', which conducts a
project search with ag, rg, pt, or git-grep, combined with extra heuristics to
reduce false positives.
This backend prefers \"just working\" over accuracy."
  (and (require 'dumb-jump nil t)
       (dumb-jump-go)))

(defun nasy/lookup-project-search-backend-fn (identifier)
  "Conducts a simple project text search for IDENTIFIER.
Uses and requires `+ivy-file-search' or `+helm-file-search'. Will return nil if
neither is available. These require ripgrep to be installed."
  (unless identifier
    (let ((query (rxt-quote-pcre identifier)))
      (ignore-errors
      (cond ((eq *ivy-or-helm* 'ivy)
  	     (nasy/ivy-file-search :query query)
  	     t)
  	    ((eq *ivy-or-helm* 'helm)
  	     (nasy/helm-file-search :query query)
  	     t))))))

;;
;;; Main commands

;;;###autoload
(defun nasy/lookup/definition (identifier &optional arg)
  "Jump to the definition of IDENTIFIER (defaults to the symbol at point).
Each function in `nasy/lookup-definition-functions' is tried until one changes the
point or current buffer. Falls back to dumb-jump, naive
ripgrep/the_silver_searcher text search, then `evil-goto-definition' if
evil-mode is active."
  (interactive (list (nasy/thing-at-point-or-region)
  		   current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
      ((nasy/lookup--jump-to :definition identifier nil arg))
      ((error "Couldn't find the definition of %S" identifier))))

;;;###autoload
(defun nasy/lookup/implementations (identifier &optional arg)
  "Jump to the implementations of IDENTIFIER (defaults to the symbol at point).
Each function in `nasy/lookup-implementations-functions' is tried until one changes
the point or current buffer."
  (interactive (list (nasy/thing-at-point-or-region)
  		   current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
      ((nasy/lookup--jump-to :implementations identifier nil arg))
      ((error "Couldn't find the implementations of %S" identifier))))

;;;###autoload
(defun nasy/lookup/type-definition (identifier &optional arg)
  "Jump to the type definition of IDENTIFIER (defaults to the symbol at point).
Each function in `nasy/lookup-type-definition-functions' is tried until one changes
the point or current buffer."
  (interactive (list (nasy/thing-at-point-or-region)
  		   current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
      ((nasy/lookup--jump-to :type-definition identifier nil arg))
      ((error "Couldn't find the definition of %S" identifier))))

;;;###autoload
(defun nasy/lookup/references (identifier &optional arg)
  "Show a list of usages of IDENTIFIER (defaults to the symbol at point)
Tries each function in `nasy/lookup-references-functions' until one changes the
point and/or current buffer. Falls back to a naive ripgrep/the_silver_searcher
search otherwise."
  (interactive (list (nasy/thing-at-point-or-region)
  		   current-prefix-arg))
  (cond ((null identifier) (user-error "Nothing under point"))
      ((nasy/lookup--jump-to :references identifier nil arg))
      ((error "Couldn't find references of %S" identifier))))

;;;###autoload
(defun nasy/lookup/documentation (identifier &optional arg)
  "Show documentation for IDENTIFIER (defaults to symbol at point or selection.
First attempts the :documentation handler specified with `set-lookup-handlers!'
for the current mode/buffer (if any), then falls back to the backends in
`nasy/lookup-documentation-functions'."
  (interactive (list (nasy/thing-at-point-or-region)
  		   current-prefix-arg))
  (cond ((nasy/lookup--jump-to :documentation identifier #'pop-to-buffer arg))
      ((user-error "Couldn't find documentation for %S" identifier))))

(defvar ffap-file-finder)
;;;###autoload
(defun nasy/lookup/file (path)
  "Figure out PATH from whatever is at point and open it.
Each function in `nasy/lookup-file-functions' is tried until one changes the point
or the current buffer.
Otherwise, falls back on `find-file-at-point'."
  (interactive
   (progn
     (require 'ffap)
     (list
      (or (ffap-guesser)
  	(ffap-read-file-or-url
  	 (if ffap-url-regexp "Find file or URL: " "Find file: ")
  	 (nasy/thing-at-point-or-region))))))
  (require 'ffap)
  (cond ((and path
  	    buffer-file-name
  	    (file-equal-p path buffer-file-name)
  	    (user-error "Already here")))

      ((nasy/lookup--jump-to :file path))

      ((stringp path) (find-file-at-point path))

      ((call-interactively #'find-file-at-point))))


;;
;;; Dictionary

;;;###autoload
(defun nasy/lookup/dictionary-definition (identifier &optional arg)
  "Look up the definition of the word at point (or selection)."
  (interactive
   (list (or (nasy/thing-at-point-or-region 'word)
  	   (read-string "Look up in dictionary: "))
       current-prefix-arg))
  (message "Looking up definition for %S" identifier)
  (cond ((and *is-a-mac* (require 'osx-dictionary nil t))
       (osx-dictionary--view-result identifier))
      ((and nasy/lookup-dictionary-prefer-offline
  	    (require 'wordnut nil t))
       (unless (executable-find wordnut-cmd)
  	 (user-error "Couldn't find %S installed on your system"
  		     wordnut-cmd))
       (wordnut-search identifier))
      ((require 'define-word nil t)
       (define-word identifier nil arg))
      ((user-error "No dictionary backend is available"))))

;;;###autoload
(defun nasy/lookup/synonyms (identifier &optional _arg)
  "Look up and insert a synonym for the word at point (or selection)."
  (interactive
   (list (nasy/thing-at-point-or-region 'word) ; TODO actually use this
       current-prefix-arg))
  (message "Looking up synonyms for %S" identifier)
  (cond ((and nasy/lookup-dictionary-prefer-offline
  	    (require 'synosaurus-wordnet nil t))
       (unless (executable-find synosaurus-wordnet--command)
  	 (user-error "Couldn't find %S installed on your system"
  		     synosaurus-wordnet--command))
       (synosaurus-choose-and-replace))
      ((require 'powerthesaurus nil t)
       (powerthesaurus-lookup-word-dwim))
      ((user-error "No thesaurus backend is available"))))

(defvar nasy/lookup-definition-functions
  '(nasy/lookup-xref-definitions-backend-fn
    nasy/lookup-dumb-jump-backend-fn
    nasy/lookup-project-search-backend-fn)
  "Functions for `nasy/lookup/definition' to try, before resorting to `dumb-jump'.
Stops at the first function to return non-nil or change the current
window/point.
If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar nasy/lookup-implementations-functions ()
  "Function for `nasy/lookup/implementations' to try. Stops at the first function to
return non-nil or change the current window/point.
If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar nasy/lookup-type-definition-functions ()
  "Functions for `nasy/lookup/type-definition' to try. Stops at the first function to
return non-nil or change the current window/point.
If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar nasy/lookup-references-functions
  '(nasy/lookup-xref-references-backend-fn
    nasy/lookup-project-search-backend-fn)
  "Functions for `nasy/lookup/references' to try, before resorting to `dumb-jump'.
Stops at the first function to return non-nil or change the current
window/point.
If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar nasy/lookup-documentation-functions
  '(nasy/lookup-online-backend-fn)
  "Functions for `nasy/lookup/documentation' to try, before resorting to
`dumb-jump'. Stops at the first function to return non-nil or change the current
window/point.
If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar nasy/lookup-file-functions ()
  "Function for `nasy/lookup/file' to try, before restoring to `find-file-at-point'.
Stops at the first function to return non-nil or change the current
window/point.
If the argument is interactive (satisfies `commandp'), it is called with
`call-interactively' (with no arguments). Otherwise, it is called with one
argument: the identifier at point. See `set-lookup-handlers!' about adding to
this list.")

(defvar nasy/lookup-dictionary-prefer-offline *lookup/offline*
  "If non-nil, look up dictionaries online.
Setting this to nil will force it to use offline backends, which may be less
than perfect, but available without an internet connection.
Used by `nasy/lookup/dictionary-definition' and `nasy/lookup/synonyms'.
For `nasy/lookup/dictionary-definition', this is ignored on Mac, where Emacs users
Dictionary.app behind the scenes to get definitions.")

(use-package dumb-jump
  :defer t
  :commands dumb-jump-result-follow
  :hook ((dumb-jump-after-jump . better-jumper-set-jump))
  :config
  (gsetq dumb-jump-prefer-searcher 'rg
       dumb-jump-aggressive nil
       dumb-jump-selector   'ivy))

;;
;;; xref

;; The lookup commands are superior, and will consult xref if there are no
;; better backends available.
(general-define-key
 [remap xref-find-definitions] #'nasy/lookup/definition
 [remap xref-find-references]  #'nasy/lookup/references)

(after-x 'xref
  ;; We already have `projectile-find-tag' and `evil-jump-to-tag', no need for
  ;; xref to be one too.
  (remove-hook 'xref-backend-functions #'etags--xref-backend)
  ;; ...however, it breaks `projectile-find-tag', unless we put it back.
  (defun nasy/lookup--projectile-find-tag-a (orig-fn)
    "Fix it back advice."
    (let ((xref-backend-functions '(etags--xref-backend t)))
      (funcall orig-fn)))
  (advice-add
   #'projectile-find-tag :around
   #'nasy/lookup--projectile-find-tag-a))

(unless *is-a-mac*
  (use-package define-word
    :defer t))

(general-define-key
 :keymaps 'text-mode-map
 [remap nasy/lookup/definition] #'nasy/lookup/dictionary-definition
 [remap nasy/lookup/references] #'nasy/lookup/synonyms)

(gsetq synosaurus-choose-method 'default)

(nasy/s-u-p
 company-restclient
 elvish-mode
 fish-completion
 fish-mode
 markdown-mode
 ob-elvish
 ob-restclient
 pandoc-mode
 restclient
 toml-mode
 yaml-mode)

(when *rust*
  (nasy/s-u-p cargo rust-mode))

(nasy/s-u-p macrostep)
(when *ccls*
    (nasy/s-u-p ccls))

(use-package macrostep
  :defer t
  :general
  (:keymaps 'c-mode-map
  	  "C-c e" #'macrostep-expand)
  (:keymaps 'c++-mode-map
  	  "C-c e" #'macrostep-expand)
  (:keymaps 'objc-mode-map
  	  "C-c e" #'macrostep-expand))

(use-package lsp-mode
  :if *clangd*
  :hook (((c-mode c++-mode objc-mode) . lsp-deferred))
  :init (setq-default lsp-clients-clangd-executable *clangd*))

(when *ccls*
  (use-package ccls
    :preface
    (defun ccls/load ()
      (require 'ccls)
      (lsp-deferred))
    :hook (((c-mode c++-mode objc-mode) . ccls/load))
    :init
    (gsetq ccls-executable *ccls*
  	 ccls-initialization-options
  	 '(:clang (:extraArgs
  		   ["-isysroot"
  		    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"])
  	   :index (:comments 2)
  	   :completion (:detailedLabel t)
  	   ccls-sem-highlight-method 'font-lock))
    (gsetq ccls-sem-function-colors
  	 '("#e5b124" "#927754" "#eb992c" "#e2bf8f" "#d67c17"
  	   "#88651e" "#e4b953" "#a36526" "#b28927" "#d69855")
  	 ccls-sem-macro-colors
  	 '("#e79528" "#c5373d" "#e8a272" "#d84f2b" "#a67245"
  	   "#e27a33" "#9b4a31" "#b66a1e" "#e27a71" "#cf6d49")
  	 ccls-sem-namespace-colors
  	 '("#aa96da" "#fcbad3" "#ffffd2" "#a8d8ea" "#ffcfdf"
  	   "#fefdca" "#e0f9b5" "#a5dee5" "#eef9bf" "#a7e9af")
  	 ccls-sem-parameter-colors
  	 '("#aa96da" "#fcbad3" "#ffffd2" "#a8d8ea" "#ffcfdf"
  	   "#fefdca" "#e0f9b5" "#a5dee5" "#eef9bf" "#a7e9af")
  	 ccls-sem-type-colors
  	 '("#e1afc3" "#d533bb" "#9b677f" "#e350b6" "#a04360"
  	   "#dd82bc" "#de3864" "#ad3f87" "#dd7a90" "#e0438a"))
    :config
    (ccls-use-default-rainbow-sem-highlight)
    (defun ccls/callee ()
      (interactive)
      (lsp-ui-peek-find-custom "$ccls/call" '(:callee t)))
    (defun ccls/caller ()
      (interactive)
      (lsp-ui-peek-find-custom "$ccls/call"))
    (defun ccls/vars (kind)
      (lsp-ui-peek-find-custom "$ccls/vars" `(:kind ,kind)))
    (defun ccls/base (levels)
      (lsp-ui-peek-find-custom "$ccls/inheritance" `(:levels ,levels)))
    (defun ccls/derived (levels)
      (lsp-ui-peek-find-custom "$ccls/inheritance" `(:levels ,levels :derived t)))
    (defun ccls/member (kind)
      (lsp-ui-peek-find-custom "$ccls/member" `(:kind ,kind)))

    ;; The meaning of :role corresponds to https://github.com/maskray/ccls/blob/master/src/symbol.h

    ;; References w/ Role::Address bit (e.g. variables explicitly being taken addresses)
    (defun ccls/references-address ()
      (interactive)
      (lsp-ui-peek-find-custom "textDocument/references"
       (plist-put (lsp--text-document-position-params) :role 128)))

    ;; References w/ Role::Dynamic bit (macro expansions)
    (defun ccls/references-macro ()
      (interactive)
      (lsp-ui-peek-find-custom "textDocument/references"
       (plist-put (lsp--text-document-position-params) :role 64)))

    ;; References w/o Role::Call bit (e.g. where functions are taken addresses)
    (defun ccls/references-not-call ()
      (interactive)
      (lsp-ui-peek-find-custom "textDocument/references"
       (plist-put (lsp--text-document-position-params) :excludeRole 32)))

    ;; References w/ Role::Read
    (defun ccls/references-read ()
      (interactive)
      (lsp-ui-peek-find-custom "textDocument/references"
       (plist-put (lsp--text-document-position-params) :role 8)))

    ;; References w/ Role::Write
    (defun ccls/references-write ()
      (interactive)
      (lsp-ui-peek-find-custom "textDocument/references"
       (plist-put (lsp--text-document-position-params) :role 16)))

    ;; xref-find-apropos (workspace/symbol)

    (defun my/highlight-pattern-in-text (pattern line)
      (when (> (length pattern) 0)
      (let ((i 0))
       (while (string-match pattern line i)
  	 (setq i (match-end 0))
  	 (add-face-text-property (match-beginning 0) (match-end 0) 'isearch t line))
       line)))

    (after! lsp-methods
      ;;; Override
      ;; This deviated from the original in that it highlights pattern appeared in symbol
      (defun lsp--symbol-information-to-xref (pattern symbol)
       "Return a `xref-item' from SYMBOL information."
       (let* ((location (gethash "location" symbol))
  	    (uri (gethash "uri" location))
  	    (range (gethash "range" location))
  	    (start (gethash "start" range))
  	    (name (gethash "name" symbol)))
       (xref-make (format "[%s] %s"
  			  (alist-get (gethash "kind" symbol) lsp--symbol-kind)
  			  (my/highlight-pattern-in-text (regexp-quote pattern) name))
  		  (xref-make-file-location (string-remove-prefix "file://" uri)
  					   (1+ (gethash "line" start))
  					   (gethash "character" start)))))

      (cl-defmethod xref-backend-apropos ((_backend (eql xref-lsp)) pattern)
      (let ((symbols (lsp--send-request (lsp--make-request
  					 "workspace/symbol"
  					 `(:query ,pattern)))))
  	(mapcar (lambda (x) (lsp--symbol-information-to-xref pattern x)) symbols))))))

(straight-use-package 'bing-dict)
(use-package bing-dict
  :bind (("C-c d" . bing-dict-brief))
  :init (gsetq bing-dict-show-thesaurus  'both
  	     bing-dict-vocabulary-save t
  	     bing-dict-cache-auto-save t
  	     bing-dict-vocabulary-file
  	     (no-littering-expand-var-file-name "bing-dict/vocabulary.org")
  	     bing-dict-cache-file
  	     (no-littering-expand-var-file-name "bing-dict/bing-dict-save.el")))

(use-package ispell
  :if *ispell*
  :init
  (gsetq-default ispell-program-name   *ispell*
  	       ispell-silently-savep t
  	       ispell-dictionary     "english"
  	       ispell-personal-dictionary
  	       (no-littering-expand-var-file-name "ispell/dictionary"))
  (when (string-suffix-p "aspell" *ispell*)
    (gsetq-default ispell-extra-args '("--reverse"))))

(unless *ispell*
  (message "if you want to use ispell, try\n brew install aspell\n brew install ispell"))

(straight-use-package 'haskell-mode)
(use-package haskell-mode
  :preface
  (define-minor-mode stack-exec-path-mode
    "If this is a stack project, set `exec-path' to the path \"stack exec\" would use."
    nil
    :lighter ""
    :global nil
    (if stack-exec-path-mode
      (when (and (executable-find "stack")
  		 (locate-dominating-file default-directory "stack.yaml"))
  	(setq-local
  	 exec-path
  	 (seq-uniq
  	  (append (list (concat (string-trim-right (shell-command-to-string "stack path --local-install-root")) "/bin"))
  		  (parse-colon-path
  		   (replace-regexp-in-string "[\r\n]+\\'" ""
  					     (shell-command-to-string "stack path --bin-path"))))
  	  'string-equal)))
      (kill-local-variable 'exec-path)))

  :gfhook '(subword-mode
  	  haskell-auto-insert-module-template
  	  haskell-collapse-mode
  	  stack-exec-path-mode
  	  interactive-haskell-mode
  	  (lambda () (gsetq-local tab-width 4)))
  :bind (("C-x a a" . align)
       :map haskell-mode-map
       ("C-c h" . hoogle)
       ("C-o"   . open-line))
  :init
  (gsetq haskell-mode-stylish-haskell-path            "stylish-haskell"
       haskell-indentation-layout-offset            4
       haskell-indentation-left-offset              4
       haskell-process-suggest-haskell-docs-imports t
       haskell-process-suggest-remove-import-lines  t
       haskell-process-auto-import-loaded-modules   t
       haskell-process-log                          t
       haskell-process-suggest-hayoo-imports        t
       haskell-process-suggest-hoogle-imports       t
       haskell-process-suggest-remove-import-lines  t
       haskell-tags-on-save                         t
       ;; haskell-completing-read-function             'helm--completing-read-default
       haskell-doc-show-global-types                t
       haskell-svg-render-images                    t
       haskell-doc-chop-off-context                 nil)

  (unless *struct-hs*
    (add-hook #'haskell-mode-hook #'haskell-indentation-mode))

  (unless (fboundp 'align-rules-list)
    (defvar align-rules-list nil))

  (add-to-list 'align-rules-list
  	     '(haskell-types
  	       (regexp . "\\(\\s-+\\)\\(::\\|∷\\)\\s-+")
  	       (modes quote (haskell-mode literate-haskell-mode))))
  (add-to-list 'align-rules-list
  	     '(haskell-assignment
  	       (regexp . "\\(\\s-+\\)=\\s-+")
  	       (modes quote (haskell-mode literate-haskell-mode))))
  (add-to-list 'align-rules-list
  	     '(haskell-arrows
  	       (regexp . "\\(\\s-+\\)\\(->\\|→\\)\\s-+")
  	       (modes quote (haskell-mode literate-haskell-mode))))
  (add-to-list 'align-rules-list
  	     '(haskell-left-arrows
  	       (regexp . "\\(\\s-+\\)\\(<-\\|←\\)\\s-+")
  	       (modes quote (haskell-mode literate-haskell-mode))))

  :config
  (after! page-break-lines
    (push 'haskell-mode page-break-lines-modes))
  (defun haskell-mode-generate-tags (&optional and-then-find-this-tag)
    "Generate tags using Hasktags.  This is synchronous function.

  If optional AND-THEN-FIND-THIS-TAG argument is present it is used
  with function `xref-find-definitions' after new table was
  generated."
    (interactive)
    (let* ((dir (haskell-cabal--find-tags-dir))
  	 (command (haskell-cabal--compose-hasktags-command dir)))
      (if (not command)
  	(error "Unable to compose hasktags command")
      ;; I disabled the noisy shell command output.
      ;; The original is (shell-command command)
      (call-process-shell-command command nil "*Shell Command Output*" t)
      (haskell-mode-message-line "Tags generated.")
      (when and-then-find-this-tag
  	(let ((tags-file-name dir))
  	  (xref-find-definitions and-then-find-this-tag)))))))

(straight-use-package 'lsp-haskell)
(use-package lsp-haskell
  :preface
  (defun start-lsp-haskell ()
    (require 'lsp)
    (require 'lsp-haskell)
    (lsp-deferred))
  :defer t
  :hook ((haskell-mode . start-lsp-haskell))
  :init
  (nasy/add-company-backend 'haskell-mode '(company-capf
  					  company-lsp
  					  company-files
  					  :with company-tabnine company-yasnippet))
  ;; (gsetq lsp-haskell-process-path-hie "hie-8.6.5")
  ;; You can set the lsp-haskell settings here
  ;; (lsp-haskell-set-hlint-on)                    ;; default on
  ;; (lsp-haskell-set-max-number-of-problems 100)  ;; default 100
  ;; (lsp-haskell-set-liquid-on)                   ;; default off
  ;; (lsp-haskell-set-completion-snippets-on)      ;; default on
  ;; (gsetq lsp-haskell-process-path-hie "ghcide")
  ;; (gsetq lsp-haskell-process-args-hie '())
  )

(when *intero*
  (straight-use-package 'intero)
  (use-package intero
    :hook ((haskell-mode . intero-mode))
    :config
    (define-key intero-mode-map (kbd "M-?") nil)
    (define-key intero-mode-map (kbd "C-c C-r") nil)))

(if *struct-hs*
    (progn
      (add-to-list 'load-path *struct-hs-path*)
      (require 'shm)
      (setq shm-program-name *struct-hs*)
      (add-hook #'haskell-mode-hook #'structured-haskell-mode))
  (progn
    (when *struct-hs*
      (message (concat "*NOTE* about structured-haskell-mode:\n"
  		     "https://github.com/projectional-haskell/structured-haskell-mode\n"
  		     "No structured-haskell-mode elisp find.\n"
  		     "If you want to use it, \n"
  		     "please install it and config its variables *struct-hs-path* in user-config.el\n")))))

(straight-use-package 'haskell-snippets)

(use-package lsp-html
  :hook ((html-mode . lsp-deferred)))

(use-package lsp-mode
  :disabled t
  :hook ((javascript-mode . lsp-deferred)))

(mapcar 'straight-use-package
      '(lsp-mode
  	lsp-ui
  	;; company-lsp
  	dap-mode
  	lsp-treemacs))

;;;###autoload
(defun delete-company-lsp ()
  "Delete company-lsp added by lsp-mode from company-backends"
  (when 'company-backends
    (gsetq company-backends (delete 'intero-company company-backends)
  	 company-backends (delete 'company-lsp    company-backends))))

(defvar lsp-company-backend 'company-lsp
  "What backend to use for lsp-driven autocompletion.
This can be overridden by `lsp-capf-blacklist'.
While `company-capf' does not require the `company-lsp' package and should offer
better performance, it has been integrated into lsp only recently and as of
02/25/2020 is known to cause issues with some language servers. If you wish to
use `company-capf' in general but fall back to `company-lsp' for specific
language servers, set `lsp-company-backend' to `company-capf' and add the
excluded servers' identifiers to `lsp-capf-blacklist'.")

(defvar lsp-capf-blacklist '(ts-ls gopls)
  "Language servers listed here will always use the `company-lsp' backend,
irrespective of what `lsp-company-backend' is set to.")

(use-package lsp-mode
  :commands (nasy/lsp-init lsp-install-server)
  :defer t
  :preface
  (defun nasy/lsp-init ()
    "Nasy lsp mode init."
    (lsp-flycheck-enable)
    (flycheck-inline-mode -1)
    (when lsp-enable-symbol-highlighting
      (add-hook #'lsp-on-idle-hook #'lsp--document-highlight nil t)
      (lsp--info "Symbol highlighting enabled in current buffer."))
    (lsp-enable-which-key-integration))
  :hook ((lsp-mode . nasy/lsp-init))
  :init
  (gsetq lsp-log-io                         *debug*
       lsp-log-max                        t
       lsp-print-performance              *debug*
       lsp-inhibit-message                t
       lsp-report-if-no-buffer            *debug*
       ;; Auto-kill LSP server once you've killed the last buffer
       ;; associated with its project.
       lsp-keep-workspace-alive           nil
       lsp-enable-snippet                 t
       lsp-auto-guess-root                nil
       lsp-restart                        'interactive
       lsp-auto-configure                 nil
       lsp-document-sync-method           nil
       lsp-auto-execute-action            nil
       lsp-eldoc-enable-hover             t
       lsp-eldoc-render-all               t
       lsp-enable-completion-at-point     nil
       lsp-enable-imenu                   t
       lsp-enable-xref                    t
       lsp-enable-links                   t
       lsp-enable-indentation             t
       lsp-diagnostic-package             :auto
       lsp-enable-on-type-formatting      t
       lsp-signature-auto-activate        t
       lsp-enable-semantic-highlighting   t
       lsp-signature-render-documentation t
       lsp-enable-file-watchers           nil
       lsp-enable-text-document-color     t
       lsp-prefer-capf                    t)

  :config
  (set-lookup-handlers! 'lsp-mode :async t
    :documentation #'lsp-describe-thing-at-point
    :definition #'lsp-find-definition
    :implementations #'lsp-find-implementation
    :type-definition #'lsp-find-type-definition
    :references #'lsp-find-references)
  ;; Don't prompt to restart LSP servers while quitting Emacs
  (add-hook 'kill-emacs-hook #'(lambda () (setq lsp-restart 'ignore))))

(use-package lsp-ui
  :commands lsp-ui-mode
  :hook ((lsp-mode . lsp-ui-mode))
  :init
  (gsetq lsp-ui-doc-enable                nil
       lsp-ui-doc-position              'at-point
       lsp-ui-doc-header                nil
       lsp-ui-doc-border                "violet"
       lsp-ui-doc-include-signature     t
       lsp-ui-sideline-update-mode      'point
       lsp-ui-sideline-delay            1
       lsp-ui-sideline-show-hover       t
       lsp-ui-sideline-ignore-duplicate t)
  :config
  (after-x 'lsp-ui
    (require 'lsp-ui-peek)
    (set-lookup-handlers! 'lsp-ui-mode :async t
      :definition 'lsp-ui-peek-find-definitions
      :implementations 'lsp-ui-peek-find-implementation
      :references 'lsp-ui-peek-find-references)))

;; (defun nasy/lsp-init-company-h ()
;;   (if (not (bound-and-true-p company-mode))
;;       (add-hook 'company-mode-hook #'nasy/lsp-init-company-h t t)
;;     (setq-local company-backends
;;                 (cons '(company-capf
;;                         company-files
;;                         :with company-yasnippet)
;;                       (remq 'company-capf company-backends)))
;;     (remove-hook 'company-mode-hook #'nasy/lsp-init-company-h t)))

;; (use-package company-lsp
;;   :defer t
;;   :commands company-lsp
;;   :hook ((lsp-mode . nasy/lsp-init-company-h))
;;   :init
;;   (gsetq company-lsp-async               t
;;          company-lsp-cache-candidates    'auto)
;;   :config
;;   (with-no-warnings
;;     ;; WORKAROUND: Fix tons of unrelated completion candidates shown
;;     ;; when a candidate is fulfilled
;;     ;; @see https://github.com/emacs-lsp/lsp-python-ms/issues/79
;;     (add-to-list 'company-lsp-filter-candidates '(mspyls . t))

;;     (defun nasy/company-lsp--on-completion (response prefix)
;;       "Handle completion RESPONSE.
;; PREFIX is a string of the prefix when the completion is requested.
;; Return a list of strings as the completion candidates."
;;       (let* ((incomplete (and (hash-table-p response) (gethash "isIncomplete" response)))
;;              (items (cond ((hash-table-p response) (gethash "items" response))
;;                           ((sequencep response) response)))
;;              (candidates (mapcar (lambda (item)
;;                                    (company-lsp--make-candidate item prefix))
;;                                  (lsp--sort-completions items)))
;;              (server-id (lsp--client-server-id (lsp--workspace-client lsp--cur-workspace)))
;;              (should-filter (or (eq company-lsp-cache-candidates 'auto)
;;                                 (and (null company-lsp-cache-candidates)
;;                                      (company-lsp--get-config company-lsp-filter-candidates server-id)))))
;;         (when (null company-lsp--completion-cache)
;;           (add-hook 'company-completion-cancelled-hook #'company-lsp--cleanup-cache nil t)
;;           (add-hook 'company-completion-finished-hook #'company-lsp--cleanup-cache nil t))
;;         (when (eq company-lsp-cache-candidates 'auto)
;;           ;; Only cache candidates on auto mode. If it's t company caches the
;;           ;; candidates for us.
;;           (company-lsp--cache-put prefix (company-lsp--cache-item-new candidates incomplete)))
;;         (if should-filter
;;             (company-lsp--filter-candidates candidates prefix)
;;           candidates)))
;;     (advice-add #'company-lsp--on-completion
;;                 :override
;;                 #'nasy/company-lsp--on-completion)))

(use-package lsp-treemacs
  :commands lsp-treemacs-errors-list
  :config
  (lsp-treemacs-sync-mode t)
  (gsetq lsp-metals-treeview-show-when-views-received t))

(straight-register-package
 '(parinfer-rust-mode :type git
  		    :host github
  		    :repo "justinbarclay/parinfer-rust-mode"))

(nasy/s-u-p cl-lib-highlight
  	  elisp-def
  	  highlight-quoted
  	  macrostep
  	  parinfer-rust-mode)

(after-x 'lisp-mode
  (use-package cl-lib-highlight
    :config
    (cl-lib-highlight-initialize)))

(use-package elisp-def
  :defer t
  :hook (((emacs-lisp-mode ielm-mode) . elisp-def-mode)))

(use-package highlight-quoted
  :defer t
  :hook ((emacs-lisp-mode . highlight-quoted-mode)))

(use-package lisp-mode
  :preface
  (defun eval-last-sexp-or-region (prefix)
    "Eval region from BEG to END if active, otherwise the last sexp."
    (interactive "P")
    (if (and (mark) (use-region-p))
      (eval-region (min (point) (mark)) (max (point) (mark)))
      (pp-eval-last-sexp prefix)))
  :general
  (:keymaps 'emacs-lisp-mode-map
  	  [remap eval-expression] #'pp-eval-expression
  	  "C-x C-e"               #'eval-last-sexp-or-region))

(use-package macrostep
  :defer t
  :general
  (:keymaps #'emacs-lisp-mode-map
  	  "C-c e" #'macrostep-expand))

(use-package parinfer-rust-mode
  :defer t
  :init
  (gsetq parinfer-rust-library       (no-littering-expand-var-file-name "parinfer-rust/parinfer-rust-darwin.so")
       parinfer-rust-auto-download t)
  :ghook lisp-modes-hooks)

(use-package markdown-mode
  :defer t
  :mode ("INSTALL\\'"
       "CONTRIBUTORS\\'"
       "LICENSE\\'"
       "README\\'"
       "\\.markdown\\'"
       "\\.md\\'"))

(let ((packages '(flycheck-mypy py-isort python-docstring sphinx-doc pyimport)))
  (dolist (package packages)
    (straight-use-package package)))
(when *pyblack*
  (straight-use-package 'python-black))

(let ((module
       (cond ((eq *py-module* 'elpy)    'elpy)
  	   ((eq *py-module* 'pyls)    'lsp-mode)
  	   ((eq *py-module* 'mspyls)  'lsp-python-ms)
  	   ((eq *py-module* 'pylance) 'elpy))))
  (straight-use-package module))

;;;###autoload
(defcustom nasy*python-buffer "vterm"
  "Nasy Python Buffer"
  :group 'python-mode
  :type 'string)

;;;###autoload
(defun nasy/python-send-buffer ()
  "Send current buffer to the running python process."
  (interactive)
  (let ((proc (get-buffer-process nasy*python-buffer)))
    (unless proc
      (error "No process found"))
    (save-buffer)
    (comint-simple-send proc
  		      (concat "%run " (format "%s" (buffer-file-name))))
    (pop-to-buffer nasy*python-buffer)))

;;;###autoload
(defun nasy/python-send-region (begin end)
  "Evaluate the code in region from BEGIN to END in the python repl.
if the region is unset, the current line will be used."
  (interactive "r")
  (unless (use-region-p)
    (setq begin (line-beginning-position)
  	end (line-end-position)))
  (let* ((text (buffer-substring-no-properties begin end))
       (proc (get-buffer-process nasy*python-buffer)))
    (unless proc
      (error "No process found"))
    (comint-simple-send proc text)
    (display-buffer nasy*python-buffer)))

;;;###autoload
(defun nasy/python-send-defun (&optional arg)
  "Send the current defun to inferior Python process.
When ARG is non-nil do not include decorators."
  (interactive (list current-prefix-arg t))
  (nasy:python-send-region
   (progn
     (end-of-line 1)
     (while (and (or (python-nav-beginning-of-defun)
  		   (beginning-of-line 1))
  	       (> (current-indentation) 0)))
     (when (not arg)
       (while (and (forward-line -1)
  		 (looking-at (python-rx decorator))))
       (forward-line 1))
     (point-marker)
     (progn
       (or (python-nav-end-of-defun)
  	 (end-of-line 1))
       (point-marker)))))

;;;###autoload
(defun nasy/python-switch-to-shell ()
  "Switch to inferior Python process buffer."
  (interactive "p")
  (let ((proc (get-buffer-process nasy:python-buffer)))
    (unless proc
      (error "No process found"))
    (pop-to-buffer nasy*python-buffer)))

(general-define-key
 :prefix "C-c"
 :keymaps 'python-mode-map
 "C-b" 'nasy/python-send-buffer
 "C-r" 'nasy/python-send-region
 "C-c" 'nasy/python-send-defun
 "C-z" 'nasy/python-switch-to-shell)
(general-define-key
 :keymaps 'python-mode-map
 "<S-return>" 'nasy/python-send-region)


(defun python-flycheck-setup ()
  "Add python checker for lsp-ui."
  (after-x 'lsp-ui
    (flycheck-add-next-checker 'lsp              'python-flake8))
    ;; flake8 already have python-mypy and python-pylint as the next checker
    ;; (flycheck-add-next-checker 'python-flake8    'python-mypy)))
  (flycheck-disable-checker 'python-pylint)
  (flycheck-remove-next-checker 'python-flake8 'python-pylint))

(use-package elpy
  :if (or (eq *py-module* 'elpy)
       (eq *py-module* 'pylance))
  :defer t
  :init
  ;; (add-to-list 'exec-path "/Users/Nasy/Library/Python/3.7/bin")
  (gsetq elpy-rpc-virtualenv-path 'current)
  (advice-add 'python-mode :before 'elpy-enable)


  (gsetq elpy-modules '(elpy-module-company
  		      elpy-module-folding
  		      elpy-module-yasnippet))

  (when (eq *py-module* 'elpy)
    (add-to-list 'elpy-modules 'elpy-module-autodoc)
    (add-to-list 'elpy-modules 'elpy-module-eldoc))

  :config
  (when (eq *py-module* 'elpy)
    (nasy/add-company-backend 'python-mode '(elpy-company-backend
  					   company-files
  					   :with company-tabnine company-yasnippet))

    (set-lookup-handlers! 'python-mode :async t
      :documentation #'elpy-doc
      :definition #'elpy-goto-definition
      :implementations #'elpy-goto-assignment
      :references #'xref-find-references))

  (advice-add
   'elpy-module-folding :after
   #'(lambda (&rest _)
       (define-key elpy-mode-map (kbd "<mouse-1>") nil))))

(use-package lsp-pyls
  :if (eq *py-module* 'pyls)
  :defer t
  :init
  (defun start-lsp-pyls ()
    "Start lsp-pyls."
    (require 'lsp-pyls)
    (lsp-deferred))
  :hook ((python-mode . start-lsp-pyls)
       (after-init  . python-flycheck-setup))
  :config
  (nasy/add-company-backend 'python-mode '(company-capf
  					 company-files
  					 :with company-tabnine company-yasnippet))
  ;; A list here https://github.com/palantir/python-language-server/blob/develop/vscode-client/package.json#L23-L230
  ;; I prefer pydocstyle and black, so disabled yapf, though, pydocstyle still cannot be abled.
  ;; pip install black pyls-black -U
  ;; The default line-length is 88 when using black, you can add a file named "pyproject.yaml" that contains
  ;; [tool.black]
  ;; line-length = 79
  (gsetq lsp-pyls-configuration-sources              ["pycodestyle" "pydocstyle" "flake8"]
       lsp-pyls-plugins-pylint-enabled             nil
       lsp-pyls-plugins-pycodestyle-enabled        t
       lsp-pyls-plugins-pydocstyle-enabled         t
       lsp-pyls-plugins-pydocstyle-convention      "numpy"
       lsp-pyls-plugins-pydocstyle-add-select.     '("D107" "D413" "D415" "D416")
       lsp-pyls-plugins-rope-completion-enabled    t
       lsp-pyls-plugins-autopep8-enabled           t
       lsp-pyls-plugins-yapf-enabled               nil
       lsp-pyls-plugins-flake8-enabled             t)

  (unless *pyblack*
    (add-hook #'python-mode-hook
  	    #'(lambda () (add-hook #'before-save-hook #'lsp-format-buffer nil t)))))

(use-package lsp-python-ms
  :if (eq *py-module* 'mspyls)
  :defer t
  :preface
  (defun start-lsp-mspyls ()
    "Start lsp-python-ms."
    (require 'lsp-python-ms)
    (lsp-deferred))
  :init
  (nasy/add-company-backend 'python-mode '(company-capf
  					 company-files
  					 :with company-tabnine company-yasnippet))
  (gsetq
   lsp-python-ms-nupkg-channel "daily"
   lsp-python-ms-log-level     (if *debug* "Trace" "Error")
   lsp-python-ms-executable    (executable-find "Microsoft.Python.LanguageServer")
   lsp-python-ms-information   ["too-many-function-arguments"
  			      "too-many-positional-arguments-before-star"]
   lsp-python-ms-errors        ["inherit-non-class"
  			      "no-method-argument"
  			      "parameter-already-specified"
  			      "parameter-missing"
  			      "positional-argument-after-keyword"
  			      "positional-only-named"
  			      "return-in-init"
  			      "typing-generic-arguments"
  			      "typing-newtype-arguments"
  			      "typing-typevar-arguments"
  			      "unknown-parameter-name"
  			      "undefined-variable"]
   lsp-python-ms-warnings      ["no-cls-argument"
  			      "no-self-argument"
  			      "unresolved-import"
  			      "variable-not-defined-globally"
  			      "variable-not-defined-nonlocal"])
  :hook ((python-mode . start-lsp-mspyls)))

(when (eq *py-module* 'pylance)

  (nasy/add-company-backend 'python-mode
    '(company-capf
      elpy-company-backend
      company-files
      :with company-tabnine company-yasnippet))

  (defun nasy/lsp-pylance ()

    (require 'lsp-mode)

    (defvar lsp-pylance-executable (executable-find "pylance")
      "Pylance executable.

    #!/bin/bash
    set -euo pipefail

    node $HOME/.vscode/extensions/ms-python.vscode-pylance-2020.7.1/server/server.bundle.js --stdio")

    (defvar lsp-pylance-type-checking "basic"
      "Used to specify the level of type checking analysis performed;

    * Default: off

    * Available values:
    - off: No type checking analysis is conducted; unresolved imports/variables diagnostics are produced
    - basic: Non-type checking-related rules (all rules in off) + basic type checking rules
    - strict: All type checking rules at the highest severity of error (includes all rules in off and basic categories")

    (lsp-register-custom-settings
     `(("python.analysis.typeCheckingMode"       lsp-pylance-type-checking
      "python.analysis.useLibraryCodeForTypes" nil)))

    (lsp-register-client
     (make-lsp-client
      :new-connection (lsp-stdio-connection (lambda () lsp-pylance-executable)
  					  (lambda () (f-exists? lsp-pylance-executable)))
      :major-modes '(python-mode)
      :server-id 'pylance
      :priority 3
      :initialized-fn (lambda (workspace)
  		      (with-lsp-workspace workspace
  			(lsp--set-configuration (lsp-configuration-section "python"))))
      :notification-handlers (lsp-ht ("pylance/beginProgress"  'ignore)
  				   ("pylance/reportProgress" 'ignore)
  				   ("pylance/endProgress"    'ignore))))

    (set-lookup-handlers! 'python-mode :async t
      :documentation #'lsp-describe-thing-at-point
      :definition #'lsp-find-definition
      :implementations #'lsp-find-implementation
      :type-definition #'lsp-find-type-definition
      :references #'lsp-find-references))

  (defun start-lsp-pylance ()
    "Start lsp-pylance."
    (nasy/lsp-pylance)
    (python-flycheck-setup)
    (gsetq elpy-modules (remove 'elpy-module-autodoc elpy-modules))
    (gsetq elpy-modules (remove 'elpy-module-eldoc   elpy-modules))
    (lsp-deferred))

  (add-hook #'python-mode-hook #'start-lsp-pylance))

(gsetq flycheck-python-mypy-ini "~/.config/mypy/config")

;; Now you can use it in lsp.
;; NOTICE you have to config black though pyproject.toml.
(when *pyblack*
  (use-package python-black
    :hook ((python-mode . python-black-on-save-mode))
    :init (gsetq python-black-extra-args
  	       '("--line-length" "79" "-t" "py38"))))

(use-package py-isort
  :hook ((before-save . py-isort-before-save)))

(use-package python-docstring
  :hook ((python-mode . python-docstring-mode)))

(use-package sphinx-doc
  :hook ((python-mode . sphinx-doc-mode)))

(use-package pyimport
  :bind (:map python-mode-map
  	    ("C-c C-i" . pyimport-insert-missing)))

(use-package restclient
  :defer t
  :init
  (nasy/add-company-backend
    'restclient-mode
    '(company-restclient company-files)))

(when *rust*
  (use-package rust-mode
    :defer t
    :hook ((rust-mode . (lambda () (setq-local tab-width 4)))
  	 (rust-mode . lsp-deferred))
    :config
    (when *rls*
      (add-hook #'rust-mode-hook #'(lambda () (add-to-list 'flycheck-disabled-checkers 'rust-cargo)))))

  (use-package cargo
    :after rust-mode
    :hook ((toml-mode . cargo-minor-mode)
  	 (rust-mode . cargo-minor-mode))))

(use-package lsp-yaml
  :defer t
  :hook ((yaml-mode . lsp-deferred)))

(straight-use-package 'org-plus-contrib)

(straight-use-package 'org-cliplink)
(straight-use-package 'org-pdfview)
(straight-use-package 'org-superstar)
(straight-use-package 'toc-org)
(straight-use-package 'org-wc)

;;

(use-package org
  :preface
  (advice-add 'org-refile :after (lambda (&rest _) (org-save-all-org-buffers)))

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

  (defun nasy/org-html-paragraph-advice (orig paragraph contents &rest args)
    "Join consecutive Chinese lines into a single long line without
unwanted space when exporting org-mode to html."
    (let* ((fix-regexp "[[:multibyte:]]")
  	 (fixed-contents
  	  (replace-regexp-in-string
  	   (concat
  	    "\\(" fix-regexp "\\) *\n *\\(" fix-regexp "\\)") "\\1\\2" contents)))
      (apply orig paragraph fixed-contents args)))
  (advice-add #'org-html-paragraph :around #'nasy/org-html-paragraph-advice)

  (defun nasy/org-fix-saveplace ()
    "Fix a problem with saveplace.el putting you back in a folded position"
    (when (outline-invisible-p)
      (save-excursion
      (outline-previous-visible-heading 1)
      (org-show-subtree))))

  (defvar-local nasy/org-at-src-begin -1
    "Variable that holds whether last position was a ")

  (defvar nasy/ob-header-symbol ?☰
    "Symbol used for babel headers")

  (defun nasy/org-prettify-src--update ()
    (let ((case-fold-search t)
  	(re "^[ \t]*#\\+begin_src[ \t]+[^ \f\t\n\r\v]+[ \t]*")
  	found)
      (save-excursion
      (goto-char (point-min))
      (while (re-search-forward re nil t)
  	(goto-char (match-end 0))
  	(let ((args (org-trim
  		     (buffer-substring-no-properties (point)
  						     (line-end-position)))))
  	  (when (org-string-nw-p args)
  	    (let ((new-cell (cons args nasy/ob-header-symbol)))
  	      (cl-pushnew new-cell prettify-symbols-alist :test #'equal)
  	      (cl-pushnew new-cell found :test #'equal)))))
      (setq prettify-symbols-alist
  	    (cl-set-difference prettify-symbols-alist
  			       (cl-set-difference
  				(cl-remove-if-not
  				 (lambda (elm)
  				   (eq (cdr elm) nasy/ob-header-symbol))
  				 prettify-symbols-alist)
  				found :test #'equal)))
      ;; Clean up old font-lock-keywords.
      (font-lock-remove-keywords nil prettify-symbols--keywords)
      (setq prettify-symbols--keywords (prettify-symbols--make-keywords))
      (font-lock-add-keywords nil prettify-symbols--keywords)
      (while (re-search-forward re nil t)
  	(font-lock-flush (line-beginning-position) (line-end-position))))))

  (defun nasy/org-prettify-src ()
    "Hide src options via `prettify-symbols-mode'.

  `prettify-symbols-mode' is used because it has uncollpasing. It's
  may not be efficient."
    (let* ((case-fold-search t)
  	 (at-src-block (save-excursion
  			 (beginning-of-line)
  			 (looking-at "^[ \t]*#\\+begin_src[ \t]+[^ \f\t\n\r\v]+[ \t]*"))))
      ;; Test if we moved out of a block.
      (when (or (and nasy/org-at-src-begin
  		   (not at-src-block))
  	      ;; File was just opened.
  	      (eq nasy/org-at-src-begin -1))
      (nasy/org-prettify-src--update))
      ;; Remove composition if at line; doesn't work properly.
      ;; (when at-src-block
      ;;   (with-silent-modifications
      ;;     (remove-text-properties (match-end 0)
      ;;                             (1+ (line-end-position))
      ;;                             '(composition))))
      (setq nasy/org-at-src-begin at-src-block)))

  (defun nasy/org-prettify-symbols ()
    (mapc (apply-partially 'add-to-list 'prettify-symbols-alist)
  	(cl-reduce 'append
  		   (mapcar (lambda (x) (list x (cons (upcase (car x)) (cdr x))))
  			   `(("#+begin_src" . ?λ)
  			     ("#+end_src"   . ?⌞)
  			     ("#+header:" . ,nasy/ob-header-symbol)
  			     ("#+begin_quote" . ?✎)
  			     ("#+end_quote" . ?⌞)))))
    (turn-on-prettify-symbols-mode)
    (add-hook 'post-command-hook 'nasy/org-prettify-src t t))

  :bind (:map org-src-mode-map
       ("C-c _"    . org-edit-src-exit))
  :hook ((org-mode . auto-fill-mode)
       (org-mode . nasy/org-fix-saveplace)
       (org-mode . nasy/org-prettify-symbols))
  :init
  (gsetq
   org-archive-mark-done nil
   org-archive-location  "%s_archive::* Archive"
   org-archive-mark-done nil

   org-catch-invisible-edits 'smart

   org-default-notes-file "~/notes/default.org"

   org-edit-timestamp-down-means-later t

   org-ellipsis " ﹅"

   org-emphasis-regexp-components ;; markup chinesee without space
      (list (concat " \t('\"{"            "[:nonascii:]")
  	  (concat "- \t.,:!?;'\")}\\["  "[:nonascii:]")
  	  " \t\r\n,\"'"
  	  "."
  	  1)

   org-export-backends                           '(ascii html latex md)
   org-export-coding-system                      'utf-8
   org-export-kill-product-buffer-when-displayed t
   org-export-with-broken-links                  'mark
   org-export-with-sub-superscripts              '{}
   org-use-sub-superscripts                      '{}

   org-fast-tag-selection-single-key 'expert

   org-highlight-latex-and-related: '(native latex script entities)

   org-hide-emphasis-markers t
   org-hide-leading-stars    nil

   org-html-checkbox-type       'uncode
   org-html-doctype             "html5"
   org-html-html5-fancy         t
   org-html-htmlize-output-type 'inline-css
   org-html-klipsify-src        t
   org-html-mathjax-options     '((path          "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.7/latest.js?config=TeX-AMS-MML_HTMLorMML")
  				(scale         "100")
  				(align         "center")
  				(font          "Neo-Euler")
  				(linebreaks    "false")
  				(autonumber    "AMS")
  				(indent        "0em")
  				(multlinewidth "85%")
  				(tagindent     ".8em")
  				(tagside       "right"))
   org-html-with-latex          'mathjax
   org-html-validation-link     nil

   org-indent-mode-turns-on-hiding-stars nil

   org-pretty-entities t

   ;; org time
   org-display-custom-times         t
   org-time-stamp-custom-formats    '("<%a, %b %d, %Y>" . "<%a, %b %d, %Y at %H:%M>")
   org-export-date-timestamp-format "%b %d, %Y"

   ;; org latex
   org-latex-compiler "lualatex"
   org-latex-default-packages-alist
   (quote
    (("AUTO" "inputenc"  t   ("pdflatex"))
     ("T1"   "fontenc"   t   ("pdflatex"))
     (""     "graphicx"  t   nil)
     (""     "grffile"   t   nil)
     (""     "longtable" t   nil)
     (""     "booktabs"  t   nil)
     (""     "wrapfig"   nil nil)
     (""     "rotating"  nil nil)
     ("normalem" "ulem"  t   nil)
     (""     "amsmath"   t   nil)
     (""     "textcomp"  t   nil)
     (""     "amssymb"   t   nil)
     (""     "capt-of"   nil nil)
     ("colorlinks,unicode,linkcolor=blue,anchorcolor=blue,citecolor=green,filecolor=black,urlcolor=blue"
      "hyperref" t nil)
     (""            "luatexja-fontspec" t nil)
     (""            "listings"          t nil)
     (""            "algorithm"         t nil)
     (""            "algpseudocode"     t nil)
     ("cache=false" "minted"            t nil)))
   org-latex-default-table-environment "longtable"
   org-latex-listings 'minted
   org-latex-listings-langs
   (quote
    ((emacs-lisp   "Lisp")
     (lisp         "Lisp")
     (clojure      "Lisp")
     (c            "C")
     (C            "C")
     (cc           "C++")
     (fortran      "fortran")
     (perl         "Perl")
     (cperl        "Perl")
     (Python       "Python")
     (python       "Python")
     (ruby         "Ruby")
     (html         "HTML")
     (xml          "XML")
     (tex          "TeX")
     (latex        "[LaTeX]TeX")
     (sh           "bash")
     (shell-script "bash")
     (gnuplot      "Gnuplot")
     (ocaml        "Caml")
     (caml         "Caml")
     (sql          "SQL")
     (sqlite       "sql")
     (makefile     "make")
     (make         "make")
     (R            "r")))
   org-latex-pdf-process
   (quote
    ("lualatex -shell-escape -interaction nonstopmode %f"
     "lualatex -shell-escape -interaction nonstopmode %f"))
   org-latex-tables-booktabs t

   org-level-color-stars-only nil
   org-list-indent-offset 2
   org-log-done t

   org-outline-path-complete-in-steps nil

   org-refile-allow-creating-parent-nodes 'confirm
   ;; org-refile-targets                     '((nil :maxlevel . 5) (org-agenda-files :maxlevel . 5))
   org-refile-use-cache                   nil
   org-refile-use-outline-path            t

   org-startup-indented  t
   org-startup-folded    'content
   org-startup-truncated nil

   org-src-lang-modes '(("C"         . c)
  		      ("C++"       . c++)
  		      ("asymptote" . asy)
  		      ("bash"      . sh)
  		      ("beamer"    . latex)
  		      ("calc"      . fundamental)
  		      ("makefile"  . fundamental)
  		      ("make"      . fundamental)
  		      ("cpp"       . c++)
  		      ("ditaa"     . artist)
  		      ("dot"       . fundamental)
  		      ("elisp"     . emacs-lisp)
  		      ("ocaml"     . tuareg)
  		      ("screen"    . shell-script)
  		      ("shell"     . sh)
  		      ("sqlite"    . sql))

   org-support-shift-select t

   org-tags-column 80

   ;; to-do settings
   org-todo-keywords        (quote ((sequence "TODO(t)" "WIP(w/!)" "WAIT(W@/!)" "HOLD(h)" "|" "CANCELLED(c@/!)" "DONE(d!/!)")))
   org-todo-repeat-to-state "NEXT"
   org-todo-keyword-faces   (quote (("NEXT" :inherit warning)
  				  ("WAIT" :inherit font-lock-string-face))))
  (nasy/add-company-backend 'org-mode 'company-tabnine)
  :config
  ;; --------
  (org-babel-do-load-languages
   'org-babel-load-languages
   `((ditaa      . t)
     (dot        . t)
     (elvish     . t)
     (emacs-lisp . t)
     (gnuplot    . t)
     (haskell    . nil)
     (latex      . t)
     (ledger     . t)
     (ocaml      . nil)
     (octave     . t)
     (plantuml   . t)
     (python     . t)
     (R          . t)
     (restclient . t)
     (ruby       . t)
     (screen     . nil)
     (,(if (locate-library "ob-sh") 'sh 'shell) . t)
     (sql        . nil)
     (sqlite     . t)))

  (gsetq org-babel-python-command "python")

  ;; --------
  (gsetq luamagick
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

  (gsetq luasvg
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
  (gsetq org-preview-latex-default-process 'luamagick)

  (require 'org-tempo nil t)
  (after! ox
    (let ((oxs '(ox-rst
  	       ox-pandoc)))
      (dolist (language oxs)
      (straight-use-package language)
      (require language nil t)))))

(use-package org-agenda
  :defer t
  :preface
  (defun org-agenda-log-mode-colorize-block ()
    "Set different line spacing based on clock time duration."
    (save-excursion
      (let* ((colors (cl-case (alist-get 'background-mode (frame-parameters))
  		     ('light
  		      (list "#a7e9af" "#75b79e" "#6a8caf" "#eef9bf"))
  		     ('dark
  		      (list "#a7e9af" "#75b79e" "#6a8caf" "#eef9bf"))))
  	   pos
  	   duration)
      (nconc colors colors)
      (goto-char (point-min))
      (while (setq pos (next-single-property-change (point) 'duration))
  	(goto-char pos)
  	(when (and (not (equal pos (point-at-eol)))
  		  (setq duration (org-get-at-bol 'duration)))
  	  ;; larger duration bar height
  	  (let ((line-height (if (< duration 15) 1.0 (+ 0.5 (/ duration 30))))
  		(ov (make-overlay (point-at-bol) (1+ (point-at-eol)))))
  	    (overlay-put ov 'face `(:background ,(car colors) :foreground "black"))
  	    (setq colors (cdr colors))
  	    (overlay-put ov 'line-height line-height)
  	    (overlay-put ov 'line-spacing (1- line-height))))))))
  :hook ((org-agenda-finalize . org-agenda-log-mode-colorize-block))
  :config
  (gsetq-default org-agenda-clockreport-parameter-plist '(:link t :maxlevel 3))
  (gsetq
   org-agenda-compact-blocks   t
   org-agenda-include-diary    nil
   org-agenda-span             'week
   org-agenda-start-on-weekday nil
   org-agenda-start-day       "-1d"
   org-agenda-sticky           nil
   org-agenda-window-setup     'current-window)

  (gsetq
   org-agenda-sorting-strategy
   '((agenda habit-down time-up user-defined-up effort-up category-keep)
     (todo category-up effort-up)
     (tags category-up effort-up)
     (search category-up)))

  (gsetq
   org-agenda-time-grid
   '((daily today weekly require-timed remove-match)
     (0 600 900 1200 1300 1600 1800 2000 2200 2400 2600)
     "......"
     "-----------------------------------------------------")
   org-agenda-prefix-format
   '((agenda . " %i %+15c\t%?-15t% s")
     (todo   . " %i %+15c\t")
     (tags   . " %i %+15c\t")
     (search . " %i %+15c\t")))

  (after-x 'all-the-icons
    (gsetq
     org-agenda-category-icon-alist
     `(("Tasks"        ,(list (all-the-icons-faicon  "tasks"            :height 0.8 :v-adjust 0)) nil nil :ascent center)
       ("Calendar"     ,(list (all-the-icons-octicon "calendar"         :height 0.8 :v-adjust 0)) nil nil :ascent center)
       ("Appointments" ,(list (all-the-icons-faicon  "calendar-check-o" :height 0.8 :v-adjust 0)) nil nil :ascent center)))))

(use-package org-capture
  :defer t
  :init
  (unless (boundp 'org-capture-templates)
    (defvar org-capture-templates nil))

  (add-to-list 'org-capture-templates '("t" "Tasks"))

  (add-to-list 'org-capture-templates
  	     '("tr" "Book Reading Task" entry
  	       (file+olp "~/notes/task.org" "Reading" "Book")
  	       "* TODO %^{book name}\n%u\n%a\n" :clock-in t :clock-resume t))

  (add-to-list 'org-capture-templates
  	     '("tw" "Work Task" entry
  	       (file+headline "~/notes/task.org" "Work")
  	       "* TODO %^{task name}\n%u\n%a\n" :clock-in t :clock-resume t))

  (add-to-list 'org-capture-templates
  	     '("T" "Thoughts" entry
  	       (file "~/notes/thoughts.org")
  	       "* %t - %^{heading}\n\n%?"))

  (add-to-list 'org-capture-templates
  	     '("j" "Journal" entry
  	       (file "~/notes/journal.org")
  	       "* %U - %^{heading}\n  %?"))

  (add-to-list 'org-capture-templates
  	     '("i" "Inbox" entry
  	       (file "~/notes/inbox.org")
  	       "* %U - %^{heading} %^g\n %?\n"))

  (add-to-list 'org-capture-templates
  	     '("n" "Notes" entry
  	       (file "~/notes/notes.org")
  	       "* %^{heading} %t %^g\n  %?\n")))

(use-package org-clock
  :preface
  (defun show-org-clock-in-header-line ()
    "Show the clocked-in task in header line"
    (setq-default header-line-format '((" " org-mode-line-string ""))))

  (defun hide-org-clock-from-header-line ()
    "Hide the clocked-in task from header line"
    (setq-default header-line-format nil))
  :init
  (gsetq org-clock-persist t
       org-clock-in-resume t
       ;; Save clock data and notes in the LOGBOOK drawer
       org-clock-into-drawer t
       ;; Save state changes in the LOGBOOK drawer
       org-log-into-drawer t
       ;; Removes clocked tasks with 0:00 duration
       org-clock-out-remove-zero-time-clocks t
       ;; Show clock sums as hours and minutes, not "n days" etc.
       org-time-clocksum-format
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

(use-package org
  :defer t
  :preface
  (defun grab-ditaa (url jar-name)
    "Download URL and extract JAR-NAME as `org-ditaa-jar-path'."
    (message "Grabbing " jar-name " for org.")
    (let ((zip-temp (make-temp-name (no-littering-expand-var-file-name "emacs-ditaa"))))
      (unwind-protect
  	(progn
  	  (when (executable-find "unzip")
  	    (url-copy-file url zip-temp)
  	    (shell-command (concat "unzip -p " (shell-quote-argument zip-temp)
  				   " " (shell-quote-argument jar-name) " > "
  				   (shell-quote-argument org-ditaa-jar-path)))))
      (when (file-exists-p zip-temp)
  	(delete-file zip-temp)))))
  :config
  (unless (and (boundp 'org-ditaa-jar-path)
  	     (file-exists-p org-ditaa-jar-path))
    (let ((jar-name "ditaa0_9.jar")
  	(url "http://jaist.dl.sourceforge.net/project/ditaa/ditaa/0.9/ditaa0_9.zip"))
      (setq org-ditaa-jar-path (no-littering-expand-var-file-name jar-name))
      (unless (file-exists-p org-ditaa-jar-path)
      (grab-ditaa url jar-name))))

  (let ((jar-name "plantuml.jar")
      (url "http://jaist.dl.sourceforge.net/project/plantuml/plantuml.jar"))
    (setq org-plantuml-jar-path (no-littering-expand-var-file-name jar-name))
    (unless (file-exists-p org-plantuml-jar-path)
      (url-copy-file url org-plantuml-jar-path))))

(use-package org-pomodoro
  :defer t
  :init (gsetq org-pomodoro-keep-killed-pomodoro-time t)
  :bind (:map org-agenda-mode-map
  	    ("P" . org-pomodoro)))

(use-package org-superstar
  :defer t
  :ghook 'org-mode-hook
  :init
  (gsetq
   org-superstar-special-todo-items t
   org-superstar-headline-bullets-list
   '("♥"
     "✿"
     "❀"
     "☢"
     "✸"
     "◉")
   org-superstar-item-bullet-alist
   '((?* . ?☯)
     (?+ . ?✚)
     (?- . ?▶))))

(straight-use-package 'dashboard)
(use-package dashboard
  :bind
  ;; https://github.com/rakanalh/emacs-dashboard/issues/45
  :diminish (dashboard-mode page-break-lines-mode)
  :hook ((dashboard-mode . (lambda () (gsetq-local tab-width 1))))
  :init
  (general-define-key
   "<f5>" 'nasy/dashboard-refresh)
  (general-define-key
   :keymaps 'dashboard-mode-map
   "<down-mouse-1>" nil
   "<mouse-1>"      'widget-button-click
   "<mouse-2>"      'widget-button-click
   "<up>"           'widget-backward
   "<down>"         'widget-forward)
  (gsetq dashboard-startup-banner    (concat user-emacs-directory "ue.png")
       dashboard-center-content    t
       dashboard-show-shortcuts    t
       dashboard-set-heading-icons t
       dashboard-set-file-icons    t
       dashboard-set-init-info     t
       show-week-agenda-p          t
       dashboard-set-navigator     t
       dashboard-org-agenda-categories '("Calendar" "Tasks" "Appointments"))
  (setq dashboard-navigator-buttons
      `(;; line1
  	((,(all-the-icons-octicon "mark-github" :height 1.1 :v-adjust 0.0)
  	  "Source"
  	  "Source Page"
  	  (lambda (&rest _) (browse-url "https://github.com/nasyxx/emacs.d/")))
  	 (,(all-the-icons-octicon "gear" :height 1.1 :v-adjust 0.0)
  	  "Config"
  	  "Config File"
  	  (lambda (&rest _) (let ((upath (expand-file-name "custom/user-config.el" user-emacs-directory))
  			     (epath (expand-file-name "custom/user-config-example.el" user-emacs-directory)))
  			 (when (and (file-exists-p epath)
  				   (not (file-exists-p upath)))
  			   (copy-file epath upath))
  			 (find-file upath))))
  	 (,(all-the-icons-octicon "book" :height 1.1 :v-adjust 0.0)
  	  "Document"
  	  "Document Page"
  	  (lambda (&rest _) (browse-url "https://emacs.nasy.moe/"))))))
  (defun nasy/dashboard-refresh ()
    "Refresh dashboard buffer."
    (interactive)
    (unless (get-buffer dashboard-buffer-name)
      (generate-new-buffer "*dashboard*"))
    (dashboard-refresh-buffer))
  :config
  (dashboard-setup-startup-hook)
  (gsetq dashboard-items '((recents   . 10)
  			 (bookmarks . 5)
  			 ;; (registers . 5 )
  			 ;; (agenda    . 5)
  			 (projects  . 10)))
  (advice-add 'dashboard-next-line :after #'(lambda (&rest r) (forward-char 2)))
  (advice-add 'widget-forward :after #'(lambda (&rest r) (forward-char 2))))

;; (use-package cnfonts
;;   :disabled t
;;   :straight t
;;   :init
;;   (gsetq cnfonts-directory (no-littering-expand-etc-file-name "cnfonts"))
;;   :hook ((after-init . cnfonts-enable))
;;   :config
;;   (defun nasy/set-symbol-fonts (fontsize-list)
;;     "Set symbol fonts with FONTSIZE-LIST."
;;     (let* ((fontname "Fira Code Symbol")
;;            (fontsize (nth 0 fontsize-list))
;;            (fontspec (font-spec :name fontname
;;                                 :size fontsize
;;                                 :weight 'normal
;;                                 :slant 'normal)))
;;       (if (cnfonts--fontspec-valid-p fontspec)
;;           (set-fontset-font t '(#Xe100 . #Xe16f) fontspec)
;;         (message "Font %S not exists！" fontname))))
;;   (defun nasy/set-symbol-extra-fonts (fontsize-list)
;;     "Set extra symbol fonts with FONTSIZE-LIST."
;;     (let* ((fontname "Arial")
;;            (fontsize (nth 0 fontsize-list))
;;            (fontspec (font-spec :name fontname
;;                                 :size fontsize
;;                                 :weight 'normal
;;                                 :slant 'normal)))
;;       (if (cnfonts--fontspec-valid-p fontspec)
;;           (set-fontset-font t '(#X1d400 . #X1d744) fontspec)
;;         (message "Font %S not exists！" fontname))))
;;   (add-hook #'cnfonts-set-font-finish-hook #'nasy/set-symbol-fonts)
;;   (add-hook #'cnfonts-set-font-finish-hook #'nasy/set-symbol-extra-fonts))

(defun nasy/set--font (frame)
  "Nasy set font for `FRAME'."
  (when (display-graphic-p)
    (set-face-attribute
     'default nil
     :font (font-spec :name   *font*
  		    :weight *font-weight*
  		    :size   *font-size*))

    (dolist (charset '(kana han cjk-misc bopomofo))
      (set-fontset-font (frame-parameter nil 'font)
  		      charset
  		      (font-spec :name   *font-cjk*
  				 :weight *font-weight-cjk*
  				 :size   *font-size-cjk*)
  		      frame
  		      'prepend))

    (if *is-a-mac*
       ;; For NS/Cocoa
      (set-fontset-font t
  			 'symbol
  			 (font-spec :family "Apple Color Emoji")
  			 frame
  			 'prepend)
       ;; For Linux
      (set-fontset-font t
  		      'symbol
  		      (font-spec :family "Symbola")
  		      frame
  		      'prepend))

    (set-face-attribute 'mode-line nil
  		      :font (font-spec :name   "spot mono"
  				       :weight 'normal
  				       :size   15)
  		      :background "#2d334a")

    (set-face-attribute 'mode-line-inactive nil
  		      :font (font-spec :name   "spot mono"
  				       :weight 'normal
  				       :size   15))
    (set-face-attribute 'tab-line nil
  		      :font (font-spec :name   "spot mono"
  				       :weight 'normal
  				       :size   12))))

(defun nasy/set-font (&rest _)
  "Nasy set font."
  (interactive)
  (nasy/set--font nil))


(add-hook #'after-init-hook #'nasy/set-font)
(add-hook #'after-make-frame-functions   #'nasy/set-font)
(add-hook #'server-after-make-frame-hook #'nasy/set-font)

(straight-use-package 'doom-themes)
(use-package doom-themes
  :init (gsetq doom-dracula-brighter-comments t
  	     doom-dracula-colorful-headers  t
  	     doom-dracula-comment-bg        t)
  :config
  (after-x 'treemacs
    (doom-themes-treemacs-config)
    (gsetq doom-themes-treemacs-theme "doom-colors"))
  (doom-themes-visual-bell-config)
  (after-x 'org-mode
    (doom-themes-org-config)))

(when (eq *theme* 'darktooth-theme)
  (straight-use-package 'darktooth-theme)
  (use-package darktooth-theme
    :config
    (darktooth-modeline)))

(when (eq *theme* 'soothe-theme)
  (straight-use-package 'soothe-theme))

(defun nasy/load-theme ()
  "Nasy load theme function"
  (load-theme *theme* t))

(add-hook #'after-init-hook #'nasy/load-theme)

(straight-use-package 'nyan-mode)
(use-package nyan-mode
  :init (gsetq nyan-animate-nyancat t
  	     nyan-bar-length 16
  	     nyan-wavy-trail t)
  :hook ((after-init . nyan-mode)))

(straight-use-package 'minions)
(use-package minions
  :hook ((after-init . minions-mode))
  :init (gsetq minions-mode-line-lighter "✬"))

(straight-use-package 'doom-modeline)
(use-package doom-modeline
  :hook ((after-init . doom-modeline-mode))
  :init (gsetq
       doom-modeline-height                      25
       doom-modeline-bar-width                   3
       doom-modeline-window-width-limit          fill-column
       doom-modeline-project-detection           'project  ;; changed
       doom-modeline-buffer-file-name-style      'relative-to-project  ;; changed
       doom-modeline-icon                        t  ;; changed
       doom-modeline-major-mode-icon             t
       doom-modeline-major-mode-color-icon       t
       doom-modeline-buffer-state-icon           t
       doom-modeline-buffer-modification-icon    t
       doom-modeline-unicode-fallback            t  ;; changed
       doom-modeline-minor-modes                 t
       doom-modeline-enable-word-count           t
       doom-modeline-continuous-word-count-modes '(markdown-mode gfm-mode org-mode text-mode)
       doom-modeline-buffer-encoding             nil
       doom-modeline-indent-info                 nil
       doom-modeline-checker-simple-format       nil
       doom-modeline-number-limit                99
       doom-modeline-vcs-max-length              12
       doom-modeline-persp-name                  t
       doom-modeline-display-default-persp-name  nil
       doom-modeline-lsp                         t
       doom-modeline-github                      t
       doom-modeline-github-interval             (* 30 60)
       doom-modeline-modal-icon                  nil

       doom-modeline-env-version       t
       doom-modeline-env-enable-python t
       doom-modeline-env-enable-ruby   t
       doom-modeline-env-enable-perl   t
       doom-modeline-env-enable-go     t
       doom-modeline-env-enable-elixir t
       doom-modeline-env-enable-rust   t

       doom-modeline-env-python-executable "python"
       doom-modeline-env-ruby-executable   "ruby"
       doom-modeline-env-perl-executable   "perl"
       doom-modeline-env-go-executable     "go"
       doom-modeline-env-elixir-executable "iex"
       doom-modeline-env-rust-executable   "rustc"

       doom-modeline-env-load-string "..."

       doom-modeline-mu4e        t
       doom-modeline-irc         t
       doom-modeline-irc-stylize 'identity)
  :config
  (doom-modeline-def-segment nasy/time
    "Time"
    (when (doom-modeline--active)
      (propertize
       (format-time-string " %b %d, %Y - %H:%M ")
       'face (when (doom-modeline--active) `(:foreground "#1b335f" :background "#c0ffc2")))))

  ;; Remove
  ;; modals (evil, god, ryo and xah-fly-keys, etc.), parrot
  ;; buffer-encoding
  ;; Add
  ;; nasy/time
  (doom-modeline-def-modeline 'main
    '(bar workspace-name matches buffer-info buffer-position word-count parrot " " selection-info " " misc-info process)
    '(objed-state grip github debug lsp minor-modes major-mode vcs checker nasy/time))

  (doom-modeline-def-modeline 'minimal
    '(bar matches buffer-info-simple)
    '(media-info major-mode "  " nasy/time))

  (doom-modeline-def-modeline 'special
    '(bar modals matches buffer-info buffer-position word-count parrot selection-info)
    '(misc-info battery irc-buffers debug minor-modes input-method indent-info buffer-encoding major-mode process nasy/time))

  (doom-modeline-def-modeline 'media
    '(bar buffer-size buffer-info)
    '(misc-info media-info major-mode process vcs nasy/time))

  (doom-modeline-def-modeline 'pdf
    '(bar buffer-size buffer-info pdf-pages)
    '(misc-info major-mode process vcs nasy/time))

  (doom-modeline-def-modeline 'project
    '(bar buffer-default-directory)
    '(misc-info major-mode nasy/time))

  ;; Change behaviors
  (defun nasy/doom-modeline-update-buffer-file-name (&rest _)
    "Update buffer file name in mode-line."
    (setq doom-modeline--buffer-file-name
  	(if buffer-file-name
  	    (doom-modeline-buffer-file-name)
  	  (if (string-prefix-p "*Org Src" (format-mode-line "%b"))
  	      ""
  	    (propertize "%b"
  			'face (if (doom-modeline--active)
  				  'doom-modeline-buffer-file
  				'mode-line-inactive)
  			'help-echo "Buffer name
    mouse-1: Previous buffer\nmouse-3: Next buffer"
  			'local-map mode-line-buffer-identification-keymap)))))
  (advice-add #'doom-modeline-update-buffer-file-name :override #'nasy/doom-modeline-update-buffer-file-name))

(add-hook #'after-init-hook #'global-tab-line-mode)
(gsetq tab-line-close-tab-function #'kill-buffer)

(run-hooks 'nasy/config-before-hook)

(setq custom-file (no-littering-expand-etc-file-name "custom.el"))

(add-hook 'after-init-hook #'(lambda () (run-hooks 'nasy/config-after-hook)))

(when (file-exists-p custom-file)
  (load custom-file))

(when *server*
  (server-start))
;;; init.el ends here
