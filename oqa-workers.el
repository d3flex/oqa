;;; oqa-workers.el --- OpenQA workers view  -*- lexical-binding: t; -*-

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

;; The workers of the active instance, from /api/v1/workers.  Each row is
;; a worker's host:instance identity, its status, and its WORKER_CLASS.
;; RET opens a detail view listing that worker's `properties' as
;; key = value rows.  Independent of the job hierarchy — reachable with
;; `w' from any view.

;;; Code:

(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-log)
(require 'oqa-job)

(defvar oqa-workers-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation is inherited from `oqa-list-mode'; add the log key.
    (define-key map (kbd "l") #'oqa-worker-log)
    map)
  "Keymap for `oqa-workers-mode' (adds the worker-log key to the list keys).")

(define-derived-mode oqa-workers-mode oqa-list-mode "oqa-workers"
  "Major mode for the oqa workers list and worker-detail views.
Derives from `oqa-list-mode' (shared navigation) and binds `l' to show
the worker's log.")

(defvar-local oqa--workers-by-id nil
  "Hash mapping worker id to its worker hash for the current buffer.")

(defun oqa--worker-identity (w)
  "Return the host:instance identity string for worker hash W."
  (format "%s:%s" (gethash "host" w) (gethash "instance" w)))

(defun oqa--worker-status-face (status)
  "Return a face for worker STATUS, or nil for no colouring."
  (pcase status
    ((or "running" "working") 'success)
    ((or "dead" "broken") 'error)
    ("idle" 'shadow)
    (_ nil)))

(defun oqa--worker-colorize (status)
  "Return STATUS propertized by its status face, or unchanged."
  (let ((face (oqa--worker-status-face status)))
    (if face (propertize status 'face face) status)))

(defun oqa--worker-class (w)
  "Return the WORKER_CLASS of worker hash W as a string, or empty."
  (let ((props (gethash "properties" w)))
    (format "%s" (or (and (hash-table-p props) (gethash "WORKER_CLASS" props)) ""))))

(defun oqa--workers-rows (data)
  "Build tabulated-list entries from DATA, a workers response hash."
  (let ((workers (gethash "workers" data)))
    (mapcar
     (lambda (w)
       (let ((id (gethash "id" w))
             (status (format "%s" (or (gethash "status" w) ""))))
         (list id (vector (oqa--worker-identity w)
                          (oqa--worker-colorize status)
                          (oqa--worker-class w)))))
     (append (or workers (vector)) nil))))

(defun oqa--workers-index (data)
  "Return a hash mapping worker id to its worker hash, from DATA."
  (let ((h (make-hash-table :test 'eql)))
    (dolist (w (append (or (gethash "workers" data) (vector)) nil))
      (puthash (gethash "id" w) w h))
    h))

(defun oqa--worker-property-rows (w)
  "Return properties of worker W as a name-sorted list of (KEY . VALUE)."
  (let ((props (gethash "properties" w))
        rows)
    (when (hash-table-p props)
      (maphash (lambda (k v) (push (cons (format "%s" k) (format "%s" v)) rows)) props))
    (sort rows (lambda (a b) (string< (car a) (car b))))))

;;; Worker detail ------------------------------------------------------

(defun oqa--worker-header (w)
  "Return the header-line string for worker hash W."
  (let ((err (gethash "error" w)))
    (concat (format " Worker %s  •  %s" (oqa--worker-identity w)
                    (or (gethash "status" w) "?"))
            (if err (format "  •  error: %s" err) "")
            "  •  l: log")))

(defun oqa--worker-detail-render (id worker)
  "Render WORKER (id ID) properties into the current buffer."
  (setq oqa--context (list :worker-id id :worker worker))
  (setq oqa--open-fn nil)
  (setq oqa--refresh-fn (lambda () (oqa--worker-detail-render id worker)))
  ;; Free the header line for the worker identity/status (see oqa-jobs.el).
  (setq tabulated-list-use-header-line nil)
  (setq header-line-format (oqa--worker-header worker))
  (setq tabulated-list-format [("Property" 28 t) ("Value" 60 nil)])
  (setq tabulated-list-entries
        (mapcar (lambda (kv) (list (car kv) (vector (car kv) (cdr kv))))
                (oqa--worker-property-rows worker)))
  (tabulated-list-init-header)
  (tabulated-list-print))

(defun oqa-worker (id worker &optional parent instance)
  "Open the detail view for WORKER (id ID).
PARENT is the buffer to return to; INSTANCE the active instance label."
  (oqa--open-view (format "*oqa: worker %s*" id)
                  parent (or instance (oqa--instance))
                  (lambda () (oqa--worker-detail-render id worker))
                  #'oqa-workers-mode))

;;; Workers list -------------------------------------------------------

(defun oqa--workers-render (data)
  "Render workers DATA into the current buffer."
  (setq oqa--workers-by-id (oqa--workers-index data))
  (setq oqa--context nil)
  (setq oqa--open-fn #'oqa--workers-open)
  (setq oqa--refresh-fn #'oqa--workers-reload)
  (setq tabulated-list-format [("Worker" 26 t) ("Status" 10 t) ("Class" 40 t)])
  (setq tabulated-list-entries (oqa--workers-rows data))
  (tabulated-list-init-header)
  (tabulated-list-print))

(defun oqa--workers-reload ()
  "Refresh the current workers buffer."
  (let ((data (oqa--api-get "/api/v1/workers")))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--workers-render data))))

(defun oqa--workers-open (id)
  "Drill from worker ID into its property detail view."
  (let ((w (and oqa--workers-by-id (gethash id oqa--workers-by-id))))
    (if w
        (oqa-worker id w (current-buffer) (oqa--instance))
      (user-error "oqa: worker %s not found" id))))

;;;###autoload
(defun oqa-workers ()
  "Open the workers view for the active instance."
  (interactive)
  (let ((data (oqa--api-get "/api/v1/workers"))
        (parent (and (derived-mode-p 'oqa-list-mode 'oqa-job-mode)
                     (current-buffer))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--open-view "*oqa: workers*" parent (oqa--instance)
                      (lambda () (oqa--workers-render data))
                      #'oqa-workers-mode))))

;;; Worker log (degraded) ----------------------------------------------

(defun oqa--worker-at-point ()
  "Return the worker hash to act on, from the list row or the detail view."
  (or (and oqa--workers-by-id
           (gethash (tabulated-list-get-id) oqa--workers-by-id))
      (plist-get oqa--context :worker)
      (user-error "oqa: no worker at point")))

(defun oqa--worker-running-job (w)
  "Return the id of the job worker W is currently running, or nil.
The workers endpoint does not always carry this; the fields checked here
are the ones present when a worker is busy."
  (or (gethash "jobid" w)
      (let ((job (gethash "job" w)))
        (and (hash-table-p job) (gethash "id" job)))))

(defun oqa--worker-log-text (w)
  "Return the degraded log text for worker W (FR-029).
No worker-log endpoint is exposed by the OpenQA REST API, so show the
worker's status and error and explain where the real logs live."
  (concat
   (format "Worker %s\n" (oqa--worker-identity w))
   (format "Status:  %s\n" (or (gethash "status" w) "?"))
   (let ((e (gethash "error" w)))
     (if e (format "Error:   %s\n" e) ""))
   "\n"
   "No worker-log endpoint is exposed by this OpenQA instance.\n"
   "Worker logs live on the worker host (journald / /var/log on the\n"
   "machine running the worker).  Only a running worker's current job\n"
   "log is retrievable through oqa.\n"))

;;;###autoload
(defun oqa-worker-log ()
  "Show the log for the worker at point.
If the worker is running a job, show that job's log; otherwise degrade to
the worker's status/error with a clear \"unavailable\" explanation."
  (interactive)
  (let* ((w (oqa--worker-at-point))
         (jobid (oqa--worker-running-job w)))
    (if jobid
        (oqa--job-log-id jobid)
      (oqa--show-log (format "worker %s" (oqa--worker-identity w))
                     (oqa--worker-log-text w)))))

(provide 'oqa-workers)
;;; oqa-workers.el ends here
