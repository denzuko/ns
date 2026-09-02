;;;; t/ns.lisp — FiveAM specification tests for the NS macro

(defpackage #:ns-tests
  (:use #:cl #:fiveam #:ns))

(in-package #:ns-tests)

(defmacro with-fresh-package (name &body body)
  "Delete NAME if it exists, execute BODY, then delete NAME on exit."
  `(progn
     (when (find-package ,name) (delete-package ,name))
     (unwind-protect (progn ,@body)
       (when (find-package ,name) (delete-package ,name)))))

(def-suite ns-suite
  :description "NS macro — full specification coverage.")

(in-suite ns-suite)

;;; ─── Basic define and enter ──────────────────────────────────────────────

(test ns-creates-package
  "NS creates the named package when it does not exist."
  (with-fresh-package '#:ns-test.scratch
    (ns #:ns-test.scratch)
    (is (packagep (find-package '#:ns-test.scratch)))))

(test ns-enters-package
  "NS sets *PACKAGE* to the named package."
  (with-fresh-package '#:ns-test.current
    (ns #:ns-test.current)
    (is (eq (find-package '#:ns-test.current) *package*))))

;;; ─── Name designator variants ────────────────────────────────────────────

(test ns-accepts-symbol-name
  "NS accepts an uninterned symbol as the package name."
  (with-fresh-package '#:ns-test.sym
    (ns #:ns-test.sym)
    (is (packagep (find-package '#:ns-test.sym)))))

(test ns-accepts-keyword-name
  "NS accepts a keyword as the package name."
  (with-fresh-package :ns-test.kw
    (ns :ns-test.kw)
    (is (packagep (find-package :ns-test.kw)))))

(test ns-accepts-string-name
  "NS accepts a string as the package name."
  (with-fresh-package "NS-TEST.STR"
    (ns "NS-TEST.STR")
    (is (packagep (find-package "NS-TEST.STR")))))

;;; ─── Default (:use :cl) behaviour ───────────────────────────────────────

(test ns-defaults-to-use-cl
  "NS without any clauses defaults to (:use :cl), making standard
   symbols accessible. This matches the documented interface and the
   expectation of every practitioner who has written defpackage."
  (with-fresh-package '#:ns-test.default-cl
    (ns #:ns-test.default-cl)
    (is (member (find-package '#:cl)
                (package-use-list (find-package '#:ns-test.default-cl)))
        "cl must be in the use-list when no clauses are given")
    (is (eq :inherited
            (nth-value 1 (find-symbol "DEFUN" '#:ns-test.default-cl)))
        "DEFUN must be accessible as an inherited symbol")
    (is (eq :inherited
            (nth-value 1 (find-symbol "PRINT" '#:ns-test.default-cl)))
        "PRINT must be accessible as an inherited symbol")
    (is (eq :inherited
            (nth-value 1 (find-symbol "T" '#:ns-test.default-cl)))
        "T must be accessible as an inherited symbol")))

(test ns-explicit-use-clause-is-used-exactly
  "NS with an explicit :use clause uses that list, not a default."
  (with-fresh-package '#:ns-test.explicit-use
    (ns #:ns-test.explicit-use (:use #:cl))
    (is (member (find-package '#:cl)
                (package-use-list (find-package '#:ns-test.explicit-use)))
        "cl must be in the use-list when explicitly stated")))

(test ns-non-cl-use-does-not-add-cl
  "NS with a :use clause that omits cl does not add cl implicitly.
   The explicit :use list is used as given."
  (with-fresh-package '#:ns-test.no-cl-explicit
    (ns #:ns-test.no-cl-explicit (:use))
    (is-false (member (find-package '#:cl)
                      (package-use-list (find-package '#:ns-test.no-cl-explicit)))
              "cl must not be added when :use is explicitly given without it")))

;;; ─── Standard defpackage clause passthrough ──────────────────────────────

(test ns-use-clause
  "NS :use clause appears in the package use-list."
  (with-fresh-package '#:ns-test.uses
    (ns #:ns-test.uses (:use #:cl))
    (is (member (find-package '#:cl)
                (package-use-list (find-package '#:ns-test.uses))))))

(test ns-export-clause
  "NS :export clause makes symbols externally visible."
  (with-fresh-package '#:ns-test.exports
    (ns #:ns-test.exports (:use #:cl) (:export #:widget))
    (multiple-value-bind (sym status)
        (find-symbol "WIDGET" '#:ns-test.exports)
      (declare (ignore sym))
      (is (eq :external status)))))

(test ns-shadow-clause
  "NS :shadow clause creates a package-local symbol distinct from CL's."
  (with-fresh-package '#:ns-test.shadows
    (ns #:ns-test.shadows (:use #:cl) (:shadow #:format))
    (is-false (eq (find-symbol "FORMAT" '#:ns-test.shadows)
                  (find-symbol "FORMAT" '#:cl)))))

(test ns-import-from-clause
  "NS :import-from pulls a single symbol into the package."
  (with-fresh-package '#:ns-test.source
    (with-fresh-package '#:ns-test.importer
      (ns #:ns-test.source (:use #:cl) (:export #:alpha))
      (export (intern "ALPHA" '#:ns-test.source) '#:ns-test.source)
      (ns #:ns-test.importer
        (:use #:cl)
        (:import-from #:ns-test.source #:alpha))
      (is (find-symbol "ALPHA" '#:ns-test.importer)
          "ALPHA must be accessible in ns-test.importer after :import-from"))))

(test ns-shadowing-import-from-clause
  "NS :shadowing-import-from resolves a symbol conflict without error."
  (with-fresh-package '#:ns-test.left
    (with-fresh-package '#:ns-test.right
      (with-fresh-package '#:ns-test.resolved
        (ns #:ns-test.left  (:use #:cl) (:export #:conflict))
        (export (intern "CONFLICT" '#:ns-test.left)  '#:ns-test.left)
        (ns #:ns-test.right (:use #:cl) (:export #:conflict))
        (export (intern "CONFLICT" '#:ns-test.right) '#:ns-test.right)
        (finishes
          (ns #:ns-test.resolved
            (:use #:cl #:ns-test.left)
            (:shadowing-import-from #:ns-test.right #:conflict)))
        (is (eq (find-symbol "CONFLICT" '#:ns-test.right)
                (find-symbol "CONFLICT" '#:ns-test.resolved))
            "CONFLICT in ns-test.resolved must be the one from ns-test.right")))))

(test ns-nicknames-clause
  "NS :nicknames registers an alternative package name."
  (with-fresh-package '#:ns-test.nicknamed
    (when (find-package '#:ntnick) (delete-package '#:ntnick))
    (ns #:ns-test.nicknamed (:nicknames #:ntnick))
    (is (eq (find-package '#:ns-test.nicknamed)
            (find-package '#:ntnick))
        "Nickname ntnick must resolve to the same package object")))

(test ns-documentation-clause
  "NS :documentation clause attaches a docstring to the package.

   ABCL variance: (documentation package t) returns NIL on ABCL
   regardless of the :documentation clause — an ABCL conformance gap,
   not a macro defect. Skipped on ABCL; asserted on all other targets."
  (with-fresh-package '#:ns-test.documented
    (ns #:ns-test.documented (:documentation "A documented test package."))
    #-abcl
    (is (string= "A documented test package."
                 (documentation (find-package '#:ns-test.documented) t)))
    #+abcl
    (skip "ABCL does not implement (documentation package t)")))

(test ns-local-nicknames-clause
  "NS :local-nicknames registers a scoped nickname within the package."
  (with-fresh-package '#:ns-test.long-name
    (with-fresh-package '#:ns-test.nicker
      (ns #:ns-test.long-name (:use #:cl))
      (ns #:ns-test.nicker
        (:use #:cl)
        (:local-nicknames (#:ln #:ns-test.long-name)))
      (is (eq (find-package '#:ns-test.long-name)
              (find-package '#:ln))
          "Local nickname ln must resolve within ns-test.nicker"))))

;;; ─── Consumer pattern — file with (:use :cl) can define functions ────────

(test ns-with-use-cl-file-can-define-functions
  "A file that opens with (ns :my.pkg (:use :cl)) can use defun, print,
   and other standard forms. Functions defined in the file are callable."
  (with-fresh-package '#:ns-test.cl-file
    (let ((src (uiop:with-temporary-file (:stream s :suffix ".lisp" :keep t)
                 (format s "(ns :ns-test.cl-file (:use :cl))~%(defun runner () t)")
                 (pathname s))))
      (unwind-protect
        (progn
          (compile-file src :output-file
                        (make-pathname :type "fasl" :defaults src))
          (load (make-pathname :type "fasl" :defaults src))
          (is (eq t (funcall (find-symbol "RUNNER" '#:ns-test.cl-file)))
              "RUNNER must be callable and return t"))
        (uiop:delete-file-if-exists src)
        (uiop:delete-file-if-exists
          (make-pathname :type "fasl" :defaults src))))))

(test ns-default-use-cl-file-can-define-functions
  "A file that opens with bare (ns :my.pkg) defaults to (:use :cl)
   and can define functions using standard CL forms."
  (with-fresh-package '#:ns-test.default-file
    (let ((src (uiop:with-temporary-file (:stream s :suffix ".lisp" :keep t)
                 (format s "(ns :ns-test.default-file)~%(defun runner () t)")
                 (pathname s))))
      (unwind-protect
        (progn
          (compile-file src :output-file
                        (make-pathname :type "fasl" :defaults src))
          (load (make-pathname :type "fasl" :defaults src))
          (is (eq t (funcall (find-symbol "RUNNER" '#:ns-test.default-file)))
              "RUNNER must be callable and return t with default (:use :cl)"))
        (uiop:delete-file-if-exists src)
        (uiop:delete-file-if-exists
          (make-pathname :type "fasl" :defaults src))))))

;;; ─── Idempotency ─────────────────────────────────────────────────────────

(test ns-idempotent-when-package-exists
  "NS is a no-op on defpackage when the package already exists."
  (with-fresh-package '#:ns-test.reloaded
    (ns #:ns-test.reloaded)
    (let ((pkg (find-package '#:ns-test.reloaded)))
      (finishes (ns #:ns-test.reloaded))
      (is (eq pkg (find-package '#:ns-test.reloaded))
          "Package object must be identical after reload"))))

(test ns-idempotent-when-already-current
  "NS skips in-package when *PACKAGE* is already the target."
  (with-fresh-package '#:ns-test.current2
    (ns #:ns-test.current2)
    (finishes (ns #:ns-test.current2))
    (is (eq (find-package '#:ns-test.current2) *package*))))

(test ns-clause-changes-ignored-on-reload
  "NS silently ignores clause changes when the package already exists."
  (with-fresh-package '#:ns-test.frozen
    (ns #:ns-test.frozen (:use #:cl))
    (finishes (ns #:ns-test.frozen (:documentation "changed")))
    (is (null (documentation (find-package '#:ns-test.frozen) t)))))

;;; ─── Compile-time existence ──────────────────────────────────────────────

(test ns-package-exists-after-form
  "The declared package exists immediately after the NS form returns."
  (with-fresh-package '#:ns-test.immediate
    (ns #:ns-test.immediate)
    (is (packagep (find-package '#:ns-test.immediate)))))

;;; ─── Boundary and error cases ────────────────────────────────────────────

(test ns-symbol-conflict-via-use-signals-error
  "NS surfaces a symbol conflict from :use as a standard package-error."
  (with-fresh-package '#:ns-test.left2
    (with-fresh-package '#:ns-test.right2
      (with-fresh-package '#:ns-test.conflict
        (ns #:ns-test.left2  (:use #:cl) (:export #:clash))
        (export (intern "CLASH" '#:ns-test.left2)  '#:ns-test.left2)
        (ns #:ns-test.right2 (:use #:cl) (:export #:clash))
        (export (intern "CLASH" '#:ns-test.right2) '#:ns-test.right2)
        (signals error
          (ns #:ns-test.conflict
            (:use #:cl #:ns-test.left2 #:ns-test.right2)))))))

;;; ─── Consumer usage patterns ─────────────────────────────────────────────

(test ns-available-unqualified-in-cl-user
  "NS is importable unqualified in CL-USER after loading the system.
   This is the standard ql:quickload consumer pattern."
  (is (find-symbol "NS" (find-package '#:cl-user))
      "NS symbol must be present in CL-USER after system load")
  (is (macro-function (find-symbol "NS" (find-package '#:cl-user)))
      "NS in CL-USER must be a macro"))

(test ns-downstream-qualified-consumer
  "NS works when called as ns:ns from a compiled file outside the ns package."
  (with-fresh-package '#:ns-test.downstream
    (let ((src (uiop:with-temporary-file (:stream s :suffix ".lisp" :keep t)
                 (format s "(ns:ns :ns-test.downstream (:use :cl) (:export :hello))")
                 (pathname s))))
      (unwind-protect
        (progn
          (compile-file src :output-file (make-pathname :type "fasl" :defaults src))
          (load (make-pathname :type "fasl" :defaults src))
          (is (packagep (find-package :ns-test.downstream))
              "Package must exist after loading a compiled file using ns:ns")
          (is (eq :external
                  (nth-value 1 (find-symbol "HELLO" :ns-test.downstream)))
              ":export clause must be honoured"))
        (uiop:delete-file-if-exists src)
        (uiop:delete-file-if-exists
          (make-pathname :type "fasl" :defaults src))))))

(test ns-downstream-unqualified-consumer
  "NS works when called unqualified from a compiled file after system load."
  (with-fresh-package '#:ns-test.unqualified
    (let ((src (uiop:with-temporary-file (:stream s :suffix ".lisp" :keep t)
                 (format s "(ns :ns-test.unqualified (:use :cl) (:export :hello))")
                 (pathname s))))
      (unwind-protect
        (progn
          (compile-file src :output-file (make-pathname :type "fasl" :defaults src))
          (load (make-pathname :type "fasl" :defaults src))
          (is (packagep (find-package :ns-test.unqualified))
              "Package must exist after loading a compiled file using unqualified ns")
          (is (eq :external
                  (nth-value 1 (find-symbol "HELLO" :ns-test.unqualified)))
              ":export clause must be honoured"))
        (uiop:delete-file-if-exists src)
        (uiop:delete-file-if-exists
          (make-pathname :type "fasl" :defaults src))))))

;;; ─── Multi-namespace / cross-reference ───────────────────────────────────

(test ns-cross-namespace-provider-consumer
  "NS correctly sequences a provider and consumer namespace declaration."
  (with-fresh-package '#:ns-test.provider
    (with-fresh-package '#:ns-test.consumer
      (ns #:ns-test.provider (:use #:cl) (:export #:provided-fn))
      (export (intern "PROVIDED-FN" '#:ns-test.provider) '#:ns-test.provider)
      (ns #:ns-test.consumer (:use #:cl #:ns-test.provider))
      (is (member (find-package '#:ns-test.provider)
                  (package-use-list (find-package '#:ns-test.consumer)))
          "Provider must appear in consumer use-list"))))

(test ns-multi-file-idempotent-reload
  "Four-namespace project reload is fully idempotent."
  (dolist (pkg '(#:ns-test.deploy #:ns-test.docs
                 #:ns-test.e2e   #:ns-test.mfspec))
    (when (find-package pkg) (delete-package pkg)))
  (unwind-protect
    (progn
      (ns #:ns-test.deploy (:use #:cl) (:export #:run))
      (ns #:ns-test.docs   (:use #:cl #:ns-test.deploy))
      (ns #:ns-test.e2e    (:use #:cl #:ns-test.deploy))
      (ns #:ns-test.mfspec (:use #:cl #:ns-test.deploy))
      (finishes
        (ns #:ns-test.deploy (:use #:cl) (:export #:run))
        (ns #:ns-test.docs   (:use #:cl #:ns-test.deploy))
        (ns #:ns-test.e2e    (:use #:cl #:ns-test.deploy))
        (ns #:ns-test.mfspec (:use #:cl #:ns-test.deploy)))
      (is (packagep (find-package '#:ns-test.deploy)))
      (is (member (find-package '#:ns-test.deploy)
                  (package-use-list (find-package '#:ns-test.docs)))))
    (dolist (pkg '(#:ns-test.docs #:ns-test.e2e
                   #:ns-test.mfspec #:ns-test.deploy))
      (when (find-package pkg) (delete-package pkg)))))

(test ns-interleaved-package-switching
  "Repeated NS forms correctly switch *PACKAGE* between namespaces."
  (with-fresh-package '#:ns-test.a
    (with-fresh-package '#:ns-test.b
      (ns #:ns-test.a)
      (is (eq (find-package '#:ns-test.a) *package*))
      (ns #:ns-test.b)
      (is (eq (find-package '#:ns-test.b) *package*))
      (ns #:ns-test.a)
      (is (eq (find-package '#:ns-test.a) *package*)))))

;;; ─── Concurrency ──────────────────────────────────────────────────────────

#-ecl
(test ns-concurrent-distinct-packages
  "Concurrent NS calls on distinct package names do not race."
  (with-fresh-package '#:ns-test.thread-a
    (with-fresh-package '#:ns-test.thread-b
      (let ((errors nil)
            (lock (bt:make-lock "ns-concurrent-test")))
        (let ((ta (bt:make-thread
                    (lambda ()
                      (handler-case
                        (ns #:ns-test.thread-a (:use #:cl))
                        (error (c)
                          (bt:with-lock-held (lock)
                            (push c errors)))))))
              (tb (bt:make-thread
                    (lambda ()
                      (handler-case
                        (ns #:ns-test.thread-b (:use #:cl))
                        (error (c)
                          (bt:with-lock-held (lock)
                            (push c errors))))))))
          (bt:join-thread ta)
          (bt:join-thread tb))
        (is-false errors "No errors from concurrent NS calls on distinct names")
        (is (packagep (find-package '#:ns-test.thread-a))
            "ns-test.thread-a must exist after concurrent creation")
        (is (packagep (find-package '#:ns-test.thread-b))
            "ns-test.thread-b must exist after concurrent creation")))))

#-ecl
(test ns-concurrent-same-package-idempotent
  "Concurrent NS calls on the same package name are idempotent.
   The unless (find-package) guard is not atomic, so two threads may
   both pass the guard and attempt defpackage simultaneously. The
   result must be one package with the correct use-list and no errors."
  (with-fresh-package '#:ns-test.shared
    (let ((errors nil)
          (lock (bt:make-lock "ns-shared-test")))
      (let ((threads (loop repeat 4 collect
                       (bt:make-thread
                         (lambda ()
                           (handler-case
                             (ns #:ns-test.shared (:use #:cl))
                             (error (c)
                               (bt:with-lock-held (lock)
                                 (push c errors)))))))))
        (mapc #'bt:join-thread threads))
      (is-false errors "No errors from concurrent NS calls on the same name")
      (is (packagep (find-package '#:ns-test.shared))
          "Package must exist after concurrent creation")
      (is (member (find-package '#:cl)
                  (package-use-list (find-package '#:ns-test.shared)))
          "(:use :cl) must be honoured"))))

(test ns-load-without-system-fails
  "The ns symbol is only accessible in CL-USER after the ns system
   loads. Before the system loads, (ns ...) in a file read via --load
   fails with UNDEFINED-FUNCTION because the shadow-import has not run.
   This test documents the invariant: ns:ns is a macro, and the
   cl-user::ns shadow only exists after system load."
  (is (macro-function (find-symbol "NS" '#:ns))
      "ns:ns must be a macro after system load")
  (is (find-symbol "NS" (find-package '#:cl-user))
      "NS must be shadow-imported into cl-user after system load"))

(test ns-asdf-depends-on-loads-ns-first
  "asdf:load-system with :depends-on (#:ns) loads ns before compiling
   any of the project components. This is the correct consumer path
   when a project has an .asd file."
  (with-fresh-package '#:ns-test.asdf-pkg
    (let* ((dir (uiop:ensure-directory-pathname "/tmp/ns-asdf-test/"))
           (asd-path (merge-pathnames "ns-asdf-test.asd" dir))
           (pkg-path (merge-pathnames "pkg.lisp" dir)))
      (unwind-protect
        (progn
          (ensure-directories-exist dir)
          (with-open-file (s asd-path :direction :output :if-exists :supersede)
            (format s "(asdf:defsystem #:ns-asdf-test :depends-on (#:ns) :components ((:file \"pkg\")))"))
          (with-open-file (s pkg-path :direction :output :if-exists :supersede)
            (format s "(ns :ns-test.asdf-pkg (:export :hello))"))
          (pushnew dir asdf:*central-registry* :test #'equal)
          (asdf:load-system :ns-asdf-test)
          (is (packagep (find-package '#:ns-test.asdf-pkg))
              "Package must exist after asdf:load-system with :depends-on (#:ns)")
          (is (eq :external
                  (nth-value 1 (find-symbol "HELLO" '#:ns-test.asdf-pkg)))
              ":export clause must be honoured"))
        (setf asdf:*central-registry*
              (remove dir asdf:*central-registry* :test #'equal))
        (uiop:delete-file-if-exists asd-path)
        (uiop:delete-file-if-exists pkg-path)
        (uiop:delete-file-if-exists
          (make-pathname :type "fasl" :defaults pkg-path))))))

(test ns-bare-keyword-clauses-signal-error
  "NS clause syntax must be list forms, not bare keywords.
   The ros init template generates (ns :pkg :export #:fn) which fails.
   Each clause must be a list: (:export #:fn)."
  (with-fresh-package '#:ns-test.bad-clauses
    (signals error
      (eval '(ns #:ns-test.bad-clauses :export #:fn)))))

(test ns-roswell-script-correct-syntax
  "NS with correct Roswell script clause syntax works.
   The correct form uses list clauses: (:use :cl) (:export #:main)."
  (with-fresh-package '#:ns-test.ros-script
    (ns #:ns-test.ros-script (:use #:cl) (:export #:main))
    (is (packagep (find-package '#:ns-test.ros-script)))
    (is (eq :external
            (nth-value 1 (find-symbol "MAIN" '#:ns-test.ros-script)))
        "MAIN must be exported")))

;;; ─── Multi-namespace cross-package call ──────────────────────────────────

(test ns-import-from-makes-symbol-callable
  "NS with :import-from makes an imported symbol callable in the
   importing package. A function defined in pkg-a and exported,
   then imported into pkg-b, is callable from pkg-b."
  (with-fresh-package '#:ns-test.cross-a
    (with-fresh-package '#:ns-test.cross-b
      (ns #:ns-test.cross-a (:use #:cl) (:export #:greet))
      (let ((greet-sym (intern "GREET" '#:ns-test.cross-a)))
        (setf (symbol-function greet-sym) (lambda () "hello"))
        (export greet-sym '#:ns-test.cross-a))
      (ns #:ns-test.cross-b
          (:use #:cl)
          (:import-from #:ns-test.cross-a #:greet))
      (is (string= "hello"
                   (funcall (find-symbol "GREET" '#:ns-test.cross-b)))
          "greet imported from ns-test.cross-a must be callable in ns-test.cross-b"))))

(test ns-hyphen-package-name-requires-hyphen-qualifier
  "Package names with hyphens use colon qualifier with hyphens.
   ns-example:main is valid; ns_example:main is a read error because
   ns_example (with underscore) does not exist as a package."
  (with-fresh-package '#:ns-test.hyphen-pkg
    (ns #:ns-test.hyphen-pkg (:use #:cl) (:export #:fn))
    (setf (symbol-function (intern "FN" '#:ns-test.hyphen-pkg)) (lambda () t))
    (is (eq t (funcall (find-symbol "FN" '#:ns-test.hyphen-pkg)))
        "ns-test.hyphen-pkg:fn must be callable via hyphenated qualifier")
    (signals error
      (read-from-string "(ns_test.hyphen_pkg:fn)")
      "ns_test.hyphen_pkg with underscores must signal a read error")))

(test ns-sequential-forms-one-file-cross-import
  "Sequential NS forms in one file — each enters its own package.
   This is the ns-example.lisp pattern: two namespaces in one file,
   the second importing from the first."
  (with-fresh-package '#:ns-test.seq-a
    (with-fresh-package '#:ns-test.seq-b
      (ns #:ns-test.seq-a (:use #:cl) (:export #:do-work))
      (let ((sym (intern "DO-WORK" '#:ns-test.seq-a)))
        (setf (symbol-function sym) (lambda () t))
        (export sym '#:ns-test.seq-a))
      (ns #:ns-test.seq-b
          (:use #:cl)
          (:import-from #:ns-test.seq-a #:do-work))
      (is (eq (symbol-function (find-symbol "DO-WORK" '#:ns-test.seq-a))
              (symbol-function (find-symbol "DO-WORK" '#:ns-test.seq-b)))
          "do-work in ns-test.seq-b must be the function from ns-test.seq-a")
      (is (eq t (funcall (find-symbol "DO-WORK" '#:ns-test.seq-b)))
          "do-work must return t when called from ns-test.seq-b"))))

(test ns-quickload-inside-asdf-component-is-harmless
  "ql:quickload called inside a file that is loaded as an ASDF component
   after :ns is already in the image is redundant but not harmful."
  (with-fresh-package '#:ns-test.ql-redundant
    (let ((src (uiop:with-temporary-file (:stream s :suffix ".lisp" :keep t)
                 (format s "(ql:quickload :ns :silent t)~%(ns :ns-test.ql-redundant (:use :cl) (:export :hello))")
                 (pathname s))))
      (unwind-protect
        (progn
          (compile-file src :output-file (make-pathname :type "fasl" :defaults src))
          (load (make-pathname :type "fasl" :defaults src))
          (is (packagep (find-package '#:ns-test.ql-redundant))
              "Package must exist after load")
          (is (eq :external
                  (nth-value 1 (find-symbol "HELLO" '#:ns-test.ql-redundant)))
              ":export must be honoured"))
        (uiop:delete-file-if-exists src)
        (uiop:delete-file-if-exists
          (make-pathname :type "fasl" :defaults src))))))

(test ns-available-unqualified-in-created-package
  "Every package NS creates has NS imported into it, so subsequent
   (ns ...) calls in the same file work unqualified. This is the
   documented interface — (ns :pkg-a) then (ns :pkg-b) throughout
   a multi-namespace file, no ns:ns qualification needed."
  (with-fresh-package '#:ns-test.switch-a
    (with-fresh-package '#:ns-test.switch-b
      (ns #:ns-test.switch-a (:use #:cl))
      (is (eq (find-package '#:ns-test.switch-a) *package*)
          "First ns call enters ns-test.switch-a")
      (is (find-symbol "NS" '#:ns-test.switch-a)
          "NS must be importable in ns-test.switch-a after creation")
      (finishes (ns #:ns-test.switch-b (:use #:cl)))
      (is (packagep (find-package '#:ns-test.switch-b))
          "Unqualified ns call works from ns-test.switch-a"))))

(test ns-multi-namespace-file-unqualified-throughout
  "A multi-namespace file can use unqualified ns throughout.
   Each ns call makes ns available in the package it creates."
  (with-fresh-package '#:ns-test.multi-a
    (with-fresh-package '#:ns-test.multi-b
      (with-fresh-package '#:ns-test.multi-c
        (ns #:ns-test.multi-a (:use #:cl))
        (ns #:ns-test.multi-b (:use #:cl))
        (ns #:ns-test.multi-c (:use #:cl))
        (is (packagep (find-package '#:ns-test.multi-a)))
        (is (packagep (find-package '#:ns-test.multi-b)))
        (is (packagep (find-package '#:ns-test.multi-c)))))))

(test ns-qualified-form-works-from-any-package
  "ns:ns qualified form works regardless of which package is current."
  (with-fresh-package '#:ns-test.arbitrary
    (ns #:ns-test.arbitrary (:use #:cl))
    (with-fresh-package '#:ns-test.from-arbitrary
      (finishes (ns:ns #:ns-test.from-arbitrary (:use #:cl)))
      (is (packagep (find-package '#:ns-test.from-arbitrary))))))
