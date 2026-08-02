;;; oqa-transient.el --- Transient dispatch for oqa  -*- lexical-binding: t; -*-

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

;; The context command menu, reachable with `o' or `?' from any view.
;; For this browse milestone it exposes navigation only; filtering,
;; job actions, instance switching, workers and logs attach here as
;; later stories land.

;;; Code:

(require 'transient)
(require 'oqa-list)
(require 'oqa-groups)

;;;###autoload (autoload 'oqa-dispatch "oqa-transient" nil t)
(transient-define-prefix oqa-dispatch ()
  "Navigation dispatch shared by every oqa view.
These are also bound directly in the buffer (`u'/`^', RET, `g'), so
this menu is just a discoverable overview.  The jobs view has its own
`oqa-jobs-transient' (filters) on `o'/`?'/`f' instead of this one."
  ["Navigate"
   ("j" "open item at point (drill down)" oqa-open)
   ("u" "up / back" oqa-up)
   ("g" "refresh view" oqa-refresh)
   ("H" "groups (home)" oqa-groups)])

(provide 'oqa-transient)
;;; oqa-transient.el ends here
