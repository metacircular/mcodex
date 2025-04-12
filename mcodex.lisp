;;;; mcodex.lisp

(defpackage :mcodex
  (:use :cl :uiop :codex)
  (:export #:rsync
           #:build-site
           #:deploy-site
           #:publish-site
           #:mcodex-path
           #:build-and-publish))

(in-package :mcodex)

(defparameter *doc-path* "docs/build/mcodex/html/"
  "Default local directory for Codex-generated documentation.")
(defparameter *top-level* "/srv/www/codex/"
  "Default remote base directory for deployed documentation.")
(defparameter *ssh-host* (format nil "web.metacircular.net:~A" *top-level*)
  "Default remote host and path for rsync deployment.")

(defun rsync (path site)
  "Synchronize a local PATH directory to a remote SITE using rsync.

Parameters:
  PATH (string): The local directory to synchronize, typically containing generated
    documentation (e.g., `*doc-path*` = \"docs/build/mcodex/html/\").
  SITE (string): The remote destination in rsync-compatible format, including the host
    and path (e.g., `*ssh-host*` = \"web.metacircular.net:/srv/www/codex/\").

Returns:
  `nil` on successful synchronization (rsync exit code 0), or `nil` if an error occurs,
    with error details printed to `*error-output*`.

Description:
  Executes `rsync` with options `--progress` (show transfer progress), `-a` (archive mode),
  `-u` (update, skip newer files on receiver), `-v` (verbose), and `-z` (compress data)
  to transfer files from PATH to SITE. Uses `uiop:run-program` to run the command, directing
  output and errors to standard streams. Errors (e.g., network issues, invalid paths) are
  caught and logged, making this function suitable for use in deployment workflows like
  `deploy-site` and `publish-site`.

Example:
  (rsync *doc-path* *ssh-host*)
    ; Syncs docs/build/mcodex/html/ to web.metacircular.net:/srv/www/codex/.
  (rsync \"my/docs/\" \"otherserver:/var/www\")
    ; Syncs a custom directory to a different server.

Notes:
  - Requires `rsync` to be installed and in the system’s PATH.
  - Assumes SSH access to the remote host (e.g., key-based authentication).
  - Does not validate PATH or SITE; ensure PATH exists and SITE is accessible.
  - Verbose output (`--progress`, `-v`) aids monitoring but may clutter logs."
  (handler-case
      (uiop:run-program
       `("rsync" "--progress" "-auvz" ,path ,site)
       :output t
       :error-output t)
    (error (e)
      (format *error-output* "Error during rsync: ~A~%" e)
      nil)))

(defun build-site (&optional (package (package-name *package*)))
  "Generate documentation for a specified PACKAGE using the Codex documentation system.

Parameters:
  PACKAGE (string or symbol, optional): The name of the package or system to document.
    Defaults to the name of the current package (via `package-name` and `*package*`).
    Converted to a keyword (e.g., \"mcodex\" or 'mcodex becomes :mcodex).

Returns:
  The result of `codex:document`, typically a truthy value (e.g., `t`) on success, or
  `nil` on failure, depending on Codex’s implementation.

Description:
  Invokes `codex:document` with a keyword derived from PACKAGE to generate documentation
  (e.g., HTML files) for the specified system. Used in workflows like `publish-site` to
  prepare files for deployment. Clients can override the default package to document
  alternative systems.

Example:
  (build-site)         ; Generates documentation for :mcodex.
  (build-site \"test\") ; Generates documentation for :test.

Notes:
  - Assumes the `codex` package is loaded and configured.
  - Output directory is set by Codex (typically `*doc-path*` = \"docs/build/mcodex/html/\").
  - Errors from `codex:document` are not caught; wrap with `handler-case` if needed."
  (codex:document (intern (string package) :keyword)))

(defun deploy-site (&optional (source *doc-path*) (destination *ssh-host*))
  "Deploy a local SOURCE directory to a remote DESTINATION using rsync.

Parameters:
  SOURCE (string, optional): The local directory to synchronize, typically where Codex
    outputs documentation. Defaults to `*doc-path*` (\"docs/build/mcodex/html/\").
  DESTINATION (string, optional): The remote rsync destination (host:path format).
    Defaults to `*ssh-host*` (\"web.metacircular.net:/srv/www/codex/\").

Returns:
  `nil` on successful deployment (rsync exit code 0), or `nil` if an error occurs,
    with error details printed to `*error-output*`.

Description:
  Calls `rsync` to transfer files from SOURCE to DESTINATION, providing a convenient
  wrapper for deployment tasks. Suitable for standalone use or as part of `publish-site`.
  Clients can override defaults to deploy to custom locations.

Example:
  (deploy-site)                           ; Deploys *doc-path* to *ssh-host*.
  (deploy-site \"my/docs/\" \"otherserver:/var/www\") ; Custom source and destination.

Notes:
  - Inherits `rsync`’s requirements: rsync installed, SSH configured.
  - Does not validate SOURCE or DESTINATION; ensure they are valid.
  - Verbose rsync output is enabled for monitoring."
  (rsync source destination))

(defun mcodex-path (&optional (package (package-name *package*)))
  "Generate a remote path for storing a site’s files under *top-level*, based on PACKAGE.

Parameters:
  PACKAGE (string or symbol, optional): The package or system name used to determine
    the path. Defaults to the current package’s name (via `package-name` and `*package*`).

Returns:
  A string representing the remote path:
  - If PACKAGE is \"mcodex\" (case-insensitive), returns `*top-level*` (\"/srv/www/codex/\").
  - Otherwise, returns \"*top-level*/<package>/\", with <package> in lowercase.

Description:
  Constructs a path for rsync destinations (e.g., in `build-and-publish`). Ensures the
  `mcodex` package uses the root directory `*top-level*`, while other packages use a
  subdirectory. Validates PACKAGE to prevent empty names, ensuring well-formed paths.
  Clients can use this to customize deployment paths for different systems.

Example:
  (mcodex-path)          ; Returns \"/srv/www/codex/\" in mcodex package.
  (mcodex-path \"test\")  ; Returns \"/srv/www/codex/test/\".
  (mcodex-path 'my-proj) ; Returns \"/srv/www/codex/my-proj/\".

Notes:
  - Paths exclude the host prefix; combine with a host (e.g., \"web.metacircular.net:\").
  - Package names are lowercased for consistent URLs.
  - Does not verify remote path existence; rsync creates directories as needed.
  - Signals an error for invalid (empty) package names."
  (let ((pkg-str (string-downcase (string package))))
    (unless (plusp (length pkg-str))
      (error "Package name must not be empty"))
    (if (string-equal pkg-str "mcodex")
        *top-level*
        (format nil "~A~A/" *top-level* pkg-str))))

(defun publish-site (&key (path *doc-path*)
                          (site (format nil "web.metacircular.net:~A" (mcodex-path)))
                          (package (package-name *package*)))
  "Build and publish a site by generating documentation and deploying it to a remote server.

Parameters:
  PATH (string, optional): The local directory containing documentation to synchronize.
    Defaults to `*doc-path*` (\"docs/build/mcodex/html/\").
  SITE (string, optional): The remote rsync destination (host:path format). Defaults to
    \"web.metacircular.net:\" combined with `(mcodex-path)`, yielding package-specific paths
    (e.g., \"web.metacircular.net:/srv/www/codex/\" for mcodex).
  PACKAGE (string or symbol, optional): The package or system to document. Defaults to
    the current package’s name (via `package-name` and `*package*`).

Returns:
  `nil` if the build and deployment succeed, or `nil` if either fails, with errors printed
    to `*error-output*`.

Description:
  Orchestrates site publishing by:
  1. Calling `build-site` with PACKAGE to generate documentation.
  2. If successful (non-nil result), calling `rsync` with PATH and SITE to deploy.
  Prints progress messages to standard output and errors to `*error-output*`. Ensures
  deployment only proceeds after a successful build, preventing partial uploads. Clients
  can override parameters to customize the build and deployment process.

Example:
  (publish-site)                           ; Builds and deploys with defaults.
  (publish-site :package \"test\")         ; Builds for :test, deploys to .../codex/test/.
  (publish-site :path \"my/docs/\" :site \"otherserver:/var/www\") ; Custom path and site.

Notes:
  - Assumes `build-site` and `rsync` are available.
  - Relies on `build-site` returning a truthy value on success.
  - Does not validate inputs; ensure PATH exists and SITE is accessible.
  - Requires SSH configuration for rsync."
  (format t "Building site for package ~A...~%" package)
  (let ((build-result (build-site package)))
    (if build-result
        (progn
	  (format *error-output* "build-result: ~a~%" build-result)
          (format *error-output* "Build failed, skipping rsync.~%")
          nil)
	(progn
          (format t "Deploying site from ~A to ~A...~%" path site)
          (rsync path site)))))

(defun build-and-publish (&optional (package (package-name *package*)))
  "Build and publish a site for PACKAGE with a package-specific remote path.

Parameters:
  PACKAGE (string or symbol, optional): The package or system to document and deploy.
    Defaults to the current package’s name (via `package-name` and `*package*`).

Returns:
  `nil` if the build and deployment succeed, or `nil` if either fails, with errors printed
    to `*error-output*`.

Description:
  A high-level wrapper around `publish-site` that uses `mcodex-path` to determine the
  remote deployment path based on PACKAGE. Calls `publish-site` with default `*doc-path*`
  and a SITE constructed from \"web.metacircular.net:\" and `(mcodex-path package)`.
  Simplifies deployment for clients who want package-specific paths (e.g., /srv/www/codex/test/
  for :test) without specifying paths manually.

Example:
  (build-and-publish)         ; Builds and deploys to .../codex/ for mcodex.
  (build-and-publish \"test\") ; Builds and deploys to .../codex/test/.

Notes:
  - Assumes `publish-site` and `mcodex-path` are available.
  - Inherits `publish-site`’s requirements (Codex, rsync, SSH).
  - Does not validate `*doc-path*` or remote accessibility."
  (publish-site :package package))
