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
            (if err (format "  •  error: %s" err) ""))))

(defun oqa--worker-detail-render (id worker)
  "Render WORKER (id ID) properties into the current buffer."
  (setq oqa--context (list :worker-id id))
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
                  (lambda () (oqa--worker-detail-render id worker))))

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
                      (lambda () (oqa--workers-render data))))))

(provide 'oqa-workers)
;;; oqa-workers.el ends here
