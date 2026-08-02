;;; oqa-groups-test.el --- Tests for the groups view  -*- lexical-binding: t; -*-

;;; Commentary:

;; Row building and parent-group resolution from recorded fixtures.

;;; Code:

(require 'ert)
(require 'seq)
(require 'oqa-fixture)
(require 'oqa-groups)

(ert-deftest oqa-groups-rows-basic ()
  (let* ((groups (oqa-fixture "job_groups.json"))
         (parents (oqa--parents-table (oqa-fixture "parent_groups.json")))
         (rows (oqa--groups-rows groups parents)))
    (should (> (length rows) 0))
    (should (= (length rows) (length groups)))
    (let ((row (car rows)))
      (should (integerp (car row)))
      (should (= 2 (length (cadr row)))))))

(ert-deftest oqa-groups-parent-name-resolved ()
  "A group with a parent_id shows the parent group name, not a bare number."
  (let* ((groups (oqa-fixture "job_groups.json"))
         (parents (oqa--parents-table (oqa-fixture "parent_groups.json")))
         (rows (oqa--groups-rows groups parents))
         (with-parent (seq-find (lambda (g) (gethash "parent_id" g))
                                (append groups nil))))
    (should with-parent)
    (let* ((id (gethash "id" with-parent))
           (row (assoc id rows))
           (parent-col (aref (cadr row) 1)))
      (should (> (length parent-col) 0))
      (should-not (string-match-p "\\`[0-9]+\\'" parent-col)))))

(provide 'oqa-groups-test)
;;; oqa-groups-test.el ends here
