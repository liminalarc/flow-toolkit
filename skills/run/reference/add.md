# flow — co-author a new spec (`/flow:run --add`)

Read `reference/authoring.md` alongside this for the templates and terseness rules.

Ask: what is it, who is it for, what does success look like? Then create **both** the index entry and the detail file:

1. **Index entry** —
   - local: add a line under the right phase in `SPECIFICATIONS.md`: `- **<id>** <Title> — \`NOT STARTED\` — [detail](specs/<id>-<slug>.md)`. Assign the next logical `Phase.Spec` number.
   - ado: create the work item (confirm the drafted fields first), then use the returned `#NNNNNN` as the id.
2. **Filename** — derive the slug from the Title (local) or `System.Title` (ado) per the slugify rule in `reference/authoring.md`, unless `.flow/config.yml` sets `flow.spec_filename: id` (then use the bare id). The link in the index must point at the path you actually write.
3. **Detail file** — write `specs/<id>-<slug>.md` from the detail-file template in `reference/authoring.md` (Problem, Value user story, Scope, Acceptance criteria populated; Plan/Decisions/Verification/Progress scaffolded). If the spec is already big enough to warrant breakout (the guideline in `authoring.md` — ≥3 tasks or a task with its own AC), create the **directory** form instead: the orchestrator `specs/<id>-<slug>/<id>-<slug>.md` plus its first task files `specs/<id>-<slug>/<id>-<slug>.T<n>-<context>.md`, each task's suffix slugged from its own title (task-file template in `authoring.md`). The index line links to the orchestrator.

Show the draft (index line + detail) and confirm before writing.

Author to the terseness rules in `reference/authoring.md` — one job per section, shortest lossless form, append-only one-line Progress log. After any write the spec guard re-validates the file and re-checks the budget on save.
