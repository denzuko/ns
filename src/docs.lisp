;;;; src/docs.lisp

(defpackage #:ns/docs
  (:use #:cl)
  (:import-from #:40ants-doc #:defsection)
  (:import-from #:40ants-doc-full/builder #:render-to-string)
  (:export #:@ns-manual
           #:generate))

(in-package #:ns/docs)

(defsection @ns-manual (:title "NS")
  "Single-form namespace declaration for Common Lisp.

   (ns name clause*) replaces the defpackage + in-package pair.
   Clause syntax is standard defpackage, passed through verbatim.
   Portability target: SBCL, CCL, ECL."
  (ns:ns macro))

(defun generate (&optional (stream *standard-output*) (format :markdown))
  "Render @NS-MANUAL to STREAM in FORMAT (:markdown or :html)."
  (write-string (render-to-string @ns-manual :format format) stream))
