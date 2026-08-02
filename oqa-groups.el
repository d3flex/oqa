;;; oqa-groups.el --- OpenQA job-groups view  -*- lexical-binding: t; -*-

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

;; The entry view: every job group on the active instance, with its
;; parent group resolved from /api/v1/parent_groups.  RET drills into a
;; group's builds.

;;; Code:

(require 'seq)
(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-builds)

(defun oqa--parents-table (parents)
  "Return a hash-table mapping parent-group id to name from PARENTS (a vector)."
  (let ((h (make-hash-table :test 'eql)))
    (when (vectorp parents)
      (seq-doseq (p parents)
        (puthash (gethash "id" p) (gethash "name" p) h)))
    h))

(defun oqa--groups-rows (groups parents)
  "Build tabulated-list entries from GROUPS (a vector).
PARENTS is a hash-table id->name used to render the parent column."
  (mapcar
   (lambda (g)
     (let* ((id (gethash "id" g))
            (name (format "%s" (or (gethash "name" g) "")))
            (pid (gethash "parent_id" g))
            (parent (if (and pid parents) (or (gethash pid parents) "") "")))
       (list id (vector name parent))))
   (append groups nil)))

(defun oqa--groups-render (groups parents)
  "Render GROUPS with PARENTS into the current groups buffer."
  (setq oqa--context nil)
  (setq oqa--open-fn #'oqa--groups-open)
  (setq oqa--refresh-fn #'oqa--groups-reload)
  (setq tabulated-list-format [("Group" 48 t) ("Parent" 30 t)])
  (setq tabulated-list-entries (oqa--groups-rows groups parents))
  (tabulated-list-init-header)
  (tabulated-list-print))

(defun oqa--groups-fetch ()
  "Fetch (groups . parents-table) or return an `oqa-error'."
  (let ((groups (oqa--api-get "/api/v1/job_groups")))
    (if (oqa-error-p groups)
        groups
      (let ((parents (oqa--api-get "/api/v1/parent_groups")))
        (cons groups (oqa--parents-table
                      (if (oqa-error-p parents) nil parents)))))))

(defun oqa--groups-reload ()
  "Refresh the current groups buffer."
  (let ((res (oqa--groups-fetch)))
    (if (oqa-error-p res)
        (message "%s" (oqa--render-error res))
      (oqa--groups-render (car res) (cdr res)))))

(defun oqa--groups-open (id)
  "Drill from group ID into its builds."
  (oqa-builds id (current-buffer) (oqa--instance)))

;;;###autoload
(defun oqa-groups ()
  "Open the job-groups view for the active instance."
  (interactive)
  (let ((res (oqa--groups-fetch)))
    (if (oqa-error-p res)
        (message "%s" (oqa--render-error res))
      (let ((groups (car res))
            (parents (cdr res)))
        (oqa--open-view "*oqa: groups*" nil (oqa--instance)
                        (lambda () (oqa--groups-render groups parents)))))))

(provide 'oqa-groups)
;;; oqa-groups.el ends here
