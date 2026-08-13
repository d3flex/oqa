;;; oqa-list.el --- Shared list mode and navigation for oqa  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Ioannis Bonatakis

;; Author: Ioannis Bonatakis <ybonatakis@suse.com>
;; Assisted-by: Claude:claude-opus-5
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

;; `oqa-list-mode' is the read-only tabulated-list base every navigation
;; view derives its behaviour from.  Each buffer keeps its own context:
;; the parent buffer to return to (`^'), a refresh thunk (`g'), and the
;; function used to drill into the entry at point (RET).  Views set those
;; buffer-locally through `oqa--open-view'.

;;; Code:

(require 'tabulated-list)
(require 'oqa-instance)

;; `oqa-dispatch' lives in oqa-transient.el, which requires this file;
;; declare it here to avoid a load cycle while keeping the byte-compiler
;; quiet.  It is autoloaded, so the `o'/`?' bindings resolve at runtime.
(declare-function oqa-dispatch "oqa-transient")
;; `oqa-workers' likewise requires this file; declared for the `w' binding.
(declare-function oqa-workers "oqa-workers")

(defvar-local oqa--parent-buffer nil
  "Buffer to return to with `oqa-up'.")

(defvar-local oqa--context nil
  "Plist of navigation context for this buffer (e.g. :group-id, :build).")

(defvar-local oqa--open-fn nil
  "Function called with the entry id at point to drill into it.")

(defvar-local oqa--refresh-fn nil
  "Function of no arguments that repopulates this buffer.")

(defvar oqa-list-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'oqa-open)
    (define-key map (kbd "q")   #'quit-window)
    (define-key map (kbd "^")   #'oqa-up)
    (define-key map (kbd "u")   #'oqa-up)
    (define-key map (kbd "g")   #'oqa-refresh)
    (define-key map (kbd "o")   #'oqa-dispatch)
    (define-key map (kbd "?")   #'oqa-dispatch)
    ;; Switch the active instance directly from any list view.
    (define-key map (kbd "O")   #'oqa-use-o3)
    (define-key map (kbd "D")   #'oqa-use-osd)
    (define-key map (kbd "i")   #'oqa-switch-instance)
    ;; Jump to the workers view from anywhere.
    (define-key map (kbd "w")   #'oqa-workers)
    map)
  "Keymap shared by all oqa list views.
Navigation works directly here — RET drills, `u'/`^' go up, `q'
buries, `g' refreshes — so the dispatch transient (`o'/`?') is only
needed for the richer, context-specific actions, never for plain
navigation.")

(define-derived-mode oqa-list-mode tabulated-list-mode "oqa"
  "Base major mode for oqa list buffers.
Buffers are read-only; navigation uses \\<oqa-list-mode-map>\\[oqa-open], \
\\[oqa-up], \\[oqa-refresh] and \\[oqa-dispatch]."
  (setq truncate-lines t)
  (setq tabulated-list-sort-key nil)
  (hl-line-mode 1))

(defun oqa-open ()
  "Drill into the entry at point using this buffer's open function."
  (interactive)
  (let ((id (tabulated-list-get-id)))
    (if (and id oqa--open-fn)
        (funcall oqa--open-fn id)
      (user-error "Nothing to open here"))))

(defun oqa-up ()
  "Return to the parent view, if any."
  (interactive)
  (if (buffer-live-p oqa--parent-buffer)
      (pop-to-buffer-same-window oqa--parent-buffer)
    (message "oqa: already at the top")))

(defun oqa-refresh ()
  "Reload the current view."
  (interactive)
  (if oqa--refresh-fn
      (funcall oqa--refresh-fn)
    (message "oqa: nothing to refresh")))

(defun oqa--open-view (name parent instance populate &optional mode)
  "Create or reuse buffer NAME as a child of PARENT and populate it.
INSTANCE is the active instance label to inherit.  POPULATE is a thunk
run in the new buffer that sets the table format, entries, `oqa--open-fn'
and `oqa--refresh-fn'.  MODE is the major mode to enable (a mode derived
from `oqa-list-mode', e.g. `oqa-jobs-mode' for its own keymap); it
defaults to `oqa-list-mode'."
  (let ((buf (get-buffer-create name)))
    (pop-to-buffer-same-window buf)
    (funcall (or mode #'oqa-list-mode))
    (setq oqa--parent-buffer parent)
    (when instance (setq oqa--instance instance))
    (funcall populate)
    buf))

(provide 'oqa-list)
;;; oqa-list.el ends here
