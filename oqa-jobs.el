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
;;
;; The jobs view has its own major mode (`oqa-jobs-mode') and its own
;; menu (`oqa-jobs-transient', on `o'/`?'/`f') because filtering only
;; makes sense here.  The transient offers one-key presets (running,
;; failed, …) that reload immediately, plus `-s'/`-r' and friends for
;; arbitrary filters applied with RET.  The active filters are always
;; shown in the buffer's header line.

;;; Code:

(require 'transient)
(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-job)

(defcustom oqa-jobs-limit 100
  "Default maximum number of jobs fetched for a build."
  :type 'integer
  :group 'oqa)

(defvar oqa-jobs-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation (RET/u/^/q/g) is inherited from `oqa-list-mode'; the
    ;; menu key opens the filter transient and `x' clears filters right
    ;; from the buffer (matching the header-line hint).
    (define-key map (kbd "o") #'oqa-jobs-transient)
    (define-key map (kbd "?") #'oqa-jobs-transient)
    (define-key map (kbd "f") #'oqa-jobs-transient)
    (define-key map (kbd "x") #'oqa-jobs-clear-filters)
    map)
  "Keymap for `oqa-jobs-mode' (adds the filter menu to the shared keys).")

(define-derived-mode oqa-jobs-mode oqa-list-mode "oqa-jobs"
  "Major mode for the oqa jobs view.
Derives from `oqa-list-mode' (so RET/`u'/`^'/`q'/`g' navigate as
everywhere else) and rebinds `o'/`?'/`f' to `oqa-jobs-transient'.")

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

(defun oqa--arg-name (switch)
  "Return the query parameter name for a transient SWITCH.
The leading \"--\" and trailing \"=\" are stripped, so \"--state=\"
becomes \"state\"."
  (replace-regexp-in-string "\\`--\\|=\\'" "" switch))

(defun oqa--parse-arg (arg)
  "Parse one transient ARG into a (KEY . VALUE) query cons.
ARG is either a single-value string like \"--result=failed\" or a
multi-value list like (\"--state=\" \"running\" \"done\"), which is the
shape `transient-args' returns for a :multi-value option.  For the
multi-value form the cdr is the list of values, so `oqa--query-string'
emits one repeated parameter per value."
  (if (consp arg)
      (cons (oqa--arg-name (car arg)) (cdr arg))
    (let ((eq (string-match "=" arg)))
      (cons (oqa--arg-name (substring arg 0 (1+ eq)))
            (substring arg (1+ eq))))))

(defun oqa--args->query (args)
  "Convert transient ARGS (from `transient-args') into a query alist."
  (mapcar #'oqa--parse-arg args))

(defun oqa--jobs-query (group-id build &optional args)
  "Return the /api/v1/jobs query alist for GROUP-ID and BUILD.
ARGS is an optional list of transient filter arguments; a default
`oqa-jobs-limit' is added only when ARGS does not already set a limit."
  (let ((filters (oqa--args->query args)))
    (append (list (cons "group_id" group-id)
                  (cons "build" build))
            filters
            (unless (assoc "limit" filters)
              (list (cons "limit" oqa-jobs-limit))))))

(defun oqa--jobs-empty-message (args)
  "Return the empty-state message for a jobs view given filter ARGS.
When ARGS is non-nil the wording makes clear that filters, not the
build, produced the empty list (FR-013)."
  (if args
      "No jobs match the current filters."
    "This build has no jobs."))

(defun oqa--filter-summary (&optional args)
  "Return a short string describing the active jobs filters, or nil.
ARGS defaults to the filters stored in the current buffer's context, so
callers can show what is currently applied (FR-012)."
  (let ((args (or args (plist-get oqa--context :args))))
    (when args
      (mapconcat
       (lambda (kv)
         (let ((vals (cdr kv)))
           (format "%s=%s" (car kv)
                   (if (listp vals) (string-join vals ",") vals))))
       (oqa--args->query args) " "))))

(defun oqa--jobs-header (build args)
  "Return the header-line string for BUILD with active filter ARGS.
Keeps the applied filters visible without opening any menu (FR-012)."
  (let ((sum (oqa--filter-summary args)))
    (concat (format " Build %s" build)
            (if sum
                (format "  •  filters: %s  (o: change, x: clear)" sum)
              "  •  no filters  (o: filter)"))))

(defun oqa--jobs-render (group-id build data &optional args)
  "Render jobs DATA for GROUP-ID and BUILD into the current buffer.
ARGS is the list of active transient filter arguments; it is stored in
the buffer context so `g' (refresh) re-applies the same filters, drives
the header line, and selects the wording of the empty state."
  (setq oqa--context (list :group-id group-id :build build :args args))
  (setq oqa--open-fn #'oqa--jobs-open)
  (setq oqa--refresh-fn (lambda () (oqa--jobs-reload group-id build args)))
  (setq header-line-format (oqa--jobs-header build args))
  (setq tabulated-list-format
        [("Id" 9 t) ("Test" 38 t) ("Flavor" 16 t) ("Arch" 9 t)
         ("Machine" 12 t) ("State" 10 t) ("Result" 12 t)])
  (setq tabulated-list-entries (oqa--jobs-rows data))
  (tabulated-list-init-header)
  (tabulated-list-print)
  (unless tabulated-list-entries
    (let ((inhibit-read-only t))
      (save-excursion
        (goto-char (point-max))
        (insert (propertize (oqa--jobs-empty-message args)
                            'face 'oqa-muted))
        (insert "\n")))))

(defun oqa--jobs-reload (group-id build &optional args)
  "Refresh the jobs buffer for GROUP-ID and BUILD applying filter ARGS."
  (let ((data (oqa--api-get "/api/v1/jobs" (oqa--jobs-query group-id build args))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--jobs-render group-id build data args))))

(defun oqa--jobs-open (id)
  "Open the single-job view for job ID."
  (oqa-job id (current-buffer) (oqa--instance)))

(defun oqa-jobs (group-id build &optional parent instance args)
  "Open the jobs view for BUILD of GROUP-ID.
PARENT is the buffer to return to; INSTANCE the active instance label;
ARGS an optional list of transient filter arguments."
  (let ((data (oqa--api-get "/api/v1/jobs" (oqa--jobs-query group-id build args))))
    (if (oqa-error-p data)
        (message "%s" (oqa--render-error data))
      (oqa--open-view (format "*oqa: jobs %s*" build)
                      parent (or instance (oqa--instance))
                      (lambda () (oqa--jobs-render group-id build data args))
                      #'oqa-jobs-mode))))

(defun oqa--jobs-reload-here (args)
  "Reload the current jobs view with filter ARGS.
Signals a `user-error' outside a jobs buffer (one whose context carries
a group id and build)."
  (let ((group-id (plist-get oqa--context :group-id))
        (build (plist-get oqa--context :build)))
    (unless (and group-id build)
      (user-error "oqa: not in a jobs view"))
    (oqa--jobs-reload group-id build args)))

(defun oqa-jobs-apply-filters (&optional args)
  "Reload the current jobs view applying transient filter ARGS.
Interactively ARGS comes from `oqa-jobs-transient' (the `-s'/`-r'/…
infixes)."
  (interactive (list (transient-args 'oqa-jobs-transient)))
  (oqa--jobs-reload-here args))

(defconst oqa--jobs-quick-filters
  '(("running"           . (("--state=" "running")))
    ("failed"            . (("--result=" "failed")))
    ("failed+softfailed" . (("--result=" "failed" "softfailed")))
    ("passed"            . (("--result=" "passed"))))
  "Named preset filter argument lists for the jobs quick filters.
Each value has the shape `transient-args' produces, so it flows through
`oqa--jobs-query' unchanged.")

(defun oqa-jobs-running ()
  "Reload the jobs view showing only running jobs."
  (interactive)
  (oqa--jobs-reload-here (cdr (assoc "running" oqa--jobs-quick-filters))))

(defun oqa-jobs-failed ()
  "Reload the jobs view showing only failed jobs."
  (interactive)
  (oqa--jobs-reload-here (cdr (assoc "failed" oqa--jobs-quick-filters))))

(defun oqa-jobs-failed-soft ()
  "Reload the jobs view showing failed and softfailed jobs."
  (interactive)
  (oqa--jobs-reload-here (cdr (assoc "failed+softfailed" oqa--jobs-quick-filters))))

(defun oqa-jobs-passed ()
  "Reload the jobs view showing only passed jobs."
  (interactive)
  (oqa--jobs-reload-here (cdr (assoc "passed" oqa--jobs-quick-filters))))

(defun oqa-jobs-clear-filters ()
  "Reload the jobs view with all filters cleared."
  (interactive)
  (oqa--jobs-reload-here nil))

;;;###autoload (autoload 'oqa-jobs-transient "oqa-jobs" nil t)
(transient-define-prefix oqa-jobs-transient ()
  "Filter the jobs view.
The quick presets reload the list immediately; the custom `-s'/`-r' and
single-value infixes accumulate and are applied with RET."
  :man-page nil
  ["Quick filter (reloads immediately)"
   ("R" "running"            oqa-jobs-running)
   ("F" "failed"             oqa-jobs-failed)
   ("S" "failed + softfailed" oqa-jobs-failed-soft)
   ("P" "passed"             oqa-jobs-passed)
   ("x" "clear filters"      oqa-jobs-clear-filters)]
  ["Custom filter"
   ["Multi-value"
    ("-s" "state" "--state="
     :multi-value t
     :choices ("scheduled" "assigned" "setup" "running" "uploading"
               "done" "cancelled"))
    ("-r" "result" "--result="
     :multi-value t
     :choices ("passed" "failed" "softfailed" "incomplete" "skipped"
               "timeout_exceeded" "parallel_failed" "obsoleted"
               "user_cancelled" "none"))]
   ["Single-value"
    ("-a" "arch" "--arch=")
    ("-f" "flavor" "--flavor=")
    ("-m" "machine" "--machine=")
    ("-t" "test (exact name)" "--test=")
    ("-d" "distri" "--distri=")
    ("-v" "version" "--version=")
    ("-n" "limit" "--limit=")]]
  ["Apply custom filter"
   ("RET" "reload with the args above" oqa-jobs-apply-filters)])

(provide 'oqa-jobs)
;;; oqa-jobs.el ends here
