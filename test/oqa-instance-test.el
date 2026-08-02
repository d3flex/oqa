;;; oqa-instance-test.el --- Tests for instance selection  -*- lexical-binding: t; -*-

;;; Commentary:

;; The active instance defaults to o3, a buffer-local or override change
;; is reflected in the host `oqa--url' targets, and switching opens the
;; groups view against the chosen instance.

;;; Code:

(require 'ert)
(require 'oqa-api)
(require 'oqa-instance)

(ert-deftest oqa-instance-default-is-o3 ()
  "With no configuration the active instance is o3."
  (with-temp-buffer
    (should (equal (oqa--instance) "o3"))
    (should (equal (oqa--host) "https://openqa.opensuse.org"))))

(ert-deftest oqa-instance-override-changes-host ()
  "The dynamic override selects the host `oqa--url' builds against."
  (with-temp-buffer
    (let ((oqa--instance-override "osd"))
      (should (equal (oqa--instance) "osd"))
      (should (string-prefix-p "https://openqa.suse.de"
                               (oqa--url "/api/v1/job_groups"))))
    ;; outside the override we are back to the default host
    (should (string-prefix-p "https://openqa.opensuse.org" (oqa--url "/x")))))

(ert-deftest oqa-instance-buffer-local-active ()
  "A buffer-local active instance selects that buffer's host."
  (with-temp-buffer
    (setq oqa--instance "osd")
    (should (equal (oqa--host) "https://openqa.suse.de"))))

(ert-deftest oqa-instance-switch-opens-groups-with-label ()
  "`oqa-switch-instance' opens the groups view against the chosen label."
  (let (captured)
    (cl-letf (((symbol-function 'oqa-groups)
               (lambda (&optional label) (setq captured label))))
      (oqa-switch-instance "osd")
      (should (equal captured "osd")))))

(ert-deftest oqa-instance-switch-unknown-errors ()
  "Switching to an instance absent from `oqa-instances' signals an error."
  (should-error (oqa-switch-instance "nope") :type 'user-error))

(ert-deftest oqa-instance-use-shortcuts ()
  "`oqa-use-o3'/`oqa-use-osd' switch to their respective instances."
  (let (captured)
    (cl-letf (((symbol-function 'oqa-groups)
               (lambda (&optional label) (setq captured label))))
      (oqa-use-osd)
      (should (equal captured "osd"))
      (oqa-use-o3)
      (should (equal captured "o3")))))

(provide 'oqa-instance-test)
;;; oqa-instance-test.el ends here
