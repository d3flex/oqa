;;; oqa-api-error-test.el --- Tests for the fetch layer  -*- lexical-binding: t; -*-

;;; Commentary:

;; URL/query building and the structured-error contract of `oqa--api-get'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'oqa-api)

(ert-deftest oqa-api-query-string-multi-value ()
  "List-valued keys are emitted as repeated parameters."
  (should (equal (oqa--query-string '(("a" . "1") ("b" "x" "y")))
                 "a=1&b=x&b=y")))

(ert-deftest oqa-api-url-builds-with-host ()
  (let ((oqa-instances '(("o3" . "https://example.org")))
        (oqa-default-instance "o3"))
    (should (equal (oqa--url "/api/v1/job_groups")
                   "https://example.org/api/v1/job_groups"))
    (should (equal (oqa--url "/x" '(("q" . "a b")))
                   "https://example.org/x?q=a%20b"))))

(ert-deftest oqa-api-get-no-response-is-error ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _) nil)))
    (let ((res (oqa--api-get "/x")))
      (should (oqa-error-p res))
      (should (string-match-p "no response" (oqa-error-message res))))))

(ert-deftest oqa-api-get-non-200-is-error ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((b (generate-new-buffer " *oqa-fake*")))
                 (with-current-buffer b
                   (setq-local url-http-response-status 404)
                   (insert "HTTP/1.1 404 Not Found\n\nnope"))
                 b))))
    (let ((res (oqa--api-get "/x")))
      (should (oqa-error-p res))
      (should (string-match-p "404" (oqa-error-message res))))))

(ert-deftest oqa-api-get-bad-json-is-error ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((b (generate-new-buffer " *oqa-fake*")))
                 (with-current-buffer b
                   (setq-local url-http-response-status 200)
                   (insert "HTTP/1.1 200 OK\n\nnot json{{"))
                 b))))
    (let ((res (oqa--api-get "/x")))
      (should (oqa-error-p res))
      (should (string-match-p "JSON" (oqa-error-message res))))))

(ert-deftest oqa-api-render-error ()
  (should (equal (oqa--render-error (oqa--make-error :message "boom"))
                 "oqa: boom")))

(provide 'oqa-api-error-test)
;;; oqa-api-error-test.el ends here
