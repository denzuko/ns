# CLAUDE.md — NS Macro Library

| Field         | Value                                                       |
|---------------|-------------------------------------------------------------|
| Application   | ns                                                          |
| Description   | Single-form namespace declaration macro for Common Lisp                      |
| Type          | lisp-macro-library (placeholder: lisp-actor — denzuko/dps-meta#5)                                          |
| Version       | 0.1.0                                                       |
| Branch        | develop                                                     |
| Licence       | BSD-3-Clause                                                |
| Organisation  | denzuko                                                     |

## Standards Stack

- ASDF umbrella pattern (root + /tests subsystem)
- Roswell + Qlot for dependency management
- 40ants-ci for CI pipeline
- FiveAM + Gherkin for BDD spec tests (sunny-side engine)
- denzuko/dps-meta@v1 governance action
- BSD-3-Clause licence (no MIT, no GPL-family)
- Semver: MAJOR = public API break; MINOR = new capability; PATCH = everything else
- Docstrings: human-facing prose only, no LLM-prompt-style language
- Closing-paren stacking beyond 4–5 deep signals scope creep; refactor to macros/functions

## BDD Workflow

```
BDD gate → spec tests → code → e2e tests → changelog → merge → tag
```

## Subcommands

```
ros run --load ns.asd --eval '(asdf:test-system :ns)'   # run spec suite
ros run --load ns.asd --eval '(asdf:load-system :ns)'   # load library
```

## Quality Gate

Run before every commit:

```
# CL reader gate (authoritative, handles all CL syntax)
./gate.ros

# Voice gate on prose, docstrings, README, CLAUDE.md
python3 scripts/blog-voice-check.py README.md CLAUDE.md

# Run locally before pushing
./tests.ros
```

The gate script is `gate.ros`. Uses the CL reader directly, which is
the only authoritative tool for CL syntax including strings and comments.

## Do Not

- Do not use MIT or GPL-family licences.
- Do not write docstrings in prompt style.
- Do not use inline comments; docstrings are the documentation surface.
- Do not nest if/else beyond 2 levels; use guard clauses (cond/unless/when).
- Do not commit without running gate.ros.
- Do not add LLM tells or filler text to README or docstrings.
- Do not use `:use` to import conflicting symbol sets; use `:import-from` for precision.
- Do not redefine the KEYWORD package.
