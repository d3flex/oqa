;;; oqa-workers-test.el --- Tests for the workers view  -*- lexical-binding: t; -*-

;;; Commentary:

;; Worker rows (host:instance identity, status, WORKER_CLASS) and the
;; per-worker property rows, from a recorded workers fixture.

;;; Code:

(require 'ert)
(require 'oqa-fixture)
(require 'oqa-workers)

(ert-deftest oqa-workers-rows-identity-status-class ()
  "Rows carry host:instance, status, and WORKER_CLASS, keyed by worker id."
  (let* ((data (oqa-fixture "workers.json"))
         (rows (oqa--workers-rows data))
         (workers (append (gethash "workers" data) nil)))
    (should (> (length rows) 0))
    (should (= (length rows) (length workers)))
    (let* ((w (car workers))
           (row (car rows))
           (id (car row))
           (cols (cadr row)))
      (should (equal id (gethash "id" w)))
      (should (= 3 (length cols)))
      (should (equal (substring-no-properties (aref cols 0))
                     (format "%s:%s" (gethash "host" w) (gethash "instance" w))))
      (should (equal (aref cols 2)
                     (format "%s" (gethash "WORKER_CLASS"
                                           (gethash "properties" w))))))))

(ert-deftest oqa-workers-status-column-keeps-text ()
  "The Status column shows the worker status (colouring aside)."
  (let* ((data (oqa-fixture "workers.json"))
         (w (car (append (gethash "workers" data) nil)))
         (cols (cadr (car (oqa--workers-rows data)))))
    (should (equal (substring-no-properties (aref cols 1))
                   (format "%s" (gethash "status" w))))))

(ert-deftest oqa-workers-property-rows-sorted-kv ()
  "A worker's properties render as name-sorted key = value rows."
  (let* ((data (oqa-fixture "workers.json"))
         (w (car (append (gethash "workers" data) nil)))
         (rows (oqa--worker-property-rows w)))
    (should (> (length rows) 0))
    (should (equal rows
                   (sort (copy-sequence rows)
                         (lambda (a b) (string< (car a) (car b))))))
    (should (assoc "WORKER_CLASS" rows))))

(ert-deftest oqa-workers-identity-helper ()
  "`oqa--worker-identity' joins host and instance with a colon."
  (let ((w (make-hash-table :test 'equal)))
    (puthash "host" "worker1" w)
    (puthash "instance" 3 w)
    (should (equal (oqa--worker-identity w) "worker1:3"))))

(ert-deftest oqa-worker-detail-header-survives-init-header ()
  "The worker identity/status header line is not clobbered by
`tabulated-list-init-header', and the properties render as rows."
  (with-temp-buffer
    (oqa-list-mode)
    (let ((w (car (append (gethash "workers" (oqa-fixture "workers.json")) nil))))
      (oqa--worker-detail-render (gethash "id" w) w)
      (should (stringp header-line-format))
      (should (string-match-p (regexp-quote (oqa--worker-identity w))
                              header-line-format))
      (should (> (length tabulated-list-entries) 0)))))

(provide 'oqa-workers-test)
;;; oqa-workers-test.el ends here
