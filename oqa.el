;;; oqa.el --- OpenQA client for Emacs  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Ioannis Bonatakis

;; Author: Ioannis Bonatakis <ybonatakis@suse.com>
;; Keywords: tools

;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (transient "0.3.0") (dash "2.19.1") (s "1.12.0"))
;; URL: https://github.com/b10n1k/oqa

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

;; oqa is a Magit-style OpenQA client: a drill-down stack of read-only
;; list buffers (groups -> builds -> jobs -> job) with a transient
;; command menu (`o' or `?').  `M-x oqa' opens the job-groups view of the
;; active instance (o3 by default; see `oqa-instances').

;;; Code:

(require 'oqa-instance)
(require 'oqa-api)
(require 'oqa-list)
(require 'oqa-actions)
(require 'oqa-job)
(require 'oqa-jobs)
(require 'oqa-builds)
(require 'oqa-groups)
(require 'oqa-transient)

;;;###autoload
(defun oqa ()
  "Open the OpenQA client at the job-groups view of the active instance."
  (interactive)
  (oqa-groups))

(provide 'oqa)
;;; oqa.el ends here
