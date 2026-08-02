;;; oqa-nav-test.el --- Tests for the navigation stack  -*- lexical-binding: t; -*-

;;; Commentary:

;; Buffer-local navigation context: `oqa--open-view' wires the parent
;; and active instance, and `oqa-open' drills the entry at point.

;;; Code:

(require 'ert)
(require 'oqa-list)

(ert-deftest oqa-nav-open-view-sets-context ()
  (let ((parent (get-buffer-create "*oqa-test-parent*")))
    (unwind-protect
        (let ((buf (oqa--open-view
                    "*oqa-test-child*" parent "osd"
                    (lambda ()
                      (setq oqa--open-fn #'ignore)
                      (setq tabulated-list-format [("X" 3 t)])
                      (setq tabulated-list-entries nil)
                      (tabulated-list-init-header)))))
          (with-current-buffer buf
            (should (eq oqa--parent-buffer parent))
            (should (equal oqa--instance "osd"))
            (should (eq major-mode 'oqa-list-mode))
            (should buffer-read-only)))
      (when (get-buffer "*oqa-test-child*") (kill-buffer "*oqa-test-child*"))
      (kill-buffer parent))))

(ert-deftest oqa-nav-open-invokes-open-fn-with-id-at-point ()
  (with-temp-buffer
    (oqa-list-mode)
    (let ((captured 'none))
      (setq oqa--open-fn (lambda (id) (setq captured id)))
      (setq tabulated-list-format [("X" 6 t)])
      (setq tabulated-list-entries (list (list 42 (vector "row"))))
      (tabulated-list-init-header)
      (tabulated-list-print)
      (goto-char (point-min))
      (oqa-open)
      (should (equal captured 42)))))

(ert-deftest oqa-nav-open-without-target-errors ()
  (with-temp-buffer
    (oqa-list-mode)
    (setq oqa--open-fn nil)
    (should-error (oqa-open) :type 'user-error)))

(provide 'oqa-nav-test)
;;; oqa-nav-test.el ends here
