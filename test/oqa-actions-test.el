;;; oqa-actions-test.el --- Tests for job actions  -*- lexical-binding: t; -*-

;;; Commentary:

;; Argument construction for the external CLIs (openqa-cli /
;; openqa-clone-job) and the `executable-find' guard: an absent CLI must
;; block the action and submit nothing.

;;; Code:

(require 'ert)
(require 'oqa-actions)

(ert-deftest oqa-actions-restart-args ()
  "Restart posts to jobs/<id>/restart on the active host."
  (should (equal (oqa--restart-args "https://o3" 42)
                 '("api" "--host" "https://o3" "-X" "POST" "jobs/42/restart"))))

(ert-deftest oqa-actions-clone-args ()
  "Clone targets --host and the job URL, then appends KEY=value overrides."
  (should (equal (oqa--clone-args "https://o3" 42 '("FOO=1" "BAR=2"))
                 '("--host" "https://o3" "https://o3/tests/42" "FOO=1" "BAR=2"))))

(ert-deftest oqa-actions-iso-args ()
  "Trigger posts to isos with DISTRI/VERSION/FLAVOR/ARCH/BUILD params."
  (should (equal (oqa--iso-args "https://o3"
                                '(("DISTRI" . "opensuse")
                                  ("VERSION" . "Tumbleweed")
                                  ("FLAVOR" . "DVD")
                                  ("ARCH" . "x86_64")
                                  ("BUILD" . "20260731")))
                 '("api" "--host" "https://o3" "-X" "POST" "isos"
                   "DISTRI=opensuse" "VERSION=Tumbleweed" "FLAVOR=DVD"
                   "ARCH=x86_64" "BUILD=20260731"))))

(ert-deftest oqa-actions-require-cli-present-returns-program ()
  "When the CLI resolves, `oqa--require-cli' returns the program name."
  (cl-letf (((symbol-function 'executable-find)
             (lambda (p &rest _) (concat "/usr/bin/" p))))
    (should (equal (oqa--require-cli "openqa-cli") "openqa-cli"))))

(ert-deftest oqa-actions-require-cli-absent-signals ()
  "When the CLI is missing, `oqa--require-cli' signals a `user-error'."
  (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil)))
    (should-error (oqa--require-cli "openqa-cli") :type 'user-error)))

(ert-deftest oqa-actions-missing-cli-submits-nothing ()
  "A restart with no CLI installed errors and runs no external process."
  (let ((ran nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
              ((symbol-function 'oqa--run-cli-report)
               (lambda (&rest _) (setq ran t)))
              ((symbol-function 'oqa--job-id-at-point) (lambda () 42))
              ((symbol-function 'oqa--host) (lambda (&rest _) "https://o3"))
              ((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
      (should-error (oqa-restart-job) :type 'user-error)
      (should-not ran))))

(ert-deftest oqa-actions-restart-confirmed-invokes-cli ()
  "A confirmed restart runs the CLI with the restart arguments."
  (let (captured)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (p &rest _) (concat "/usr/bin/" p)))
              ((symbol-function 'oqa--job-id-at-point) (lambda () 42))
              ((symbol-function 'oqa--host) (lambda (&rest _) "https://o3"))
              ((symbol-function 'y-or-n-p) (lambda (&rest _) t))
              ((symbol-function 'oqa--run-cli-report)
               (lambda (program args _desc) (setq captured (cons program args)))))
      (oqa-restart-job)
      (should (equal captured
                     (cons oqa-cli-program
                           '("api" "--host" "https://o3" "-X" "POST"
                             "jobs/42/restart")))))))

(ert-deftest oqa-actions-restart-declined-submits-nothing ()
  "Declining the confirmation prompt runs no external process."
  (let ((ran nil))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (p &rest _) (concat "/usr/bin/" p)))
              ((symbol-function 'oqa--job-id-at-point) (lambda () 42))
              ((symbol-function 'oqa--host) (lambda (&rest _) "https://o3"))
              ((symbol-function 'y-or-n-p) (lambda (&rest _) nil))
              ((symbol-function 'oqa--run-cli-report)
               (lambda (&rest _) (setq ran t))))
      (oqa-restart-job)
      (should-not ran))))

(provide 'oqa-actions-test)
;;; oqa-actions-test.el ends here
