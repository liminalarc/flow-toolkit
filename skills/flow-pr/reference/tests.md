# flow-pr — tests dimension

Audit test coverage and quality for the diff, and run the suite. **Read-only: produce findings, do not edit** — but you *may* run the test suite (you have Bash).

## Discover
Read the diff (the refs/command you were given). Read `CLAUDE.md`/`README.md` for the project's test command and testing stack.

## Review
- **TDD check** — does every behavior change in the diff have a corresponding test change? List new/changed behaviors that ship untested.
- **Test quality** — do the tests assert behavior (inputs → outcomes) rather than implementation details? Do they cover the unhappy paths the spec's criteria imply?
- **Run the suite** — run the project's test command and report results. If coverage tooling is configured, run it and report coverage on the **changed files only** (whole-repo coverage is noise here). A failing suite is a BLOCKER.

## Report
Prioritized findings (BLOCKER / SHOULD FIX / NIT), each with location and concrete fix. Include the **test command you ran and its result** (or "none runnable — <why>"). Hand findings back for synthesis — do not write changes.
