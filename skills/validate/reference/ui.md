# /flow:validate — UI lens (design-system conformance)

Drive the target screen(s) and judge whether they **conform to the design system**. Per-screen inspection.
Read `reference/driving.md` for how to drive. **Read-only: produce findings, never edit.**

## Discover the design system
From the design-system pointer you were given:
- A **tokens/theme** file, component library, Storybook, or a style-guide URL → treat as the source of truth.
- **"Infer from source"** → derive the implicit system from the component library, CSS/theme tokens, and the
  most-repeated patterns in the frontend.
- **No design system at all** → degrade to internal-consistency + general best practice, and **flag the
  absence** as a finding (you can't score conformance to a system that doesn't exist).

## Review each captured screen
- **Layout & spacing** — grid, alignment, spacing rhythm vs the token scale; no ad-hoc margins/padding.
- **Components** — correct component + variant used (not a bespoke re-implementation of an existing one);
  documented states used.
- **States** — default / hover / focus / disabled / empty / loading / error present and styled to the system.
- **Typography & color** — from the type scale + color tokens; sufficient contrast; no off-palette values.
- **Consistency** — the same pattern rendered the same way across screens; no drift between similar surfaces.

## Report
Prioritized (critical / high / low). Each finding: the **screen** (cite the captured screenshot) + location,
which conformance rule it violates, and a concrete suggested direction. Ground every finding in a screen you
actually captured — no unobserved claims. Open with the applicability verdict + a one-line summary.
