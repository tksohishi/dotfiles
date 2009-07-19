;; key-bind
(global-set-key "\C-h" 'delete-backward-char)
(define-key global-map "\C-z" 'undo)
(define-key global-map "\C-c;" 'comment-region)
(define-key global-map "\C-c:" 'uncomment-region)
(global-font-lock-mode t)
(show-paren-mode 1)

;; not saving file
(setq backup-inhibited t)
(setq delete-auto-save-files t)

;; for perl
(setenv "PERL5LIB" "S:\pm")
(defalias 'perl-mode 'cperl-mode)

;; for python
(setq auto-mode-alist
(cons '("\\.py$" . python-mode) auto-mode-alist))
(autoload 'python-mode "python-mode" "Python editing mode." t)

;; flymake
(require 'flymake)

;; flymake for perl
(defvar flymake-perl-err-line-patterns '(("\\(.*\\) at \\([^ \n]+\\) line \\([0-9]+\\)[,.\n]" 2 3 nil 1)))
(defconst flymake-allowed-perl-file-name-masks '(("\\.pl$" flymake-perl-init)
("\\.pm$" flymake-perl-init)
("\\.t$" flymake-perl-init)))
(defun flymake-perl-init ()
(let* ((temp-file (flymake-init-create-temp-buffer-copy
'flymake-create-temp-inplace))
(local-file (file-relative-name
temp-file
(file-name-directory buffer-file-name))))
(list "perl" (list "-wc" local-file))))
(defun flymake-perl-load ()
(interactive)
(defadvice flymake-post-syntax-check (before flymake-force-check-was-interrupted)
(setq flymake-check-was-interrupted t))
(ad-activate 'flymake-post-syntax-check)
(setq flymake-allowed-file-name-masks (append flymake-allowed-file-name-masks flymake-allowed-perl-file-name-masks))
(setq flymake-err-line-patterns flymake-perl-err-line-patterns)
(flymake-mode t))
(add-hook 'cperl-mode-hook '(lambda () (flymake-perl-load)))
(cd "")

;; howm
;; (add-to-list 'load-path "/usr/share/emacs/site-lisp/howm/")
;; (setq howm-menu-lang 'ja)
;; (require 'howm-mode)
(custom-set-variables
  ;; custom-set-variables was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 '(gud-gdb-command-name "gdb --annotate=1")
 '(large-file-warning-threshold nil)
 '(safe-local-variable-values (quote ((encoding . utf-8)))))
(custom-set-faces
  ;; custom-set-faces was added by Custom.
  ;; If you edit it by hand, you could mess it up, so be careful.
  ;; Your init file should contain only one such instance.
  ;; If there is more than one, they won't work right.
 )
