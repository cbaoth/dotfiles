;;; init.el --- Emacs configuration -*- lexical-binding: t -*-

;;; Commentary:
;; Fresh start, 2026-10, written for Emacs 30. Deployed by dotfiles-link:
;; dotfiles/.config/emacs/init.el -> ~/.config/emacs/init.el
;;
;; - Terminal first (`emacs -nw', ssh, TTY). GUI frames share this file;
;;   the few GUI-only settings apply to graphical frames only.
;; - Built-in features first: starts offline and behaves the same on every
;;   host. Third-party packages only where a gap hurts, and only where they
;;   are needed (see "Packages").
;; - Stock key bindings, so the tutorial (C-h t), C-h help and which-key all
;;   match what the keys do. The old personal remaps are kept, commented out,
;;   under "Legacy preferences".
;;
;; Background, decisions, open items: docs/setup/emacs.md (dotfiles repo).
;; Key cheatsheet: docs/reference/emacs.md.
;;
;; ~/.emacs and ~/.emacs.d take precedence over ~/.config/emacs: if either
;; exists, this file is silently ignored.

;;; Code:

;;; Files Emacs writes

;; Customize (M-x customize) writes here, not into this repo-managed file.
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;; Backups (file~) and auto-saves (#file#) go to ~/.config/emacs/ instead of
;; next to the edited file. No lock files (.#file): they litter directories.
(let ((auto-save-dir (locate-user-emacs-file "auto-saves/")))
  (make-directory auto-save-dir t)
  (setq backup-directory-alist `(("." . ,(locate-user-emacs-file "backups/")))
        auto-save-file-name-transforms `((".*" ,auto-save-dir t))))
(setq backup-by-copying t  ; never replace the original file (symlinks, owner)
      create-lockfiles nil)

;;; General behavior

(setq inhibit-startup-screen t
      use-short-answers t        ; y/n instead of yes/no
      ring-bell-function #'ignore
      vc-follow-symlinks t       ; dotfiles are symlinks into git: don't ask
      require-final-newline t
      kill-whole-line t          ; C-k at line start also takes the newline
      scroll-conservatively 101  ; scroll line by line instead of recentering
      scroll-margin 2
      scroll-error-top-bottom t  ; PgUp/PgDn move to the buffer edge at the ends
      sentence-end-double-space nil
      save-interprogram-paste-before-kill t  ; don't lose the clipboard on C-k
      help-window-select t)      ; focus help windows, so `q' closes them
(setq-default indent-tabs-mode nil  ; spaces, not tabs
              tab-width 4
              fill-column 80)

(delete-selection-mode 1)    ; typing replaces the selection
(global-auto-revert-mode 1)  ; reload files changed on disk (e.g. by git)
(savehist-mode 1)            ; keep minibuffer history across sessions
(save-place-mode 1)          ; reopen files at the last cursor position
(recentf-mode 1)             ; C-c r: recently opened files
(column-number-mode 1)
(editorconfig-mode 1)        ; honor .editorconfig, as VS Code and nvim do

;;; Discoverability (relearning aids)

(which-key-mode 1)  ; after a prefix (C-x, C-c, ...) list what can follow

;; Live, fuzzy-filtered candidates for M-x, C-x C-f, C-x b.
;; Gotcha: RET takes the highlighted candidate. To create a new file whose
;; name is a prefix of an existing one, type the name and press M-j instead.
(fido-vertical-mode 1)

;;; Programming and text

(defun cb/prog-mode-setup ()
  "Settings for all programming modes."
  (display-line-numbers-mode 1)
  (setq show-trailing-whitespace t)
  (hs-minor-mode 1))  ; code folding, C-c h toggles a block

(add-hook 'prog-mode-hook #'cb/prog-mode-setup)
(add-hook 'text-mode-hook (lambda () (setq show-trailing-whitespace t)))

;;; Keys (C-c <letter> is reserved for the user, nothing built-in uses it)

(keymap-global-set "C-c d" #'duplicate-dwim)  ; duplicate line, or region
(keymap-global-set "C-c ;" #'comment-line)    ; stock C-x C-; can't be typed
                                              ; in most terminals
(keymap-global-set "C-c r" #'recentf-open)
(keymap-global-set "C-c s" #'cb/save-as-script)

(defun cb/save-as-script (file)
  "Write the buffer to FILE as an executable script, keep editing this buffer.
Meant for zsh's edit-command-line (C-x C-e at the prompt): this buffer stays
the temp file that zsh reads back on exit, FILE gets a copy, with a zsh
shebang added if there is none."
  (interactive "FSave as script: ")
  (setq file (expand-file-name file))
  (when (and (file-exists-p file)
             (not (y-or-n-p (format "%s exists; overwrite? " file))))
    (user-error "Not saved"))
  (let ((content (buffer-string)))
    (with-temp-file file
      (unless (string-prefix-p "#!" content)
        (insert "#!/usr/bin/env zsh\n"))
      (insert content)))
  (set-file-modes file #o755)
  (message "Saved script: %s" file))
(with-eval-after-load 'hideshow
  (keymap-set hs-minor-mode-map "C-c h" #'hs-toggle-hiding))

;;; Look

;; Built-in dark theme (Modus Vivendi), readable in a 256-color terminal too,
;; recolored to GitHub Dark Default, the theme in VS Code and foot. Built in,
;; so it starts offline on every host.
;; - Tweak: change a color below, C-M-x (eval) the setq, then M-x load-theme
;;   RET modus-vivendi. Overridable names (left column), with a preview:
;;   M-x modus-themes-list-colors-current.
;; - Stock Modus Vivendi: comment out the setq.
;; - Try other themes live: M-x modus-themes-select (Modus family, swaps
;;   cleanly) or M-x load-theme (all themes; TAB lists them). load-theme
;;   stacks themes, so M-x disable-theme the current one first.
;; - Make one permanent: change the load-theme line.
(setq modus-vivendi-palette-overrides
      '(;; Base: GitHub Dark Default (Primer) canvas, text, borders
        (bg-main "#0d1117") (bg-dim "#161b22") (fg-main "#e6edf3")
        (fg-dim "#8b949e") (bg-active "#30363d") (bg-inactive "#161b22")
        (border "#30363d") (cursor "#2f81f7")
        (bg-hl-line "#161b22") (bg-region "#264f78") (fg-region unspecified)
        (bg-paren-match "#1b4721")
        (bg-mode-line-active "#161b22") (fg-mode-line-active "#e6edf3")
        (border-mode-line-active "#30363d")
        (bg-mode-line-inactive "#0d1117") (fg-mode-line-inactive "#8b949e")
        (bg-line-number-active "#0d1117") (bg-line-number-inactive "#0d1117")
        (fg-line-number-active "#e6edf3") (fg-line-number-inactive "#6e7681")
        (fg-link "#58a6ff")
        ;; Syntax: GitHub "prettylights" colors
        (keyword "#ff7b72") (preprocessor "#ff7b72") (string "#a5d6ff")
        (docstring "#a5d6ff") (comment "#8b949e") (fnname "#d2a8ff")
        (constant "#79c0ff") (builtin "#79c0ff") (type "#ffa657")
        (variable "#ffa657")))
(load-theme 'modus-vivendi t)

;; GUI font: the first installed one wins (setup/modules/40-fonts.sh installs
;; the Nerd Fonts). Hooked to frame creation because an `emacs --daemon' has
;; no graphical frame at startup; `emacsclient -c' creates one later.
(defun cb/set-gui-font (&optional frame)
  "Use the first installed preferred font on graphical FRAME."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (when-let* ((family (seq-find (lambda (f) (find-font (font-spec :family f)))
                                    '("FiraMono Nerd Font" "FiraCode Nerd Font"
                                      "Fira Code" "DejaVu Sans Mono"))))
        (set-face-attribute 'default nil :family family :height 100)))))

(add-hook 'after-make-frame-functions #'cb/set-gui-font)  ; emacsclient -c
(add-hook 'window-setup-hook #'cb/set-gui-font)           ; plain `emacs'

;;; Terminal (emacs -nw, ssh, TTY)

;; Mouse clicks, wheel and drag-selection in terminal frames. Hold Shift
;; while dragging to use the terminal's own selection instead.
(xterm-mouse-mode 1)

;; Copy (M-w, C-w) also lands in the clipboard of the machine the terminal
;; runs on, via the OSC 52 escape sequence, so it works over ssh. Needs
;; terminal support: tmux with `set-clipboard on' (set in .tmux.conf);
;; foot and the VS Code terminal untested. Paste from that clipboard with the
;; terminal's own paste key.
(setq xterm-extra-capabilities '(setSelection))

;;; Packages

;; package.el + use-package, both built in; no straight.el. GNU ELPA and
;; NonGNU ELPA are the default archives, MELPA is added for the rest.
;; Packages from a git repo use use-package's `:vc' (package-vc, Emacs 30).
(defvar package-archives)  ; defined by package.el, which loads later
(with-eval-after-load 'package
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))

;; Edit browser text fields in Emacs: the chrome-emacs extension connects to
;; a WebSocket server in this Emacs (port 64292). MELPA builds the unmaintained
;; original, so install the maintained fork from git. Daemon only: one process
;; can hold the port, a second `emacs' would fail to start it (start it there
;; by hand with M-x atomic-chrome-start-server when no daemon runs). pgtk is
;; the desktop build, so servers never download it. The daemon is started by
;; sway: dotfiles/.config/sway/config.d/90-launch-apps.conf.
(use-package atomic-chrome
  :if (and (daemonp) (featurep 'pgtk))
  :vc (:url "https://github.com/KarimAziev/atomic-chrome" :rev :newest)
  :config (atomic-chrome-start-server))

;;; Legacy preferences (2005-2011 config), all off for now

;; Each one overrides a stock binding that tutorials and C-h help assume.
;; Revisit once the defaults are familiar again. Source:
;; emacs.d-old-working.tar.gz (2011), see docs/setup/emacs.md.
;;
;; C-o: open an indented line below, from anywhere in the line
;; (stock C-o splits the line at point).
;; (defun cb/open-line-below ()
;;   "Insert an indented line below the current one and move there."
;;   (interactive)
;;   (end-of-line)
;;   (newline-and-indent))
;; (keymap-global-set "C-o" #'cb/open-line-below)
;;
;; C-k: always kill the whole line (stock: kill to end of line, same as C-k
;; in zsh insert mode).
;; (keymap-global-set "C-k" #'kill-whole-line)
;;
;; Shift+arrows: move between windows. Conflicts with shift-selection.
;; (windmove-default-keybindings)
;;
;; ()/[] swap. On Linux this was xmodmap; the xkb version is commented out in
;; dotfiles/.config/xkb/symbols/custom. In Emacs it was Windows-only:
;; (when (eq system-type 'windows-nt)
;;   (keyboard-translate ?\( ?\[) (keyboard-translate ?\[ ?\()
;;   (keyboard-translate ?\) ?\]) (keyboard-translate ?\] ?\)))

;;; init.el ends here
