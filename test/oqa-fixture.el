;;; oqa-fixture.el --- Fixture loader for oqa tests  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loads recorded OpenQA JSON fixtures, parsed exactly the way
;; `oqa--api-get' parses live responses, so pure row-builders can be
;; tested with no network.

;;; Code:

(defvar oqa-fixture-dir
  (expand-file-name "fixtures/"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Directory holding recorded JSON fixtures.")

(defun oqa-fixture (name)
  "Parse fixture NAME into hash-tables/vectors like `oqa--api-get' returns."
  (with-temp-buffer
    (insert-file-contents (expand-file-name name oqa-fixture-dir))
    (goto-char (point-min))
    (json-parse-buffer :object-type 'hash-table
                       :array-type 'array
                       :null-object nil
                       :false-object nil)))

(provide 'oqa-fixture)
;;; oqa-fixture.el ends here
