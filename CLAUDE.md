# flow-toolkit — CLAUDE.md

flow-toolkit is a set of Claude Code slash commands + hooks that implement a conversational, spec-driven development workflow. **This repo is the toolkit's own source, and it now uses the toolkit to manage itself** — the specs, hooks, and CLAUDE.md hierarchy here are both the product and the process.

## Architecture

- **The product is prompts + scripts, not an app.** Four parts: `commands/*.md` (the slash commands — pure markdown prompt files, no executable code), `agents/*.md` (sub-agent definitions — same pure-prompt form, dispatched by commands for isolated-context work), `hooks/*.sh` (always-on bash guards + a shared helper), and `install.{sh,ps1}` (distribution).
- **Commands are markdown prompts.** Each `commands/<name>.md` is a self-contained instruction set with YAML front-matter (`description:`). They carry no logic beyond what Claude reads and executes; "testing a command" means running it, not a unit test.
- **Hooks are the deterministic seatbelt.** `flow-spec-guard`, `flow-claude-guard`, `flow-commit-guard`, `flow-session-brief` fire on Claude Code events and enforce file-format invariants with zero tokens. Every hook exits instantly when it doesn't apply (non-spec file, non-commit, no spec model) so it costs nothing in unrelated projects.
- **`flow-preflight.sh` is the single source of truth** for four machine-checkable rules — `git-state`, `resolved` (the deferral `DONE`-gate), `wellformed` (deferral front-matter shape), `autonomy` (resolves `checkpoint`/`auto-build` by precedence). The guards, `/flow`, `/flow-lint`, and `/flow-ship` call it, so a rule is defined once and can't drift.
- **Sub-agents + autonomy.** `/flow` dispatches a `flow-implementer` per task and an independent `flow-verifier` on its diff before integration. A spec's `autonomy:` front-matter (or `.flow-toolkit.json` `autonomy.default`/`autonomy.force`) selects `checkpoint` (default — pause for plan sign-off, verifier advisory) or `auto-build` (no pause, verifier **blocking**: a FAIL gets one retry then escalates). Autonomy gates only the plan-approval pause — never Claude Code permissions.
- **Bash everywhere, incl. Windows.** All hooks are POSIX bash and run through Git Bash on Windows. No Bashism that needs GNU-only tools; keep them portable across macOS/Linux/Git-Bash.
- **Profile-agnostic install.** The installers auto-detect every Claude profile dir (`~/.claude`, `~/.claude-*`, `$CLAUDE_CONFIG_DIR`) and install into each. No account name is ever hardcoded — adding/removing a Claude account must need no installer edit.
- **Distribution = git + copy.** Users `git clone`, run the installer (force-copies `commands/*.md`, `agents/*.md`, and `hooks/*.sh` into each profile, additively merges `hooks/hooks.json` into `settings.json`), and update via `git pull` + reinstall. There is no runtime, no package registry, no server.

## Development Rules

- **Keep the two installers in lockstep.** Any change to what/where files are installed, profile detection, or hook registration must land in **both** `install.sh` and `install.ps1` in the same change — they must behave identically.
- **A rule lives in exactly one place.** Machine-checkable invariants belong in `flow-preflight.sh`, consumed by guards + commands. Never re-implement a check inline in a command or a second hook.
- **Hooks must fail fast and cheap.** Every hook's first job is to detect "does not apply" and exit 0 immediately. Never make a hook that adds latency or noise to unrelated projects.
- **TDD for hook logic.** Any change to hook parsing/validation gets a matching case in `hooks/hooks.test.sh`; run it before committing. CI (`.github/workflows/test.yml`) also runs it on every push/PR to `main`, so `/flow-ship`'s CI gate is real. Command (`.md`) changes are verified by exercising the command, not by unit test.
- **Commands, hooks, and README stay in sync.** The hooks enforce the exact file formats the commands emit. Changing a spec-model format, status vocabulary, or commit convention means updating the command(s), the guard(s), `flow-preflight.sh`, AND the README's documentation of that behavior — together.
- **Thin slices, no premature abstraction.** Ship one coherent capability per spec; don't add config knobs or generalization until a second real use exists.
- **Conventional commits** — `feat:`/`fix:`/`chore:`/`docs:`/`refactor:`/`test:`. An optional leading `[#id]` tag is allowed. The toolkit's own commit guard enforces this here (we eat our own dog food), and `/flow-ship` derives version bumps from commit types — a malformed message silently breaks releases.
- **No silent deferrals.** Never narrow a spec's scope silently. Surface each deferred in-scope item with its reason, get a per-item build-now-or-re-home decision, cross-link it, and record it as a `deferrals:` front-matter entry. Deferrals gate `DONE` mechanically — the commit guard, `/flow-lint`, and `/flow-ship` all block a `DONE` spec with an unresolved deferral.
- **CLAUDE.md line caps apply to us too.** Root ≤ 300 lines, subdirectory ≤ 200. `flow-claude-guard.sh` blocks on breach; move detail into a subdirectory file or delete what's derivable from the source.

