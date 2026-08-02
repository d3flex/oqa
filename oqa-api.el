;;; oqa-api.el --- OpenQA REST access for oqa  -*- lexical-binding: t; -*-

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

;; The single read path to an OpenQA instance.  Every GET goes through
;; `oqa--api-get', which returns parsed JSON (hash-tables/vectors) on
;; success or an `oqa-error' struct on any failure (unreachable host,
;; non-2xx, timeout, unparseable body).  Views test the result with
;; `oqa-error-p' and display `oqa--render-error' rather than raising a
;; raw Lisp error, so a failed fetch leaves the previous view intact.

;;; Code:

(require 'cl-lib)
(require 'url)
(require 'oqa-instance)

(defcustom oqa-request-timeout 30
  "Seconds to wait for an OpenQA HTTP response before giving up."
  :type 'integer
  :group 'oqa)

(cl-defstruct (oqa-error (:constructor oqa--make-error))
  "A structured failure returned by `oqa--api-get'."
  message)

(defun oqa--render-error (err)
  "Return a human-readable one-line message for ERR, an `oqa-error'."
  (format "oqa: %s" (oqa-error-message err)))

(defun oqa--query-string (query)
  "Encode QUERY, an alist, into a URL query string.
A value may be a list, in which case its key is repeated once per
element (for multi-value OpenQA parameters such as state and result)."
  (mapconcat
   (lambda (kv)
     (let ((k (car kv))
           (vals (if (listp (cdr kv)) (cdr kv) (list (cdr kv)))))
       (mapconcat
        (lambda (v)
          (concat (url-hexify-string (format "%s" k))
                  "="
                  (url-hexify-string (format "%s" v))))
        vals "&")))
   query "&"))

(defun oqa--url (path &optional query)
  "Build the full URL for PATH on the active instance, with optional QUERY."
  (concat (oqa--host) path
          (when query (concat "?" (oqa--query-string query)))))

(defun oqa--parse-json ()
  "Parse a JSON body from point to end of the current buffer."
  (json-parse-buffer :object-type 'hash-table
                     :array-type 'array
                     :null-object nil
                     :false-object nil))

(defun oqa--api-get (path &optional query)
  "GET PATH (with optional QUERY alist) from the active instance.
Return parsed JSON on success or an `oqa-error' on any failure."
  (let ((url (oqa--url path query)))
    (condition-case err
        (let ((buf (url-retrieve-synchronously url t t oqa-request-timeout)))
          (if (not buf)
              (oqa--make-error :message (format "no response from %s" url))
            (unwind-protect
                (with-current-buffer buf
                  (let ((status (bound-and-true-p url-http-response-status)))
                    (goto-char (point-min))
                    (cond
                     ((null status)
                      (oqa--make-error :message (format "no HTTP status from %s" url)))
                     ((not (<= 200 status 299))
                      (oqa--make-error :message (format "HTTP %s from %s" status url)))
                     ((not (re-search-forward "^$" nil t))
                      (oqa--make-error :message (format "malformed response from %s" url)))
                     (t
                      (condition-case perr
                          (oqa--parse-json)
                        (error (oqa--make-error
                                :message (format "bad JSON from %s: %s"
                                                 url (error-message-string perr)))))))))
              (kill-buffer buf))))
      (error (oqa--make-error
              :message (format "request to %s failed: %s"
                               url (error-message-string err)))))))

(provide 'oqa-api)
;;; oqa-api.el ends here
