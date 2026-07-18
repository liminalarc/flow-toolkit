# /flow:validate — UX lens (task completion + friction)

Drive the **intended task** end-to-end and judge whether a user can complete it, and at what friction cost.
Requires actually driving the flow — read `reference/driving.md`. **Read-only: produce findings, never edit.**

## Discover the intent
- The **intent** you were given is the outcome a user should reach. Restate the **happy path** — the minimal
  sequence of steps that reaches it — before driving, so friction is measured against a baseline.
- If the intent is missing or vague, say so — a vague intent produces slop. Don't invent one.

## Drive the task, then score against
**Can the user complete the intent?** (the primary question — a dead end is critical.) Then, friction:
- **Step count** vs the minimal happy path — every extra required step is friction.
- **Navigation / IA clarity** — is the next action obvious, or does the user have to hunt?
- **Discoverability** — is the path to the goal visible, or hidden behind recall/guesswork?
- **Error recovery** — on wrong input, does the app prevent, explain, and let the user recover?
- **Feedback** — system status is visible (loading, success, failure); no silent waits.
- **Accessibility (WCAG)** — keyboard-reachable, sensible focus order, labelled controls, sufficient contrast.

Score against **Nielsen's heuristics** (visibility of status, match to the real world, user control, consistency
& standards, error prevention, recognition over recall, flexibility, minimalist design, error recovery, help)
**merged with the stated intent**.

## Report
Prioritized (critical / high / low). **Distinguish "blocks the intent" (critical) from "adds friction"
(high/low).** Each finding: the **step** (cite the captured screenshot), what's wrong, the heuristic/WCAG rule
it violates, the friction cost (extra steps / dead end), and a concrete suggested direction. Ground every
finding in a step you actually drove. Open with the applicability verdict + a one-line summary.
