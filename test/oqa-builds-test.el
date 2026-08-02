;;; oqa-builds-test.el --- Tests for the builds view  -*- lexical-binding: t; -*-

;;; Commentary:

;; Build-overview row building from a recorded group_overview fixture.

;;; Code:

(require 'ert)
(require 'oqa-fixture)
(require 'oqa-builds)

(ert-deftest oqa-builds-rows-shape ()
  (let* ((data (oqa-fixture "group_overview.json"))
         (rows (oqa--builds-rows 1 data)))
    (should (> (length rows) 0))
    (let* ((row (car rows))
           (id (car row))
           (cols (cadr row)))
      (should (eq (plist-get id :group-id) 1))
      (should (stringp (plist-get id :build)))
      (should (= 7 (length cols)))
      ;; count columns render as integer strings
      (dolist (i '(2 3 4 5 6))
        (should (string-match-p "\\`[0-9]+\\'" (aref cols i)))))))

(provide 'oqa-builds-test)
;;; oqa-builds-test.el ends here
