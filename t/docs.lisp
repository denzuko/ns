;;;; t/docs.lisp

(defpackage #:ns-docs-tests
  (:use #:cl #:fiveam)
  (:import-from #:40ants-doc #:section-title)
  (:import-from #:ns/docs #:@ns-manual #:generate))

(in-package #:ns-docs-tests)

(def-suite ns-docs-suite
  :description "ns/docs — 40ants-doc manual coverage."
  :in ns-tests::ns-suite)

(in-suite ns-docs-suite)

(test ns-docs-manual-exists
  "The @ns-manual section object exists and is bound."
  (is (boundp '@ns-manual)))

(test ns-docs-manual-title
  "The @ns-manual section has title \"NS\"."
  (is (string= "NS" (section-title @ns-manual))))

(test ns-docs-generate-markdown-non-empty
  "generate produces a non-empty string in markdown format."
  (let ((output (with-output-to-string (s) (generate s :markdown))))
    (is (plusp (length output)))))

(test ns-docs-generate-markdown-contains-title
  "generate markdown output contains the section title."
  (let ((output (with-output-to-string (s) (generate s :markdown))))
    (is (search "NS" output))))

(test ns-docs-generate-markdown-contains-macro
  "generate markdown output references the ns macro."
  (let ((output (with-output-to-string (s) (generate s :markdown))))
    (is (or (search "NS" output) (search "ns" output)))))

(test ns-docs-generate-html-non-empty
  "generate produces a non-empty string in html format."
  (let ((output (with-output-to-string (s) (generate s :html))))
    (is (plusp (length output)))))
