;;;; package.lisp

(defpackage #:mcodex
  (:use #:cl)
  (:export #:rsync
	   #:doc-path
           #:build-site
           #:deploy-site
           #:publish-site
           #:mcodex-path
           #:build-and-publish)
  (:documentation
   "The MCODEX package provides tools for building and deploying documentation using
    the Codex documentation system and rsync for file synchronization.

    Overview:
    This package facilitates generating documentation for Lisp systems (via `build-site`)
    and deploying it to a remote server (via `rsync`, `deploy-site`, `publish-site`, or
    `build-and-publish`). It supports package-specific deployment paths (via `mcodex-path`)
    and allows clients to customize paths, hosts, and packages through function arguments.
    The default configuration targets a remote server at web.metacircular.net, with
    documentation stored under /srv/www/codex/.

    Key Functions:
    - `build-site`: Generates documentation for a specified package using Codex.
    - `rsync`: Synchronizes a local directory to a remote destination.
    - `deploy-site`: Deploys a directory to a remote server, wrapping `rsync`.
    - `publish-site`: Builds documentation and deploys it in one step.
    - `mcodex-path`: Constructs package-specific remote paths (e.g., /srv/www/codex/test/).
    - `build-and-publish`: High-level function to build and deploy with package-specific paths.

    Usage Example:
      (ql:quickload :mcodex)
      (mcodex:build-and-publish)        ; Build and deploy for current package
      (mcodex:publish-site :package \"test\" :path \"my/docs/\") ; Custom build and deploy

    Dependencies:
    - Common Lisp (CL)
    - UIOP (for running rsync)
    - Codex (for generating documentation)

    Notes:
    - Requires rsync installed and SSH access configured for the remote server.
    - Assumes Codex is set up to output documentation to a directory like
      docs/build/mcodex/html/.
    - All functions allow parameter overrides for flexibility."))