## Spec Status Vocabulary

`NOT STARTED · IN PROGRESS · PARTIAL · DONE · SUPERSEDED` — exactly one per index entry. Status lives only in `SPECIFICATIONS.md` (local mode). Never write a status field into a `specs/<id>.md`.

## Feature Completion Checklist

Before marking a spec `DONE`:

- [ ] **Deferrals reconciled** — every in-scope item was built or re-homed by explicit decision, cross-linked, and recorded in the spec's `deferrals:` front-matter with a resolved `to` (machine-checked; no silent scope narrowing).
- [ ] **Hook tests pass** — if hook logic changed, `bash hooks/hooks.test.sh` is green and a case covers the new behavior.
- [ ] **Installers verified in lockstep** — if install/registration behavior changed, both `install.sh` and `install.ps1` were updated and a dry install was exercised.
- [ ] **Smoke-test the changed behavior end-to-end** — actually run the affected command or hook against a scratch spec/repo and confirm the real behavior, not just that files parse. Show a brief pass/fail checklist.
- [ ] **README + docs updated** — any user-visible change in command behavior, hook rules, install steps, or file formats is reflected in `README.md`.
- [ ] **Index status updated + detail archived** — set status in `SPECIFICATIONS.md`; `/flow` moves the entry to `## Archive` and the detail file to `specs/archive/<id>.md`.
- [ ] **`specs/<id>.md` Progress/Decisions updated**; CLAUDE.md patterns updated if a new convention was introduced.

## Project Structure

```
flow-toolkit/
├── .github/workflows/  # CI — runs hooks.test.sh on push/PR to main
├── commands/            # The 7 slash commands — markdown prompt files (see commands/CLAUDE.md)
│   ├── flow.md          #   implement specs, manage backlog, brainstorm
│   ├── flow-init.md     #   bootstrap/adopt a project
│   ├── flow-hunt.md     #   opportunity hunting via persona panel
│   ├── flow-ship.md     #   cut a release
│   ├── flow-review.md   #   audit docs/UX/marketing/product
│   ├── flow-pr.md       #   spec-aware PR/diff review
│   └── flow-lint.md     #   audit CLAUDE.md hierarchy + spec integrity
├── agents/              # Sub-agent definitions (pure-prompt md, dispatched by commands)
│   ├── flow-implementer.md  #   builds one task to its local AC (write, worktree-isolated when parallel)
│   └── flow-verifier.md     #   checks an implementer's diff vs the task AC (read-only, judges never fixes)
├── hooks/               # Always-on bash guards + shared helper (see hooks/CLAUDE.md)
│   ├── flow-spec-guard.sh
│   ├── flow-claude-guard.sh
│   ├── flow-commit-guard.sh
│   ├── flow-session-brief.sh
│   ├── flow-preflight.sh    # shared single-source-of-truth checks
│   ├── hooks.json           # event → hook registrations (merged into settings.json)
│   └── hooks.test.sh        # bash test harness for hook parsing/validation
├── install.sh           # Mac/Linux installer — must mirror install.ps1
├── install.ps1          # Windows installer — must mirror install.sh
├── README.md            # The user-facing manual — the front door
├── SPECIFICATIONS.md    # The backlog index (status = single source of truth)
└── specs/               # One detail file per spec (flat specs/<id>.md, or a dir specs/<id>/ = orchestrator + <id>.T<n> task files); specs/archive/ for DONE/SUPERSEDED
```

## Releasing

There is no deploy target. A release is a **git tag on GitHub**; users pick it up via `git pull` + reinstall. `/flow-ship` proposes the version from conventional-commit history, confirms with you, and tags. Keep `README.md`'s command docs current before tagging — the README is the release surface.

## See Also

- `commands/CLAUDE.md` — conventions for authoring the slash-command prompt files.
- `hooks/CLAUDE.md` — conventions for the bash hooks and the shared preflight helper.
