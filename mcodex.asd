;;;; metacircular-codex is the top-level build for my documentation
;;;; site.

(asdf:defsystem #:mcodex
  :description "top-level documentation index for my projects."
  :author "K. Isom <kyle@metacircular.net>"
  :license "MIT license"
  :depends-on (#:codex)
  :components ((:file "package")
	       (:file "mcodex")))
