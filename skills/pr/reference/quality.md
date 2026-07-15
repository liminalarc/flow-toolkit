# flow:pr — quality dimension (correctness + clean code)

Audit the changed code for correctness and clean-code quality against *this project's* standards. **Read-only: produce findings, do not edit.**

## Discover
Read the diff (the refs/command you were given). Read the `CLAUDE.md` (root + any subdirectory files covering the changed paths) for the conventions this diff must follow — testing stack, named patterns, code style. Read enough surrounding code to judge consistency, not just the hunks.

## Review
**Correctness**
- Bugs in the changed code: unhandled edge cases, off-by-one, race conditions, broken error paths, null/empty handling.
- Quick security pass on changed code: injection, missing authorization checks, secrets in the diff, unsafe deserialization.
- Only report issues *in or caused by* the diff — pre-existing problems are out of scope (note separately only if severe).

**Clean code**
- Naming reveals intent; functions do one thing and stay small; no duplication introduced (or near-duplication of existing code that should have been reused).
- No dead code, commented-out blocks, debug leftovers, or magic values that deserve names.
- Comments explain *why*, not *what*; no redundant narration.
- Consistency: does the new code match the named patterns in `CLAUDE.md` and the idioms of surrounding files? A locally-clean function in a foreign style is still a finding. If project rules conflict with general principles, the project's rules win — flag the conflict.

## Report
Prioritized findings (BLOCKER / SHOULD FIX / NIT), each with `file:line`, what's wrong, and the concrete fix. "Consider improving naming" is not a finding — give the location and the fix. Hand findings back for synthesis — do not write changes.
