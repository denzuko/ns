;;;; ns.lisp — Single-form namespace declaration for Common Lisp

(in-package #:cl-user)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package '#:ns)
    (defpackage #:ns
      (:use #:cl)
      (:export #:ns))))

(in-package #:ns)

(defmacro ns (name &body clauses)
  "Define and enter a package in one form.

   NAME is a package designator (symbol, keyword, or string).
   CLAUSES are standard DEFPACKAGE option forms, passed through verbatim:

     (:use package*)
     (:export symbol*)
     (:import-from package symbol*)
     (:shadow symbol*)
     (:shadowing-import-from package symbol*)
     (:nicknames name*)
     (:documentation string)
     (:local-nicknames (nick package)*)

   The package is created only if it does not already exist (idempotent).
   IN-PACKAGE is a no-op if the current package is already NAME.

   Wrapped in EVAL-WHEN (:compile-toplevel :load-toplevel :execute) so
   the package exists when the compiler advances past this form, matching
   the load-order semantics of a top-level DEFPACKAGE (CLHS 11.2).

   Idempotency trade-off: clause changes on reload are silently ignored.
   Delete the package first if a structural change must take effect in a
   live image.

   Availability: ns is shadow-imported into CL-USER at load time, so
   (ql:quickload :ns) followed by (ns ...) works without qualification.
   In a production package that does not (:use #:ns), the qualified
   form ns:ns is always available. The common-lisp package is locked by
   the ANSI standard and cannot be extended with new symbols.

   Example:

     (ns #:my.app
       (:use #:cl #:alexandria)
       (:export #:start #:stop)
       (:documentation \"Top-level application package.\"))"
  (let ((effective-clauses
          (cond ((member :use clauses :key #'car) clauses)
                (t (cons '(:use #:cl) clauses)))))
    `(eval-when (:compile-toplevel :load-toplevel :execute)
       (unless (find-package ',name)
         (defpackage ,name ,@effective-clauses))
       (unless (eq *package* (find-package ',name))
         (in-package ,name))
       (import 'ns:ns (find-package ',name))
       (export 'ns:ns (find-package ',name)))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (import 'ns:ns (find-package '#:cl-user))
  (export 'ns:ns (find-package '#:cl-user)))
