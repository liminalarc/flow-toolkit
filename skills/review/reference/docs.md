# flow:review — docs lens

Audit the project's documentation for accuracy, completeness, and runnability. **Read-only: produce findings, do not edit** — the main thread applies any fixes on confirmation.

## Discover
Find all docs: README files, the CLAUDE.md hierarchy, `SPECIFICATIONS.md`, a `docs/` directory, API docs, setup guides.

## Review
For each doc — Is it accurate against the current code/architecture? Are setup steps runnable? What would a new contributor need that's missing? What's stale?

## Report
Prioritized findings (critical / high / low). For each: the doc + location, the problem, and a concrete suggested fix. Hand the findings back for synthesis — do not write changes.
