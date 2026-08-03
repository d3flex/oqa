;;; oqa-instance.el --- OpenQA instance configuration  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Ioannis Bonatakis

;; Author: Ioannis Bonatakis <ybonatakis@suse.com>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Configuration of OpenQA instances and resolution of the active
;; instance's host.  Credentials are never stored here; they live in the
;; user's ~/.config/openqa/client.conf and are used only by the external
;; command-line tools invoked for state-changing actions.

;;; Code:

(defgroup oqa nil
  "OpenQA client for Emacs."
  :group 'tools
  :prefix "oqa-"
  :link '(url-link "https://github.com/d3flex/oqa"))

(defcustom oqa-instances
  '(("o3" . "https://openqa.opensuse.org")
    ("osd" . "https://openqa.suse.de"))
  "Alist mapping an instance label to its base URL."
  :type '(alist :key-type string :value-type string)
  :group 'oqa)

(defcustom oqa-default-instance "o3"
  "Label of the instance used when a buffer has no active instance."
  :type 'string
  :group 'oqa)

(defvar-local oqa--instance nil
  "Active instance label for the current oqa buffer.")

(defvar oqa--instance-override nil
  "When non-nil, the instance label to use regardless of buffer-local state.
Let-bound while fetching for a view that does not exist yet — e.g. an
instance switch, where the fetch must target the chosen host before its
buffer (and its buffer-local `oqa--instance') exists.")

(defun oqa--instance ()
  "Return the active instance label.
Prefers the dynamic `oqa--instance-override', then the buffer-local
`oqa--instance', then `oqa-default-instance'."
  (or oqa--instance-override oqa--instance oqa-default-instance))

(defun oqa--host (&optional label)
  "Return the base URL for instance LABEL, or the active instance."
  (let ((label (or label (oqa--instance))))
    (or (cdr (assoc label oqa-instances))
        (error "Unknown instance %S (see `oqa-instances')" label))))

;; `oqa-groups' is the entry view (oqa-groups.el).  It requires oqa-api,
;; which requires this file, so we cannot require it back; declare it to
;; keep the byte-compiler quiet — it is loaded by the time a user switches.
(declare-function oqa-groups "oqa-groups")

;;;###autoload
(defun oqa-switch-instance (label)
  "Switch the active OpenQA instance to LABEL and open its groups view.
LABEL must be a key of `oqa-instances'.  Interactively it is chosen with
completion, defaulting to the current instance."
  (interactive
   (list (completing-read "OpenQA instance: "
                          (mapcar #'car oqa-instances) nil t
                          nil nil (oqa--instance))))
  (unless (assoc label oqa-instances)
    (user-error "Unknown instance %S (see `oqa-instances')" label))
  (oqa-groups label))

;;;###autoload
(defun oqa-use-o3 ()
  "Switch the active instance to o3 (openqa.opensuse.org)."
  (interactive)
  (oqa-switch-instance "o3"))

;;;###autoload
(defun oqa-use-osd ()
  "Switch the active instance to osd (openqa.suse.de)."
  (interactive)
  (oqa-switch-instance "osd"))

(provide 'oqa-instance)
;;; oqa-instance.el ends here
