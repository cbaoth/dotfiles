;;; early-init.el --- Runs before the first frame is drawn -*- lexical-binding: t -*-

;;; Commentary:
;; Only what has to happen before the first GUI frame appears; everything else
;; lives in init.el. No effect in a terminal.

;;; Code:

;; Hide the tool bar and the scroll bars up front, so they never flash on
;; screen. The menu bar stays: while relearning, it is the quickest way to
;; find a command (F10 opens it, in a terminal too).
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;;; early-init.el ends here
