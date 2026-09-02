Feature: NS macro — single-form namespace declaration for Common Lisp

  As a Common Lisp practitioner
  I want a single (ns name clause*) form
  So that I can define and enter a package without a separate in-package.

  Background:
    Given the NS library is loaded

  # ─── Basic define and enter ────────────────────────────────────────────

  Scenario: NS creates a named package
    When I evaluate (ns #:my.app)
    Then (find-package '#:my.app) returns a package object

  Scenario: NS enters the named package
    When I evaluate (ns #:my.app)
    Then *PACKAGE* equals (find-package '#:my.app)

  # ─── Name designator variants ───────────────────────────────────────────

  Scenario: NS accepts an uninterned symbol as the name
    When I evaluate (ns #:my.app)
    Then the package is created

  Scenario: NS accepts a keyword as the name
    When I evaluate (ns :my.app)
    Then the package is created

  Scenario: NS accepts a string as the name
    When I evaluate (ns "MY.APP")
    Then the package is created

  # ─── Standard defpackage clause passthrough ─────────────────────────────

  Scenario: :use clause is passed through to defpackage
    When I evaluate (ns #:my.app (:use #:cl))
    Then #:cl appears in (package-use-list (find-package '#:my.app))

  Scenario: :export clause makes symbols externally visible
    When I evaluate (ns #:my.app (:use #:cl) (:export #:widget))
    Then (find-symbol "WIDGET" '#:my.app) returns status :external

  Scenario: :shadow clause creates a package-local symbol
    When I evaluate (ns #:my.app (:use #:cl) (:shadow #:format))
    Then my.app:format is a distinct symbol from cl:format

  Scenario: :import-from clause makes a single symbol accessible
    Given a package ns-test.source exporting #:alpha
    When I evaluate (ns #:my.app (:import-from #:ns-test.source #:alpha))
    Then alpha is accessible in my.app without qualification

  Scenario: :shadowing-import-from resolves a symbol conflict
    Given packages ns-test.left and ns-test.right both export #:conflict
    When I evaluate (ns #:my.app (:use #:ns-test.left)
                                 (:shadowing-import-from #:ns-test.right #:conflict))
    Then no error is signalled
    And my.app:conflict is the symbol from ns-test.right

  Scenario: :nicknames clause registers an alternative package name
    When I evaluate (ns #:my.app (:nicknames #:app))
    Then (find-package '#:app) returns the same package as (find-package '#:my.app)

  Scenario: :documentation clause attaches a docstring to the package
    When I evaluate (ns #:my.app (:documentation "My package."))
    Then (documentation (find-package '#:my.app) t) returns "My package."

  Scenario: :local-nicknames clause registers a scoped nickname
    Given a package ns-test.long-name
    When I evaluate (ns #:my.app (:use #:cl) (:local-nicknames (#:ln #:ns-test.long-name)))
    Then ln is a local nickname for ns-test.long-name within my.app

  # ─── (:use :cl) requirement

  Scenario: NS without any :use clause defaults to (:use :cl)
    When I evaluate (ns #:my.app) with no clauses
    Then cl is in the use-list of my.app
    And DEFUN is accessible in my.app as an inherited symbol
    And PRINT is accessible in my.app as an inherited symbol
    And T is accessible in my.app as an inherited symbol
 ─────────────────────────────────────────────

  Scenario: NS without (:use :cl) creates a package with no standard symbols
    When I evaluate (ns #:my.app)
    Then cl is not in the use-list of my.app
    And DEFUN is not accessible in my.app without qualification
    And PRINT is not accessible in my.app without qualification
    And T is not accessible in my.app without qualification

  Scenario: NS with (:use :cl) makes standard symbols accessible
    When I evaluate (ns #:my.app (:use #:cl))
    Then DEFUN is accessible in my.app as an inherited symbol
    And PRINT is accessible in my.app as an inherited symbol
    And T is accessible in my.app as an inherited symbol


  Scenario: A file loaded after (ns :my.pkg (:use :cl)) can call defun
    Given a file containing (ns :my.pkg (:use :cl)) followed by (defun runner () t)
    When that file is loaded
    Then no undefined-function warning is signalled
    And runner is callable in my.pkg and returns t

  # ─── Idempotency ────────────────────────────────────────────────────────

  Scenario: NS skips defpackage when the package already exists
    Given I have evaluated (ns #:my.app) once
    When I evaluate (ns #:my.app) a second time
    Then no error is signalled
    And the package object is unchanged

  Scenario: NS skips in-package when already in the target package
    Given *PACKAGE* is already #:my.app
    When I evaluate (ns #:my.app)
    Then no error is signalled
    And *PACKAGE* remains (find-package '#:my.app)

  Scenario: NS clause changes on reload are silently ignored
    Given (ns #:my.app (:use #:cl)) has been evaluated
    When I evaluate (ns #:my.app (:documentation "changed"))
    Then no error is signalled
    And the package documentation remains nil

  # ─── Compile-time existence ──────────────────────────────────────────────

  Scenario: The declared package exists immediately after the NS form
    When I evaluate (ns #:my.app)
    Then (find-package '#:my.app) is non-nil in the same compilation unit

  # ─── Boundary and error cases ────────────────────────────────────────────

  Scenario: Symbol conflicts via :use surface as a standard error
    Given packages ns-test.left and ns-test.right both export #:conflict
    When I evaluate (ns #:my.app (:use #:ns-test.left #:ns-test.right))
    Then a package-error is signalled

  # ─── Consumer usage patterns ─────────────────────────────────────────────

  Scenario: NS is available unqualified in CL-USER after ql:quickload
    When I evaluate (ql:quickload :ns)
    Then (ns #:my.pkg (:use #:cl)) works without package qualification
    And ns:ns qualified form also works

  Scenario: NS works when called as ns:ns from a compiled file
    Given a source file containing (ns:ns :my.pkg (:use :cl))
    When that file is compiled and loaded with ns as a dependency
    Then the package exists and (:use :cl) is honoured

  Scenario: NS works when called unqualified from a compiled file
    Given a source file containing (ns :my.pkg (:use :cl))
    When that file is compiled and loaded after (ql:quickload :ns)
    Then the package exists and (:use :cl) is honoured

  Scenario: Loading a file with --load before (ql:quickload :ns) fails
    Given a file containing (ns :my.pkg)
    When loaded via sbcl --load without first loading ns
    Then an UNDEFINED-FUNCTION error is signalled for NS

  Scenario: Loading via asdf:load-system respects :depends-on (#:ns)
    Given a project .asd with :depends-on (#:ns)
    When I evaluate (asdf:load-system :my-project)
    Then ns is loaded before the project's components compile
    And (ns :my.pkg) works without a prior (ql:quickload :ns)

  # ─── Multi-namespace / cross-reference ───────────────────────────────────

  Scenario: Sequential NS forms correctly sequence provider and consumer packages
    Given NS declares ns-test.provider with (:export #:provided-fn)
    When I evaluate (ns #:ns-test.consumer (:use #:cl #:ns-test.provider))
    Then ns-test.provider appears in the use-list of ns-test.consumer

  Scenario: Multi-file project reload is fully idempotent
    Given four packages declared with NS (deploy, docs, e2e, spec pattern)
    When all four NS forms are evaluated a second time
    Then no error is signalled
    And all cross-package :use relationships are preserved

  Scenario: NS is safe when forms from multiple namespaces interleave
    Given packages ns-test.a and ns-test.b are declared with NS
    When I switch between them with repeated NS forms
    Then *PACKAGE* matches the most recently evaluated NS form


  # ─── Concurrency ──────────────────────────────────────────────────────────

  Scenario: Concurrent NS calls on distinct package names do not race
    Given two threads each calling NS with a different package name simultaneously
    When both threads complete
    Then both packages exist and neither is corrupted

  Scenario: Concurrent NS calls on the same package name are idempotent
    Given two threads each calling (ns :ns-test.shared (:use :cl)) simultaneously
    When both threads complete
    Then exactly one package exists with the correct use-list
    And no error is signalled by either thread
  # ─── ns/docs system ──────────────────────────────────────────────────────

  Scenario: @ns-manual section exists and has the correct title
    When I access ns/docs:@ns-manual
    Then it is a 40ants-doc section object with title "NS"

  Scenario: generate produces non-empty markdown output containing the title
    When I evaluate (ns/docs:generate nil :markdown)
    Then the result is a non-empty string containing "NS"

  Scenario: generate accepts :html format without error
    When I evaluate (ns/docs:generate nil :html)
    Then no error is signalled
    And the result is a non-empty string

  Scenario: NS clause syntax must be list forms not bare keywords
    When I evaluate (ns :my.pkg :export #:fn)
    Then a compile-time error is signalled
    And the error states the value :EXPORT is not of type LIST

  Scenario: NS with correct Roswell script clause syntax works
    When I evaluate (ns :my.script (:use :cl) (:export #:main))
    Then the package exists with main exported

  # ─── Multi-namespace cross-package call ──────────────────────────────────

  Scenario: NS with :import-from makes a symbol callable in the importing package
    Given ns-example exports main
    And ns-example/fu imports main from ns-example
    When I call main from within ns-example/fu
    Then it executes without error

  Scenario: Package names with hyphens use colon qualifier not underscore
    Given a package named ns-example
    When I write (ns-example:main)
    Then the symbol resolves correctly
    When I write (ns_example:main)
    Then a package-does-not-exist error is signalled at read time

  Scenario: Sequential NS forms in one file — each enters its own package
    Given a file with (ns :pkg-a) then (defun fa () t) then (ns :pkg-b (:import-from :pkg-a :fa))
    When the file is loaded
    Then fa is accessible in pkg-b via import
    And calling fa from pkg-b returns t

  Scenario: ql:quickload inside a file loaded via ASDF is redundant but not harmful
    Given a file that calls (ql:quickload :ns) and then (ns :my.pkg)
    When that file is loaded as an ASDF component after :ns is already loaded
    Then no error is signalled
    And the package exists

  Scenario: NS is available unqualified in every package NS creates
    Given (ns :pkg-a) has been evaluated
    When *PACKAGE* is pkg-a
    Then (ns :pkg-b (:use :cl)) works unqualified without ns:ns qualification

  Scenario: Multi-namespace file uses unqualified ns throughout
    Given a file containing (ns :pkg-a) then (ns :pkg-b) then (ns :pkg-c)
    When the file is loaded
    Then all three packages exist
    And each ns call succeeds without qualification

  Scenario: NS:NS qualified form also works regardless of current package
    Given *PACKAGE* is any package
    When I evaluate (ns:ns :my.pkg (:use :cl))
    Then the package is created and entered without error
