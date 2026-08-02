;;; oqa-actions.el --- State-changing OpenQA job actions  -*- lexical-binding: t; -*-

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

;; The only part of oqa that changes server state.  Every mutation is
;; confirmed, targets the active instance's host, and is carried out by
;; the user's installed `openqa-cli' / `openqa-clone-job', which read the
;; credentials in ~/.config/openqa/client.conf — oqa never handles a
;; secret itself (Principle III/IV).  If the CLI is not on PATH the
;; action is blocked with a message and nothing is submitted (FR-020).

;;; Code:

(require 'oqa-api)
(require 'oqa-instance)
(require 'oqa-list)

(defcustom oqa-cli-program "openqa-cli"
  "External program used for OpenQA REST mutations (restart, trigger)."
  :type 'string
  :group 'oqa)

(defcustom oqa-clone-program "openqa-clone-job"
  "External program used to clone a job with custom settings."
  :type 'string
  :group 'oqa)

;;; Guards and helpers -------------------------------------------------

(defun oqa--require-cli (program)
  "Return PROGRAM if it is on `exec-path', else signal a `user-error'.
This blocks a mutation before anything is submitted when the required
command-line tool is not installed (FR-020)."
  (if (executable-find program)
      program
    (user-error "oqa: %s not found in PATH; install openQA-client to act on jobs"
                program)))

(defun oqa--confirm (prompt)
  "Ask PROMPT with `y-or-n-p'; return non-nil only on an explicit yes.
Every state-changing action funnels through here (FR-017)."
  (y-or-n-p prompt))

(defun oqa--job-id-at-point ()
  "Return the job id to act on.
In a list view this is the entry at point; in the single-job view it is
the id kept in `oqa--context'.  Signals a `user-error' when neither is
available."
  (or (and (derived-mode-p 'tabulated-list-mode) (tabulated-list-get-id))
      (plist-get oqa--context :job-id)
      (user-error "oqa: no job at point")))

(defun oqa--job-settings (id)
  "Fetch job ID from the active instance and return its settings hash.
Returns nil when the job cannot be fetched (the caller degrades to empty
prefill).  This is a credential-free read used only to prefill prompts."
  (let ((data (oqa--api-get (format "/api/v1/jobs/%s" id))))
    (unless (oqa-error-p data)
      (let ((job (or (and (hash-table-p data) (gethash "job" data)) data)))
        (and (hash-table-p job) (gethash "settings" job))))))

(defun oqa--run-cli (program args)
  "Run PROGRAM with ARGS synchronously.
Return a cons (EXIT-CODE . OUTPUT) where OUTPUT is the combined
stdout/stderr as a string."
  (with-temp-buffer
    (let ((code (apply #'process-file program nil t nil args)))
      (cons code (buffer-string)))))

(defun oqa--run-cli-report (program args description)
  "Run PROGRAM ARGS and report the outcome of DESCRIPTION (FR-019).
On success show a one-line message and refresh the current view; on
failure pop a buffer with the command and its output."
  (let* ((res  (oqa--run-cli program args))
         (code (car res))
         (out  (string-trim (cdr res))))
    (if (and (integerp code) (zerop code))
        (progn
          (message "oqa: %s ok%s" description
                   (if (string-empty-p out)
                       ""
                     (format " — %s" (car (split-string out "\n")))))
          (when (and oqa--refresh-fn (functionp oqa--refresh-fn))
            (funcall oqa--refresh-fn)))
      (with-current-buffer (get-buffer-create "*oqa-cli*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "$ %s %s\n\n" program (mapconcat #'identity args " ")))
          (insert (format "exited with %s\n\n" code))
          (insert (if (string-empty-p out) "(no output)" out))
          (goto-char (point-min)))
        (special-mode)
        (display-buffer (current-buffer)))
      (message "oqa: %s FAILED (see *oqa-cli*)" description))))

;;; Argument builders (pure — unit-tested) ----------------------------

(defun oqa--restart-args (host id)
  "Return `openqa-cli' arguments to restart job ID on HOST."
  (list "api" "--host" host "-X" "POST" (format "jobs/%s/restart" id)))

(defun oqa--clone-args (host id kvs)
  "Return `openqa-clone-job' arguments to clone job ID on HOST.
KVS is a list of \"KEY=value\" override strings appended to the command."
  (append (list "--host" host (format "%s/tests/%s" host id)) kvs))

(defun oqa--iso-args (host params)
  "Return `openqa-cli' arguments to POST isos on HOST.
PARAMS is an alist of product keys (DISTRI, VERSION, FLAVOR, ARCH,
BUILD) to values, each rendered as a KEY=value command argument."
  (append (list "api" "--host" host "-X" "POST" "isos")
          (mapcar (lambda (kv) (format "%s=%s" (car kv) (cdr kv))) params)))

;;; Restart ------------------------------------------------------------

;;;###autoload
(defun oqa-restart-job ()
  "Restart the job at point with its existing settings.
Blocks when `oqa-cli-program' is absent and asks for confirmation before
submitting (FR-014/017/020)."
  (interactive)
  (let ((cli (oqa--require-cli oqa-cli-program)))
    (let ((id (oqa--job-id-at-point))
          (host (oqa--host)))
      (when (oqa--confirm (format "Restart job %s on %s? " id host))
        (oqa--run-cli-report cli (oqa--restart-args host id)
                             (format "restart job %s" id))))))

;;; Clone --------------------------------------------------------------

(defvar-local oqa--clone-id nil
  "Job id being cloned in an `oqa-clone-mode' buffer.")

(defvar-local oqa--clone-host nil
  "Target host for the clone in an `oqa-clone-mode' buffer.")

(defvar oqa-clone-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'oqa-clone-submit)
    (define-key map (kbd "C-c C-k") #'oqa-clone-cancel)
    map)
  "Keymap for `oqa-clone-mode'.")

(define-derived-mode oqa-clone-mode fundamental-mode "oqa-clone"
  "Edit buffer for cloning a job with custom settings.
Lines starting with `#' are comments.  \\<oqa-clone-mode-map>\
\\[oqa-clone-submit] submits the clone, \\[oqa-clone-cancel] cancels.")

(defun oqa--clone-kvs (settings)
  "Return sorted \"KEY=value\" strings for the SETTINGS hash, or nil."
  (let (rows)
    (when (hash-table-p settings)
      (maphash (lambda (k v) (push (format "%s=%s" k v) rows)) settings))
    (sort rows #'string<)))

;;;###autoload
(defun oqa-clone-job ()
  "Clone the job at point, editing its settings before submitting.
Pops a `KEY=value' edit buffer prefilled from the job's settings; submit
with \\<oqa-clone-mode-map>\\[oqa-clone-submit], cancel with \
\\[oqa-clone-cancel]."
  (interactive)
  (let ((cli (oqa--require-cli oqa-clone-program)))
    (ignore cli)
    (let* ((id (oqa--job-id-at-point))
           (host (oqa--host))
           (kvs (oqa--clone-kvs (oqa--job-settings id)))
           (buf (get-buffer-create (format "*oqa clone job %s*" id))))
      (pop-to-buffer buf)
      (oqa-clone-mode)
      (setq oqa--clone-id id
            oqa--clone-host host)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "# Clone job %s on %s\n" id host))
        (insert "# Edit KEY=value lines below, then C-c C-c to submit (C-c C-k cancels).\n")
        (insert "# Lines starting with # are ignored.\n\n")
        (dolist (kv kvs) (insert kv "\n")))
      (goto-char (point-min)))))

(defun oqa--clone-buffer-kvs ()
  "Return the non-comment, non-blank KEY=value lines of the current buffer."
  (let (kvs)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line (string-trim (buffer-substring-no-properties
                                  (line-beginning-position) (line-end-position)))))
          (when (and (not (string-empty-p line))
                     (not (string-prefix-p "#" line))
                     (string-match-p "=" line))
            (push line kvs)))
        (forward-line 1)))
    (nreverse kvs)))

