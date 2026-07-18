# /flow:validate — how to drive (shared by both lenses)

How the `flow-ux-validator` agent runs a real app and captures evidence. Loaded only on the driving path.
**Playwright-first, vision fallback, applicability-gated.** One screen/flow per run.

## 1. Find how to run the app
Discover the run/dev command, in order:
- `CLAUDE.md` / `README.md` run or dev section.
- `package.json` `scripts` (`dev`, `start`), or the framework's convention (Vite/Next/CRA → dev server;
  a static `index.html` → serve it).
- The dev-server **URL + port** (from the script output or config).

## 2. Applicability gate (never fabricate)
Return `NOT APPLICABLE — <reason>` and stop when **any** holds:
- No runnable UI (backend-only / library / CLI / infra repo — e.g. a platform-engineering repo).
- No discoverable run/dev command.
- No driver available: Playwright not installed/installable **and** no vision/computer-use fallback.

A clean N/A is a correct result. A critique of an app you did not drive is a defect.

## 3. Drive — Playwright first
- Prefer an installed Playwright (`npx playwright` / `node_modules/.bin/playwright`); write a **throwaway**
  script to the **scratch dir** that launches a browser (headless ok), navigates to the target, performs the
  interaction steps, and screenshots each state into the scratch dir. Never write under the project tree.
- **UI lens** — navigate to the screen(s); screenshot the reachable states (default, empty, loading, error,
  focus/hover where drivable).
- **UX lens** — complete the **intended task** end-to-end to the stated intent; screenshot each step and
  record the step count + any dead ends / error paths.
- Runs under Git Bash on Windows — use `npx`/`node`; forward slashes.

## 4. Vision / computer-use fallback
If Playwright is unavailable but a browser/computer-use/screenshot capability exists, drive via that and
capture the same evidence. **Note the determinism caveat** in your report — vision runs are less repeatable
than scripted Playwright.

## 5. Cleanup
Kill any app/browser process you started. Scratch screenshots + scripts are throwaway — they're your evidence
for this run, not artifacts to commit.
