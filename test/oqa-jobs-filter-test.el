;;; oqa-jobs-filter-test.el --- Tests for jobs filtering  -*- lexical-binding: t; -*-

;;; Commentary:

;; Filter arguments (as `transient-args' returns them) are turned into a
;; /api/v1/jobs query: single-value infixes become one pair, multi-value
;; state/result become repeated query params, and an explicit --limit=
;; overrides the default.  The empty-result state is distinct from a load
;; error.

;;; Code:

(require 'ert)
(require 'oqa-fixture)
(require 'oqa-jobs)

(ert-deftest oqa-jobs-filter-single-value-arg->query ()
  "A single-value transient arg becomes one query pair."
  (should (equal (oqa--args->query '("--result=failed"))
                 '(("result" . "failed")))))

(ert-deftest oqa-jobs-filter-multi-value-arg->query ()
  "A :multi-value arg (list form) collapses to a list-valued query pair."
  (should (equal (oqa--args->query '(("--state=" "running" "done")))
                 '(("state" "running" "done")))))

(ert-deftest oqa-jobs-filter-multi-value-repeats-in-query-string ()
  "Multi-value state/result render as repeated query parameters."
  (let ((qs (oqa--query-string
             (oqa--args->query '(("--state=" "running" "done")
                                 "--result=failed")))))
    (should (string-match-p "state=running" qs))
    (should (string-match-p "state=done" qs))
    (should (string-match-p "result=failed" qs))))

(ert-deftest oqa-jobs-filter-query-merges-base-filters-and-default-limit ()
  "`oqa--jobs-query' merges base params, filters, and the default limit."
  (let ((q (oqa--jobs-query 1 "20260731"
                            '(("--state=" "running") "--arch=x86_64"))))
    (should (equal (cdr (assoc "group_id" q)) 1))
    (should (equal (cdr (assoc "build" q)) "20260731"))
    (should (equal (cdr (assoc "state" q)) '("running")))
    (should (equal (cdr (assoc "arch" q)) "x86_64"))
    (should (equal (cdr (assoc "limit" q)) oqa-jobs-limit))
    (should (= oqa-jobs-limit 100))))

(ert-deftest oqa-jobs-filter-explicit-limit-overrides-default ()
  "An explicit --limit= filter suppresses the default limit (no duplicate)."
  (let ((q (oqa--jobs-query 1 "b" '("--limit=250"))))
    (should (equal (cdr (assoc "limit" q)) "250"))
    (should (= 1 (length (seq-filter (lambda (kv) (equal (car kv) "limit")) q))))))

(ert-deftest oqa-jobs-filter-empty-state-distinct-from-error ()
  "An empty jobs response yields no rows and is not an error, and the
filtered empty message differs from both the unfiltered one and an error."
  (let ((empty (let ((h (make-hash-table :test 'equal)))
                 (puthash "jobs" (vector) h) h)))
    (should (null (oqa--jobs-rows empty)))
    (should-not (oqa-error-p empty))
    (should-not (equal (oqa--jobs-empty-message '("--state=running"))
                       (oqa--jobs-empty-message nil)))
    (should (oqa-error-p (oqa--make-error :message "boom")))))

(ert-deftest oqa-jobs-filter-quick-preset-running->state ()
  "The `running' preset queries only state=running."
  (let ((q (oqa--jobs-query 1 "b" (cdr (assoc "running" oqa--jobs-quick-filters)))))
    (should (equal (cdr (assoc "state" q)) '("running")))
    (should-not (assoc "result" q))))

(ert-deftest oqa-jobs-filter-quick-preset-failed-soft-repeats ()
  "The `failed+softfailed' preset produces two repeated result params."
  (let ((qs (oqa--query-string
             (oqa--jobs-query 1 "b"
                              (cdr (assoc "failed+softfailed"
                                          oqa--jobs-quick-filters))))))
    (should (string-match-p "result=failed" qs))
    (should (string-match-p "result=softfailed" qs))))

(ert-deftest oqa-jobs-filter-clear-has-no-filters ()
  "Clearing filters leaves only the base params plus the default limit."
  (let ((q (oqa--jobs-query 1 "b" nil)))
    (should-not (assoc "state" q))
    (should-not (assoc "result" q))
    (should (equal (cdr (assoc "limit" q)) oqa-jobs-limit))))

(ert-deftest oqa-jobs-filter-header-shows-active-filters ()
  "The header line names the active filters, or says there are none."
  (should (string-match-p "no filters"
                          (oqa--jobs-header "20260731" nil)))
  (should (string-match-p "state=running"
                          (oqa--jobs-header "20260731" '(("--state=" "running"))))))

(ert-deftest oqa-jobs-filter-header-survives-init-header ()
  "The filter header line is not clobbered by `tabulated-list-init-header'."
  (with-temp-buffer
    (oqa-jobs-mode)
    (oqa--jobs-render 1 "20260731" (oqa-fixture "jobs.json")
                      '(("--state=" "running")))
    (should (stringp header-line-format))
    (should (string-match-p "state=running" header-line-format))))

(ert-deftest oqa-jobs-nav-keys-bound-in-buffer ()
  "Up navigation is bound directly in the shared list keymap (both `u'
and `^'), so navigating never requires opening the transient."
  (should (eq (lookup-key oqa-list-mode-map (kbd "u")) #'oqa-up))
  (should (eq (lookup-key oqa-list-mode-map (kbd "^")) #'oqa-up)))

(ert-deftest oqa-jobs-mode-menu-key-opens-filter-transient ()
  "In a live jobs buffer `o'/`?'/`f' open the filter transient, while
navigation keys stay inherited from `oqa-list-mode'."
  (with-temp-buffer
    (oqa-jobs-mode)
    (should (eq (key-binding (kbd "o")) #'oqa-jobs-transient))
    (should (eq (key-binding (kbd "f")) #'oqa-jobs-transient))
    ;; clearing filters works directly from the buffer
    (should (eq (key-binding (kbd "x")) #'oqa-jobs-clear-filters))
    ;; inherited navigation still resolves through the parent keymap
    (should (eq (key-binding (kbd "u")) #'oqa-up))
    (should (eq (key-binding (kbd "RET")) #'oqa-open))))

(provide 'oqa-jobs-filter-test)
;;; oqa-jobs-filter-test.el ends here
