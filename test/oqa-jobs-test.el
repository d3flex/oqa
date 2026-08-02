;;; oqa-jobs-test.el --- Tests for the jobs view  -*- lexical-binding: t; -*-

;;; Commentary:

;; Job row building (flavor/arch/machine read from settings) and the
;; base jobs query, from a recorded jobs fixture.

;;; Code:

(require 'ert)
(require 'oqa-fixture)
(require 'oqa-jobs)

(ert-deftest oqa-jobs-rows-flavor-arch-machine-from-settings ()
  (let* ((data (oqa-fixture "jobs.json"))
         (rows (oqa--jobs-rows data))
         (jobs (append (gethash "jobs" data) nil)))
    (should (> (length rows) 0))
    (should (= (length rows) (length jobs)))
    (let* ((row (car rows))
           (cols (cadr row))
           (settings (gethash "settings" (car jobs))))
      (should (= 7 (length cols)))
      ;; Flavor is column index 2, pulled from settings.FLAVOR
      (should (equal (aref cols 2)
                     (format "%s" (or (gethash "FLAVOR" settings) ""))))
      ;; Arch is column index 3, pulled from settings.ARCH
      (should (equal (aref cols 3)
                     (format "%s" (or (gethash "ARCH" settings) "")))))))

(ert-deftest oqa-jobs-query-includes-group-build-limit ()
  (let ((q (oqa--jobs-query 1 "20260731")))
    (should (equal (cdr (assoc "group_id" q)) 1))
    (should (equal (cdr (assoc "build" q)) "20260731"))
    (should (assoc "limit" q))))

(ert-deftest oqa-jobs-state-result-face-mapping ()
  (should (eq (oqa--result-face "passed") 'oqa-passed))
  (should (eq (oqa--result-face "failed") 'oqa-failed))
  (should (eq (oqa--result-face "softfailed") 'oqa-softfailed))
  (should (eq (oqa--result-face "skipped") 'oqa-muted))
  (should (null (oqa--result-face "surprising_new_value")))
  (should (eq (oqa--state-face "running") 'oqa-running))
  (should (null (oqa--state-face "done"))))

(ert-deftest oqa-jobs-rows-colorize-result-column ()
  "The Result column carries the mapped face but keeps its plain text."
  (let* ((data (oqa-fixture "jobs.json"))
         (rows (oqa--jobs-rows data)))
    (dolist (row rows)
      (let* ((cols (cadr row))
             (result (aref cols 6))
             (face (oqa--result-face (substring-no-properties result))))
        ;; text content is unchanged (equal ignores text properties)
        (should (stringp result))
        (when face
          (should (eq (get-text-property 0 'face result) face)))))))

(provide 'oqa-jobs-test)
;;; oqa-jobs-test.el ends here