(defun oqa-clone-submit ()
  "Submit the clone described by the current `oqa-clone-mode' buffer."
  (interactive)
  (let ((id oqa--clone-id)
        (host oqa--clone-host)
        (kvs (oqa--clone-buffer-kvs)))
    (unless (and id host)
      (user-error "oqa: not an oqa clone buffer"))
    (when (oqa--confirm (format "Clone job %s on %s with %d setting(s)? "
                                id host (length kvs)))
      (let ((buf (current-buffer)))
        (oqa--run-cli-report oqa-clone-program
                             (oqa--clone-args host id kvs)
                             (format "clone job %s" id))
        (kill-buffer buf)))))

(defun oqa-clone-cancel ()
  "Abandon the current clone edit buffer."
  (interactive)
  (quit-window t))

;;; Trigger a new build (iso) ------------------------------------------

;;;###autoload
(defun oqa-trigger-iso ()
  "Trigger a new build by POSTing to isos, prefilled from the job at point.
Prompts for DISTRI/VERSION/FLAVOR/ARCH/BUILD, confirms, then submits."
  (interactive)
  (let ((cli (oqa--require-cli oqa-cli-program)))
    (let* ((id (ignore-errors (oqa--job-id-at-point)))
           (settings (and id (oqa--job-settings id)))
           (host (oqa--host))
           (params (mapcar
                    (lambda (key)
                      (cons key
                            (read-string
                             (format "%s: " key)
                             (and settings (let ((v (gethash key settings)))
                                             (and v (format "%s" v)))))))
                    '("DISTRI" "VERSION" "FLAVOR" "ARCH" "BUILD"))))
      (when (oqa--confirm (format "Trigger new build %s %s %s on %s? "
                                  (cdr (assoc "DISTRI" params))
                                  (cdr (assoc "VERSION" params))
                                  (cdr (assoc "BUILD" params))
                                  host))
        (oqa--run-cli-report cli (oqa--iso-args host params)
                             "trigger new build")))))

(provide 'oqa-actions)
;;; oqa-actions.el ends here
