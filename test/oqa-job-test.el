;;; oqa-job-test.el --- Tests for the single-job view  -*- lexical-binding: t; -*-

;;; Commentary:

;; Settings (sorted key/value) and module rows (from `testresults') of a
;; job details response, from a recorded fixture.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'oqa-fixture)
(require 'oqa-job)

(ert-deftest oqa-job-settings-rows-sorted-kv ()
  (let* ((job (oqa--job-unwrap (oqa-fixture "job.json")))
         (rows (oqa--job-settings-rows job)))
    (should (> (length rows) 0))
    (should (cl-every (lambda (kv) (and (stringp (car kv)) (stringp (cdr kv)))) rows))
    (should (equal rows (sort (copy-sequence rows)
                              (lambda (a b) (string< (car a) (car b))))))
    (should (assoc "DISTRI" rows))))

(ert-deftest oqa-job-module-rows-name-result ()
  (let* ((job (oqa--job-unwrap (oqa-fixture "job.json")))
         (rows (oqa--job-module-rows job)))
    (should (> (length rows) 0))
    (let ((mr (car rows)))
      (should (stringp (car mr)))
      (should (stringp (cdr mr))))))

(ert-deftest oqa-job-unwrap-handles-envelope ()
  (let ((data (oqa-fixture "job.json")))
    ;; fixture is a {"job": {...}} envelope
    (should (gethash "settings" (oqa--job-unwrap data)))))

(provide 'oqa-job-test)
;;; oqa-job-test.el ends here
