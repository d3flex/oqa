;;; oqa-jobs.el --- OpenQA jobs view for a build  -*- lexical-binding: t; -*-

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

;; The jobs of a build, from /api/v1/jobs.  Flavor/arch/machine are read
;; out of each job's `settings' map.  RET opens the single-job view.
;; Filtering (transient infixes) is added by a later story; this view
;; lists a build's jobs unfiltered.

;;; Code:

(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-job)

(defcustom oqa-jobs-limit 100
  "Default maximum number of jobs fetched for a build."
  :type 'integer
  :group 'oqa)

(defface oqa-passed '((t :inherit success))
  "Face for a passed job result." :group 'oqa)

(defface oqa-failed '((t :inherit error))
  "Face for a failed (or incomplete/timed-out) job result." :group 'oqa)

(defface oqa-softfailed '((t :inherit warning))
  "Face for a softfailed job result." :group 'oqa)

(defface oqa-running
  '((((background dark))  :foreground "#61afef")
    (((background light)) :foreground "#0066cc")
    (t :inherit link))
  "Face for a job that is still running or otherwise in progress." :group 'oqa)

(defface oqa-muted '((t :inherit shadow))
  "Face for inert job states/results (skipped, cancelled, scheduled, none)."
  :group 'oqa)

(defun oqa--result-face (result)
  "Return the face for a job RESULT string, or nil for no coloring."
  (pcase result
    ("passed" 'oqa-passed)
    ("softfailed" 'oqa-softfailed)
    ((or "failed" "incomplete" "timeout_exceeded" "parallel_failed") 'oqa-failed)
    ((or "skipped" "obsoleted" "none" "user_cancelled" "") 'oqa-muted)
    (_ nil)))

(defun oqa--state-face (state)
  "Return the face for a job STATE string, or nil for no coloring."
  (pcase state
    ((or "running" "uploading" "setup" "assigned") 'oqa-running)
    ((or "scheduled" "cancelled") 'oqa-muted)
    (_ nil)))

(defun oqa--colorize (text face)
  "Return TEXT propertized with FACE, or TEXT unchanged when FACE is nil."
  (if face (propertize text 'face face) text))

(defun oqa--job-setting (job key)
  "Return string value of settings KEY in JOB, or an empty string."
  (let ((s (gethash "settings" job)))
    (format "%s" (or (and s (gethash key s)) ""))))

(defun oqa--jobs-rows (data)
  "Build tabulated-list entries from DATA, a jobs response hash."
  (let ((jobs (gethash "jobs" data)))
    (mapcar
     (lambda (j)
       (let ((id (gethash "id" j))
             (state (format "%s" (or (gethash "state" j) "")))
             (result (format "%s" (or (gethash "result" j) ""))))
         (list
          id
          (vector (number-to-string id)
                  (format "%s" (or (gethash "test" j) ""))
                  (oqa--job-setting j "FLAVOR")
                  (oqa--job-setting j "ARCH")
                  (oqa--job-setting j "MACHINE")
                  (oqa--colorize state (oqa--state-face state))
                  (oqa--colorize result (oqa--result-face result))))))
     (append (or jobs (vector)) nil))))

(defun oqa--jobs-query (group-id build)
  "Return the /api/v1/jobs query alist for GROUP-ID and BUILD."
  (list (cons "group_id" group-id)
        (cons "build" build)
        (cons "limit" oqa-jobs-limit)))

(defun oqa--jobs-render (group-id build data)
  "Render jobs DATA for GROUP-ID and BUILD into the current buffer."
  (setq oqa--context (list :group-id group-id :build build))
  (setq oqa--open-fn #'oqa--jobs-open)
  (setq oqa--refresh-fn (lambda () (oqa--jobs-reload group-id build)))
  (setq tabulated-list-format
        [("Id" 9 t) ("Test" 38 t) ("Flavor" 16 t) ("Arch" 9 t)
         ("Machine" 12 t) ("State" 10 t) ("Result" 12 t)])
  (setq tabulated-list-entries (oqa--jobs-rows data))
  (tabulated-list-init-header)
  (tabulated-list-print))

(defun oqa--jobs-reload (group-id build)
  "Refresh the jobs buffer for GROUP-ID and BUILD."
  (let ((data (oqa--api-get "/api/v1/jobs" (oqa--jobs-query group-id build))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--jobs-render group-id build data))))

(defun oqa--jobs-open (id)
  "Open the single-job view for job ID."
  (oqa-job id (current-buffer) (oqa--instance)))

(defun oqa-jobs (group-id build &optional parent instance)
  "Open the jobs view for BUILD of GROUP-ID.
PARENT is the buffer to return to; INSTANCE the active instance label."
  (let ((data (oqa--api-get "/api/v1/jobs" (oqa--jobs-query group-id build))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--open-view (format "*oqa: jobs %s*" build)
                      parent (or instance (oqa--instance))
                      (lambda () (oqa--jobs-render group-id build data))))))

(provide 'oqa-jobs)
;;; oqa-jobs.el ends here
