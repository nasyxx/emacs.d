(leaf company-box
  :disabled t
  :when *c-box*
  :hook company-mode-hook
  :custom
  (company-box-show-single-candidate . t)
  (company-box-max-candidates        . 25)
  (company-box-icons-alist           . 'company-box-icons-all-the-icons)
  :config
  (gsetq
   company-box-icons-functions
   (cons #'nasy/company-box-icons--elisp-fn
         (delq 'company-box-icons--elisp
               company-box-icons-functions)))

  (defun nasy/company-box-icons--elisp-fn (candidate)
    (when (derived-mode-p 'emacs-lisp-mode)
      (let ((sym (intern candidate)))
        (cond ((fboundp  sym) 'ElispFunction)
              ((boundp   sym) 'ElispVariable)
              ((featurep sym) 'ElispFeature)
              ((facep    sym) 'ElispFace)))))

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

  (defun nasy/company-remove-scrollbar-a (orig-fn &rest args)
   "This disables the company-box scrollbar, because:
  https://github.com/sebastiencs/company-box/issues/44"
   (cl-letf (((symbol-function #'display-buffer-in-side-window)
              (symbol-function #'ignore)))
     (apply orig-fn args)))

  :advice (:around
           company-box--update-scrollbar
           nasy/company-remove-scrollbar-a))
