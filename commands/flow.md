---
description: "Implement specs, manage backlog, brainstorm — /flow [spec#|--ideas|--add|--clean|description]"
---
# Flow

Conversational, fast development cycle. Implement specs, manage the backlog, brainstorm ideas. Reads `SPECIFICATIONS.md` and `CLAUDE.md` from the current project — works with any project initialized by `/flow-init`.

For rigorous spec work with formal investigation and sign-off requirements, use `/card-spec` → `/card-implement`.

Usage:
- `/flow` — show backlog status and suggest next item
- `/flow 2.84` — implement spec 2.84
- `/flow <description>` — implement described work
- `/flow --ideas` — brainstorm new features through three lenses
- `/flow --add` — co-author a new spec into SPECIFICATIONS.md
- `/flow --clean` — normalize SPECIFICATIONS.md formatting and status

## Instructions

### `/flow` (no args)

Read SPECIFICATIONS.md. Show a concise summary: IN PROGRESS first, then NOT STARTED grouped by phase. Suggest the next item based on phase order. Invite the user to pick or describe work.

If SPECIFICATIONS.md doesn't exist, suggest running `/flow-init` first.

### `/flow --ideas`

Read SPECIFICATIONS.md first to avoid re-suggesting existing specs. Brainstorm through three lenses:

1. **Sellable** — features that move acquisition, retention, or willingness-to-pay
2. **Profitable** — things that reduce cost or unlock a pricing tier
3. **Easy wins** — high-leverage, low-effort improvements a user would notice

3-5 ideas per lens. Offer to capture the best ones with `/flow --add`.

### `/flow --add`

Co-author a new spec. Ask: what is it, who is it for, what does success look like? Draft in standard format:

```
### Spec X.Y — Title
**Status:** NOT STARTED

[One-sentence summary]

**User story:** As a [role], I can [action] so that [outcome].

**Acceptance criteria:**
- [ ] ...
```

Assign the next logical number in the right phase. Show the draft and confirm before writing to SPECIFICATIONS.md.

### `/flow --clean`

Read SPECIFICATIONS.md. Normalize:
- `**Status:**` keyword: `DONE · IN PROGRESS · PARTIAL · NOT STARTED · SUPERSEDED`
- Heading format: `### Spec X.Y — Title`
- No orphaned status lines, duplicate specs, or malformed acceptance criteria

Show a diff before writing.

### `/flow <spec number>` or `/flow <description>`

1. **Understand.** Read SPECIFICATIONS.md for that spec, or restate free-form work and identify affected layers. Ask 1-2 clarifying questions when something is genuinely ambiguous.

   If a free-form description maps to an existing spec, say so. If it's net-new, offer `/flow --add` — before or after building, user's call.

2. **Plan + CHECKPOINT.** Concise plan: thin vertical slices, files/layers touched, test strategy, risks, open questions. **Stop for sign-off before writing any code.**

   For cross-cutting work: the sign-off is where the API contract (endpoint paths, request/response shapes, shared type names) is locked. Include it explicitly so all layers build to the same seam.

3. **Build test-first.** Follow the conventions in CLAUDE.md for this project. Keep commits small; surface decisions as you go.

   - **Single-layer specs**: build inline, test-first, commit per slice.
   - **Cross-cutting specs** (multiple independent layers): spawn one worktree-isolated agent per layer after sign-off. Each agent receives its layer's slice of the plan + the full API contract + a focused prompt scoped to its directory. Run in parallel, merge, verify the seam. Skip layers with no independent work.

4. **Definition of done.**
   - Mark spec `**Status:** DONE` in SPECIFICATIONS.md
   - Update CLAUDE.md if new conventions were introduced
   - Run the project's feature completion checklist (from CLAUDE.md)
   - Hand off with a summary; `/flow-ship` cuts the release when ready

## Rules

- Checkpoint after the plan — never write code before sign-off.
- TDD — test first, per CLAUDE.md.
- Never ship from here. `/flow-ship` is the separate, deliberate release step.
- If the work depends on an unfinished spec, stop and say so.
- Conversational — propose and confirm; don't barrel ahead.
