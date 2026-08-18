# flow — spec review rubric (INVEST + SMART)

Loaded by the `flow-spec-reviewer` agent. Judgment only — this rubric never checks file shape, and it never edits.

## Discover

Read the draft spec (orchestrator + any task files), `CLAUDE.md` for the project's conventions, the index for what else is in flight, and `specs/archive/` for decisions already settled. For an `implement.md` §2 review the "spec" is the drafted detail file in the plan, not yet on disk.

## Review — two altitudes

Judge the **spec** on INVEST and **each acceptance criterion** on SMART. Applying either at the wrong altitude produces noise: INVEST asks whether this is one good story, SMART asks whether one line is provable.

### INVEST — on the spec

| Letter | Ask | A violation looks like |
|---|---|---|
| **I**ndependent | Can this ship without unfinished work landing first? | Scope depends on a spec still `NOT STARTED`, with no stated seam or fallback. |
| **N**egotiable | Does Scope state an outcome, or dictate an implementation? | "Add a `useSpecCache` React hook" where the outcome is "re-opening a spec doesn't re-read it". |
| **V**aluable | Is the Value benefit an outcome for someone, or a restatement of Problem? | "…so that the spec has a reviewer" — the capability repeated, no benefit. |
| **E**stimable | Is anything unknown enough that the work can't be sized? | "Support every tracker backend" with no list and no spike. |
| **S**mall | Is this one coherent capability? | Three: an agent, a config format, and a migration — each with its own AC cluster. |
| **T**estable | Does every criterion state how it's proven? | An AC list where several lines stop at the behavior and name no proof. |

### SMART — per acceptance criterion

| Letter | Ask | A violation looks like |
|---|---|---|
| **S**pecific | One observable behavior, not a bundle? | "The agent works correctly and handles errors." |
| **M**easurable | Does the `— <how proven>` half name a real test, command, or observation? | "— proven by manual review" / no proof half at all. |
| **A**chievable | Within this spec's stated Scope and this project's stack? | A criterion needing a service the repo doesn't have. |
| **R**elevant | Does it trace to the Value story? | A criterion about log formatting in a spec about spec review. |
| **T**ime-bound | Provable at done-time, not "eventually"? | "— proven once teams adopt it" / "— monitored over the next quarter". |

### Prior art

Grep `specs/archive/` for a decision this spec contradicts or re-litigates. Cite the archived spec's id and the colliding Decisions line. A spec that reverses a past decision isn't wrong — but it must say so deliberately, not by accident.

## Out of scope — do not report these

Structure is owned elsewhere and re-reporting it here would double-report every finding. **`/flow:lint --specs` Step 3** owns: index/detail correspondence, one file per id, `id:` matching the filename stem, index link accuracy, descriptive-filename nudges, `status:` in a detail file, task-file local-AC presence, required-section presence, Value-is-a-user-story shape, the line budget, DONE-vs-unchecked-AC, and `deferrals:` well-formedness + resolution. **`flow-spec-guard.sh`** owns the same invariants at save time. Say nothing about any of them — including a missing section or an over-budget file. Judge only what a parser cannot.

## Report

Return the structured verdict in the agent's contract. `CONCERNS` when any INVEST letter or any criterion is WEAK; `PASS` otherwise. Every finding names the section or criterion it lands on and states what would fix it — a finding without a fix is an opinion.
