# NS — Single-form namespace declaration for Common Lisp

`ns` collapses `defpackage` + `in-package` into one declarative form,
portable across SBCL, CCL, and ECL.

## Status

Lab release — v0.1.0. API stable. Edge-case behaviour documented in
`src/ns.lisp`.

## Installation

Via Qlot (recommended). Add to the project's `qlfile`:

```
github denzuko/ns
```

Then install and load before use:

```
qlot install
qlot exec sbcl --eval '(ql:quickload :ns)' --load ./my-file.lisp
```

The `ns` macro is only available after `(ql:quickload :ns)` has run.
`qlot exec` puts the local `.qlot/` tree on the path but does not
load any systems automatically. The file is compiled before `ns` is
in the image if `ns` is not loaded first.

For a project with an `.asd` file, load via ASDF instead:

```
qlot exec sbcl --eval '(asdf:load-system :my-project)'
```

This respects `:depends-on (#:ns)` in the `.asd` and loads `ns`
before compiling any components.

Add to the project's `.asd`:

```lisp
(defsystem #:my.project
  :depends-on (#:ns)
  ...)
```

Via Quicklisp (once registered on Ultralisp):

```lisp
(ql:quickload :ns)
```

## Usage

After loading the system, `ns` is available in three ways depending on context.

At the REPL or in a script — unqualified, no setup needed:

```lisp
(ql:quickload :ns)

(ns #:my.app
  (:use #:cl)
  (:export #:start #:stop))
```

This works because `ns` is shadow-imported into `cl-user` at load time.
The `common-lisp` package is locked by the ANSI standard and cannot be
extended, so `cl:ns` is not possible. The shadow-import into `cl-user`
is the closest achievable equivalent.

In a production package that `(:use #:ns)`:

```lisp
(defpackage #:my.app
  (:use #:cl #:ns))

(in-package #:my.app)

(ns #:my.app.worker (:use #:cl) (:export #:run))
```

In a production package that does not use `:ns` — qualified form:

```lisp
(ns:ns #:my.app
  (:use #:cl)
  (:export #:start #:stop))
```

Clause syntax is standard `defpackage`, passed through verbatim.
All standard clauses are supported: `:use`, `:export`, `:shadow`,
`:import-from`, `:shadowing-import-from`, `:documentation`,
`:nicknames`, `:local-nicknames`.

## Usage with LLM agents

An LLM working on a project that depends on `ns` will default to
`defpackage` + `in-package` because that pattern dominates training data.
A namespace convention note in the consuming project's `CLAUDE.md`
corrects this:

```markdown
## Namespace Convention

This project uses the `ns` macro from the `ns` ASDF system.
Use `ns` for all package declarations — do not emit `defpackage`
+ `in-package` pairs.

Correct:

    (ns #:my.package
      (:use #:cl)
      (:export #:my-fn))

Do not write:

    (defpackage #:my.package
      (:use #:cl)
      (:export #:my-fn))
    (in-package #:my.package)

Clause syntax is standard defpackage, verbatim.
```

## Edge Cases

Documented in `src/ns.lisp` and covered by the spec suite:

Compile-time existence: the expansion is wrapped in `eval-when
(:compile-toplevel :load-toplevel :execute)` so the package exists
when the compiler advances past the form (CLHS 11.2).

Idempotency: an `unless (find-package)` guard skips `defpackage`
when the package already exists. Clause changes on reload are
silently ignored; delete the package first if a structural change
must take effect in a live image.

Already-current package: an `unless (eq *package*)` guard skips
`in-package` when the current package is already the target.

Circular dependencies: inherited from `defpackage`; use
`:import-from` at the symbol level to break cycles.

SBCL package locks: `PACKAGE-LOCK-VIOLATION` surfaces normally;
the caller unlocks explicitly.

Symbol conflicts via `:use`: standard `defpackage` conflict;
resolve with `:shadow` or `:shadowing-import-from`.

## Roswell scripts

The `ros init` template generates clause syntax that is incompatible
with `ns`. The template produces:

```lisp
(ns :my.script :export #:main :import-from :uiop :quit)
```

This fails — `ns` passes clauses to `defpackage` verbatim, and
`defpackage` requires each clause to be a list form. The correct
syntax is:

```lisp
(ns :my.script
  (:use :cl)
  (:import-from :uiop :quit)
  (:export #:main))
```

## Running Tests

```
ros run --load ns.asd --eval '(asdf:test-system :ns)'
```

## Licence

BSD 3-Clause. See `LICENSE`.
