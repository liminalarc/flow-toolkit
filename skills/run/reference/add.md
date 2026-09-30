# flow — co-author a new spec (`/flow:run --add`)

Read `reference/authoring.md` alongside this for the templates and terseness rules.

Ask: what is it, who is it for, what does success look like? Then create **both** the index entry and the detail file:

1. **Index entry** —
   - local: add a line under the right phase in `SPECIFICATIONS.md`: `- **<id>** <Title> — \`NOT STARTED\` — [detail](specs/<id>-<slug>.md)`. Assign the next logical `Phase.Spec` number.
   - ado: create the work item (confirm the drafted fields first), then use the returned `#NNNNNN` as the id.
2. **Filename** — derive the slug from the Title (local) or `System.Title` (ado) per the slugify rule in `reference/authoring.md`, unless `.flow/config.yml` sets `flow.spec_filename: id` (then use the bare id). The link in the index must point at the path you actually write.
3. **Detail file** — write `specs/<id>-<slug>.md` from the detail-file template in `reference/authoring.md` (Problem, Value user story, Scope, Acceptance criteria populated; Plan/Decisions/Verification/Progress scaffolded). If the spec is already big enough to warrant breakout (the guideline in `authoring.md` — ≥3 tasks or a task with its own AC), create the **directory** form instead: the orchestrator `specs/<id>-<slug>/<id>-<slug>.md` plus its first task files `specs/<id>-<slug>/<id>-<slug>.T<n>-<context>.md`, each task's suffix slugged from its own title (task-file template in `authoring.md`). The index line links to the orchestrator.

### Cross-repo footprint (1.28) — only when `flow.related_repos` is declared

A project with no `related_repos` gets **no extra question**: skip this section entirely.

Otherwise ask which of the declared repos this item touches. One repo (just this one) ⇒ author exactly as above and write no footprint keys. Two or more ⇒ the item is **one work item with a slice per repo**:

- **Write the footprint into every slice** — `repos:` (the same set in each), `work_item:` (the same handle in each; omit it to default to this repo's `id:` only when the item is single-repo), and `canonical_repo:` (the **same value** in each — the repo holding the full Problem/Scope/AC; the others are slices that reference it).
- **This repo's slice** is authored normally. Run `flow-preflight.sh repos <detail.md>` on it before you finish — it catches an undeclared name or a missing `canonical_repo` on the spot.
- **Each sibling slice** — scaffold it only when that sibling is **reachable** (`local_path` set and readable), **flow-managed**, on the **same backend**, and **already declaring this repo in its own `flow.related_repos`**. Otherwise emit copy-paste instructions and write nothing there — a slice scaffolded into a repo that has not declared the footprint is rejected by that repo's own guard the first time it is saved, so writing it would hand someone a broken file.

**Scaffolding a sibling is the one sanctioned cross-repo write (1.24 D7), and it is tightly bounded.** Only when the human asked for it in this turn:

- **Create** the slice detail file at a path that does not exist. Never overwrite.
- **Append exactly one line** to the sibling's index. Never edit or reorder an existing line.
- **Touch nothing else** in that tree.
- The sibling's id is **allocated from the sibling's own index**, never copied from here: take **max + 1** within its highest existing phase, counting `## Archive` entries (ids are never reused) and ignoring non-numeric ids when taking the max. If a max cannot be computed — no numeric id anywhere, or that phase holds only non-numeric ids — **ask** rather than guessing. The slices share a `work_item:`, not an id, because each repo numbers its own backlog.

**ado only — mirror the footprint to the card.** Add one `repo:<name>` tag per repo in `repos:`. Touch no other tag: `slice-done:<name>` tags belong to the done-step and must survive untouched.

Show the draft (index line + detail) and confirm before writing.

**Offer a spec review at that confirm step** — one `flow:flow-spec-reviewer` on the draft (rubric: `reference/spec-review.md` **within this skill's directory**, passed absolute), which judges INVEST on the spec and SMART on each acceptance criterion and returns `PASS`/`CONCERNS`. Offer it; never impose it. `--add` is the cheapest, most frequent action in flow and idea capture shouldn't pay an agent round-trip it didn't ask for — on decline, write exactly as you would have. (The review is **mandatory** on the build path, `reference/implement.md` §2, where the stakes are highest and the cost is already amortized.)

Author to the terseness rules in `reference/authoring.md` — one job per section, shortest lossless form, append-only one-line Progress log. After any write the spec guard re-validates the file and re-checks the budget on save.
