;;; oqa-builds.el --- OpenQA builds view for a group  -*- lexical-binding: t; -*-

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

;; The per-group build overview (the generalisation of the old, retired
;; `oqa-status'): each build with its pass/fail/soft/unfinished counts,
;; sourced from /group_overview/<id>.json.  RET drills into a build's
;; jobs.

;;; Code:

(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-jobs)

(defun oqa--num (v)
  "Render V as a count string, treating nil as 0."
  (number-to-string (or v 0)))

(defun oqa--builds-rows (group-id data)
  "Build entries from DATA (a group_overview hash) for GROUP-ID.
Each entry id is a plist carrying :group-id and :build for the jobs drill."
  (let ((builds (gethash "build_results" data)))
    (mapcar
     (lambda (b)
       (let ((build (format "%s" (or (gethash "build" b) ""))))
         (list
          (list :group-id group-id :build build)
          (vector build
                  (format "%s" (or (gethash "version" b) ""))
                  (oqa--num (gethash "total" b))
                  (oqa--num (gethash "passed" b))
                  (oqa--num (gethash "failed" b))
                  (oqa--num (gethash "softfailed" b))
                  (oqa--num (gethash "unfinished" b))))))
     (append (or builds (vector)) nil))))

(defun oqa--builds-render (group-id data)
  "Render build overview DATA for GROUP-ID into the current buffer."
  (setq oqa--context (list :group-id group-id))
  (setq oqa--open-fn #'oqa--builds-open)
  (setq oqa--refresh-fn (lambda () (oqa--builds-reload group-id)))
  (setq tabulated-list-format
        [("Build" 22 nil) ("Version" 14 t) ("Total" 7 t)
         ("Pass" 7 t) ("Fail" 7 t) ("Soft" 7 t) ("Unfin" 7 t)])
  (setq tabulated-list-entries (oqa--builds-rows group-id data))
  (tabulated-list-init-header)
  (tabulated-list-print))

(defun oqa--builds-reload (group-id)
  "Refresh the builds buffer for GROUP-ID."
  (let ((data (oqa--api-get (format "/group_overview/%s.json" group-id))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--builds-render group-id data))))

(defun oqa--builds-open (id)
  "Drill from a build entry ID (plist) into its jobs."
  (oqa-jobs (plist-get id :group-id) (plist-get id :build)
            (current-buffer) (oqa--instance)))

(defun oqa-builds (group-id &optional parent instance)
  "Open the builds view for GROUP-ID.
PARENT is the buffer to return to; INSTANCE the active instance label."
  (let ((data (oqa--api-get (format "/group_overview/%s.json" group-id))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--open-view (format "*oqa: builds %s*" group-id)
                      parent (or instance (oqa--instance))
                      (lambda () (oqa--builds-render group-id data))))))

(provide 'oqa-builds)
;;; oqa-builds.el ends here
