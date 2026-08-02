;;; oqa-log-test.el --- Tests for log viewing  -*- lexical-binding: t; -*-

;;; Commentary:

;; The text-fetch path and log classification: a 200 yields the body, a
;; 404 yields an "unavailable" result (not a hard error), the log buffer
;; is read-only, and a worker with no log endpoint degrades to a status
;; message.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'oqa-fixture)
(require 'oqa-api)
(require 'oqa-log)
(require 'oqa-workers)

(ert-deftest oqa-log-outcome-classifies-ok-unavailable-error ()
  "String is ok, a 404 error is unavailable, anything else is error."
  (should (eq (oqa--log-outcome "text") 'ok))
  (should (eq (oqa--log-outcome (oqa--make-error :message "nf" :status 404))
             'unavailable))
  (should (eq (oqa--log-outcome (oqa--make-error :message "boom" :status 500))
             'error))
  (should (eq (oqa--log-outcome (oqa--make-error :message "unreachable"))
             'error)))

(ert-deftest oqa-log-buffer-read-only-holds-text ()
  "A log buffer is read-only, in `oqa-log-mode', and holds the text."
  (let ((buf (oqa--log-buffer "job 1" "hello\nworld\n")))
    (unwind-protect
        (with-current-buffer buf
          (should buffer-read-only)
          (should (derived-mode-p 'special-mode))
          (should (string-match-p "world" (buffer-string))))
      (kill-buffer buf))))

(ert-deftest oqa-log-job-fixture-renders ()
  "The recorded autoinst-log fixture renders into a log buffer."
  (let* ((text (with-temp-buffer
                 (insert-file-contents
                  (expand-file-name "autoinst-log.txt" oqa-fixture-dir))
                 (buffer-string)))
         (buf (oqa--log-buffer "job 42" text)))
    (unwind-protect
        (with-current-buffer buf
          (should (> (length (buffer-string)) 0))
          (should (equal (buffer-string) text)))
      (kill-buffer buf))))

(ert-deftest oqa-api-get-text-200-returns-body ()
  "A 200 text response returns exactly the body, without the headers."
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((b (generate-new-buffer " *oqa-fake*")))
                 (with-current-buffer b
                   (setq-local url-http-response-status 200)
                   (insert "HTTP/1.1 200 OK\n\nplain log body\nline2"))
                 b))))
    (should (equal (oqa--api-get-text "/x") "plain log body\nline2"))))

(ert-deftest oqa-api-get-text-404-is-unavailable ()
  "A 404 text response is an `oqa-error' with status 404 → unavailable."
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((b (generate-new-buffer " *oqa-fake*")))
                 (with-current-buffer b
                   (setq-local url-http-response-status 404)
                   (insert "HTTP/1.1 404 Not Found\n\nnope"))
                 b))))
    (let ((res (oqa--api-get-text "/x")))
      (should (oqa-error-p res))
      (should (eql (oqa-error-status res) 404))
      (should (eq (oqa--log-outcome res) 'unavailable)))))

(ert-deftest oqa-worker-log-text-is-degraded ()
  "A worker with no log endpoint degrades to its status and a clear note."
  (let ((w (make-hash-table :test 'equal)))
    (puthash "host" "midas" w)
    (puthash "instance" 8081 w)
    (puthash "status" "dead" w)
    (let ((txt (oqa--worker-log-text w)))
      (should (string-match-p "midas:8081" txt))
      (should (string-match-p "dead" txt))
      (should (string-match-p "No worker-log endpoint" txt)))))

(provide 'oqa-log-test)
;;; oqa-log-test.el ends here
