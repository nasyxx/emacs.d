(leaf custom-settings
  :custom
  ;; (calendar-latitude         . 24.8801)
  ;; (calendar-longitude        . 102.8329)
  ;; (user-mail-address         . "nasyxx@gmail.com")
  ;; (initial-buffer-choice     . #'(lambda () (get-buffer "*dashboard*")))
  ;; (diary-file                . ~/dairy/emacs-dairy)
  (*debug*                   . nil)
  (*highlight-indent-guides* . nil)
  (*ivy-posframe*            . t)
  (*ivy-prescient*           . t)
  (*c-box*                   . nil)
  (*flycheck-inline*         . t)
  (*rust*                    . nil)
  (*theme*                   . 'nasy))

(leaf disabled-packages
  :custom
  ((*no-eldoc-overlay*
    *no-highlight-indent-guides*
    *no-indent-tools*
    *no-point-history*
    *no-tree-sitter-indent*)
   . t))

(provide '芄蘭之例)
