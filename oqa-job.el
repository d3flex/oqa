;;; oqa-job.el --- OpenQA single-job view  -*- lexical-binding: t; -*-

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

;; A read-only detail view for one job: its settings (key = value) and
;; its module/step results, from /api/v1/jobs/<id>.  A still-running job
;; with no modules yet renders without error.

;;; Code:

(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-actions)

;; See oqa-list.el: `oqa-dispatch' is autoloaded from oqa-transient.el,
;; which requires this dependency chain; declare it to avoid a cycle.
(declare-function oqa-dispatch "oqa-transient")
(declare-function oqa-workers "oqa-workers")

(defvar oqa-job-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "^") #'oqa-up)
    (define-key map (kbd "u") #'oqa-up)
    (define-key map (kbd "g") #'oqa-refresh)
    (define-key map (kbd "o") #'oqa-dispatch)
    (define-key map (kbd "?") #'oqa-dispatch)
    ;; Act on this job (credentialed, via the external CLIs).
    (define-key map (kbd "r") #'oqa-restart-job)
    (define-key map (kbd "c") #'oqa-clone-job)
    (define-key map (kbd "T") #'oqa-trigger-iso)
    ;; Switch the active instance directly.
    (define-key map (kbd "O") #'oqa-use-o3)
    (define-key map (kbd "D") #'oqa-use-osd)
    (define-key map (kbd "i") #'oqa-switch-instance)
    (define-key map (kbd "w") #'oqa-workers)
    map)
  "Keymap for `oqa-job-mode'.")

(define-derived-mode oqa-job-mode special-mode "oqa-job"
  "Major mode for a single OpenQA job detail buffer.")

(defun oqa--job-unwrap (data)
  "Return the job hash from DATA, unwrapping a {\"job\":...} envelope."
  (or (and (hash-table-p data) (gethash "job" data)) data))

(defun oqa--job-settings-rows (job)
  "Return settings of JOB as a name-sorted list of (KEY . VALUE) strings."
  (let ((s (gethash "settings" job))
        rows)
    (when s
      (maphash (lambda (k v) (push (cons (format "%s" k) (format "%s" v)) rows)) s))
    (sort rows (lambda (a b) (string< (car a) (car b))))))

(defun oqa--job-module-rows (job)
  "Return modules of JOB as a list of (NAME . RESULT) strings.
Modules come from the `testresults' array of a job \"details\" response."
  (let ((mods (gethash "testresults" job)))
    (mapcar (lambda (m)
              (cons (format "%s" (or (gethash "name" m) ""))
                    (format "%s" (or (gethash "result" m) ""))))
            (append (or mods (vector)) nil))))

(defun oqa--job-render (id data)
  "Render job DATA (for job ID) into the current `oqa-job-mode' buffer."
  (let ((job (oqa--job-unwrap data))
        (inhibit-read-only t))
    (erase-buffer)
    (insert (format "Job %s: %s   [%s/%s]\n"
                    id
                    (or (gethash "test" job) "")
                    (or (gethash "state" job) "?")
                    (or (gethash "result" job) "-")))
    (insert (propertize "r restart · c clone · T trigger · u up · g refresh\n\n"
                        'face 'shadow))
    (insert "Settings\n")
    (let ((rows (oqa--job-settings-rows job)))
      (if rows
          (dolist (kv rows)
            (insert (format "  %s = %s\n" (car kv) (cdr kv))))
        (insert "  (none)\n")))
    (insert "\nModules\n")
    (let ((rows (oqa--job-module-rows job)))
      (if rows
          (dolist (mr rows)
            (insert (format "  %-44s %s\n" (car mr) (cdr mr))))
        (insert "  (no modules yet)\n")))
    (goto-char (point-min))))

(defun oqa--job-reload (id)
  "Refresh the buffer for job ID."
  (let ((data (oqa--api-get (format "/api/v1/jobs/%s/details" id))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--job-render id data))))

(defun oqa-job (id &optional parent instance)
  "Open the detail view for job ID.
PARENT is the buffer to return to; INSTANCE the active instance label."
  (let ((data (oqa--api-get (format "/api/v1/jobs/%s/details" id))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (let ((buf (get-buffer-create (format "*oqa: job %s*" id))))
        (pop-to-buffer-same-window buf)
        (oqa-job-mode)
        (setq oqa--parent-buffer parent)
        (when instance (setq oqa--instance instance))
        (setq oqa--context (list :job-id id))
        (setq oqa--refresh-fn (lambda () (oqa--job-reload id)))
        (oqa--job-render id data)
        buf))))

(provide 'oqa-job)
;;; oqa-job.el ends here
