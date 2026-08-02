;;; oqa-log.el --- Read-only log viewing for oqa  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Ioannis Bonatakis

;; Author: Ioannis Bonatakis <ybonatakis@suse.com>
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

;; Shared plumbing for showing a log (a job's autoinst-log, or a worker's
;; degraded status text) in a read-only buffer.  `oqa--log-outcome'
;; classifies a text fetch as ok / unavailable (a 404) / error so callers
;; can report "unavailable" distinctly from a hard failure (FR-029).

;;; Code:

(require 'oqa-api)

(defvar oqa-log-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'quit-window)
    map)
  "Keymap for `oqa-log-mode'.")

(define-derived-mode oqa-log-mode special-mode "oqa-log"
  "Read-only major mode for an oqa log buffer.")

(defun oqa--log-outcome (result)
  "Classify a text-fetch RESULT.
Return `ok' for a string body, `unavailable' for a 404 `oqa-error', and
`error' for any other `oqa-error'."
  (cond
   ((stringp result) 'ok)
   ((and (oqa-error-p result) (eql (oqa-error-status result) 404)) 'unavailable)
   (t 'error)))

(defun oqa--log-buffer (title text)
  "Return a read-only `oqa-log-mode' buffer titled TITLE holding TEXT."
  (let ((buf (get-buffer-create (format "*oqa log: %s*" title))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert text)
        (goto-char (point-min)))
      (oqa-log-mode))
    buf))

(defun oqa--show-log (title text)
  "Display TEXT in a read-only log buffer titled TITLE and return it."
  (let ((buf (oqa--log-buffer title text)))
    (pop-to-buffer buf)
    buf))

(provide 'oqa-log)
;;; oqa-log.el ends here
