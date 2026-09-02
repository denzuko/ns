;;;; ns.asd — ASDF system definition for the NS macro library

(defsystem #:ns
  :description    "Single-form namespace declaration for Common Lisp."
  :author         "Dwight Spencer <dwight@dapla.net>"
  :maintainer     "Dwight Spencer <dwight@dapla.net>"
  :license        "BSD-3-Clause"
  :version        "0.1.0"
  :homepage       "https://github.com/denzuko/ns"
  :bug-tracker    "https://github.com/denzuko/ns/issues"
  :source-control (:git "https://github.com/denzuko/ns.git")
  :depends-on     ()
  :components     ((:module "src"
                    :components ((:file "ns"))))
  :in-order-to    ((test-op (test-op #:ns/tests))))

(defsystem #:ns/docs
  :description "40ants-doc manual for the NS macro library."
  :author      "Dwight Spencer <dwight@dapla.net>"
  :license     "BSD-3-Clause"
  :depends-on  (#:ns #:40ants-doc #:40ants-doc-full)
  :components  ((:module "src"
                 :components ((:file "docs")))))

(defsystem #:ns/tests
  :description "FiveAM spec suite for ns and ns/docs."
  :author      "Dwight Spencer <dwight@dapla.net>"
  :license     "BSD-3-Clause"
  :depends-on  (#:ns #:ns/docs #:fiveam)
  :components  ((:module "t"
                 :components ((:file "ns")
                              (:file "docs" :depends-on ("ns")))))
  :perform     (test-op (op sys)
                 (funcall (find-symbol "RUN!" :fiveam)
                          (find-symbol "NS-SUITE" :ns-tests))))
