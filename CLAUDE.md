# flow-toolkit — CLAUDE.md

flow-toolkit is a set of Claude Code slash commands + hooks that implement a conversational, spec-driven development workflow. **This repo is the toolkit's own source, and it now uses the toolkit to manage itself** — the specs, hooks, and CLAUDE.md hierarchy here are both the product and the process.

## Architecture

- **The product is prompts + scripts, not an app.** Parts: `commands/*.md` (thin slash commands — pure markdown prompt files, no executable code), `skills/<name>/` (skills — `SKILL.md` + on-demand `reference/*` for heavy, path-dependent flows), `agents/*.md` (sub-agent definitions — same pure-prompt form, dispatched by skills for isolated-context work), `hooks/*.sh` (always-on bash guards + a shared helper), `.claude-plugin/` (the `plugin.json` + `marketplace.json` manifests — the primary distribution), and `install.{sh,ps1}` (the fallback installer). Everything is namespaced under the `flow` plugin — `/flow:run`, `/flow:hunt`, etc.
- **Commands are markdown prompts.** Each `commands/<name>.md` is a self-contained instruction set with YAML front-matter (`description:`). They carry no logic beyond what Claude reads and executes; "testing a command" means running it, not a unit test.
- **Hooks are the deterministic seatbelt.** `flow-spec-guard`, `flow-claude-guard`, `flow-commit-guard`, `flow-session-brief` fire on Claude Code events and enforce file-format invariants with zero tokens. Every hook exits instantly when it doesn't apply (non-spec file, non-commit, no spec model) so it costs nothing in unrelated projects.
- **`flow-preflight.sh` is the single source of truth** for four machine-checkable rules — `git-state`, `resolved` (the deferral `DONE`-gate), `wellformed` (deferral front-matter shape), `autonomy` (resolves `checkpoint`/`auto-build` by precedence). The guards, `/flow:run`, `/flow:lint`, and `/flow:ship` call it, so a rule is defined once and can't drift.
- **Skills = progressive disclosure.** A heavy, path-dependent command becomes a skill when only part of its prompt is needed per run: `SKILL.md` is the always-loaded entry, `reference/*` files load only on the path that needs them. Five so far: `run` (routes each path — implement/`--add`/`--ideas`/`--clean`/`--condense` — to its own `reference/*`, dispatching `flow-implementer`/`flow-verifier` on the build path), `hunt` (fans one `flow-researcher` per research dimension), `review` (four lenses via parallel `flow-reviewer` agents), `pr` (three dimensions via parallel `flow-pr-reviewer` agents), and `validate` (drives the running app, one `flow-ux-validator` per UI/UX lens — **serial**, since driving a live app is stateful). Thin, deliberate-only commands (`init`, `lint`, `ship`) stay commands. All invoke under the `flow` plugin namespace (`/flow:run`, `/flow:hunt`, …); the redundant `flow-` prefix was dropped from skill/command names since the namespace carries it.
- **Sub-agents + autonomy.** `/flow:run` dispatches a `flow-implementer` per task and an independent `flow-verifier` on its diff before integration. A spec's `autonomy:` front-matter (or `.flow-toolkit.json` `autonomy.default`/`autonomy.force`) selects `checkpoint` (default — pause for plan sign-off, verifier advisory) or `auto-build` (no pause, verifier **blocking**: a FAIL gets one retry then escalates). Autonomy gates only the plan-approval pause — never Claude Code permissions.
- **Bash everywhere, incl. Windows.** All hooks are POSIX bash and run through Git Bash on Windows. No Bashism that needs GNU-only tools; keep them portable across macOS/Linux/Git-Bash.
- **Profile-agnostic install.** The installers auto-detect every Claude profile dir (`~/.claude`, `~/.claude-*`, `$CLAUDE_CONFIG_DIR`) and install into each. No account name is ever hardcoded — adding/removing a Claude account must need no installer edit.
- **Distribution = plugin, installer as fallback.** Primary: the `flow` Claude Code plugin (`.claude-plugin/{plugin.json,marketplace.json}`) — `/plugin install flow@flow-toolkit`, versioned updates via `/plugin update`, installed per-profile. The plugin bundles commands/skills/agents AND registers the hooks (`hooks/hooks.json` referencing `${CLAUDE_PLUGIN_ROOT}`). Fallback: `install.{sh,ps1}` force-copies everything as **bare** names + registers hooks by substituting that same `${CLAUDE_PLUGIN_ROOT}/hooks` prefix — retired only criterion-gated (1.2 D5: plugin registers hooks reliably across profiles AND all in-use projects migrated). No runtime, no server.

## Development Rules

- **Keep the shell/PowerShell script pairs in lockstep.** Any change to what/where files are installed, profile detection, or hook registration must land in **both** `install.sh` and `install.ps1` (and likewise `uninstall.sh`/`uninstall.ps1`) in the same change — each pair must behave identically.
- **A rule lives in exactly one place.** Machine-checkable invariants belong in `flow-preflight.sh`, consumed by guards + commands. Never re-implement a check inline in a command or a second hook.
- **Hooks must fail fast and cheap.** Every hook's first job is to detect "does not apply" and exit 0 immediately. Never make a hook that adds latency or noise to unrelated projects.
- **TDD for hook logic.** Any change to hook parsing/validation gets a matching case in `hooks/hooks.test.sh`; run it before committing. CI (`.github/workflows/test.yml`) also runs it on every push/PR to `main`, so `/flow:ship`'s CI gate is real. Command (`.md`) changes are verified by exercising the command, not by unit test.
- **Commands, hooks, and README stay in sync.** The hooks enforce the exact file formats the commands emit. Changing a spec-model format, status vocabulary, or commit convention means updating the command(s), the guard(s), `flow-preflight.sh`, AND the README's documentation of that behavior — together.
- **Thin slices, no premature abstraction.** Ship one coherent capability per spec; don't add config knobs or generalization until a second real use exists.
- **Conventional commits** — `feat:`/`fix:`/`chore:`/`docs:`/`refactor:`/`test:`. An optional leading `[id]` spec tag is allowed (e.g. `[1.12] feat: …`) — **no `#`**, which would collide with GitHub's `#N` issue/PR autolink and mis-link every dotted id to issue 1. The toolkit's own commit guard enforces this here (we eat our own dog food), and `/flow:ship` derives version bumps from commit types — a malformed message silently breaks releases.
- **No silent deferrals.** Never narrow a spec's scope silently. Surface each deferred in-scope item with its reason, get a per-item build-now-or-re-home decision, cross-link it, and record it as a `deferrals:` front-matter entry. Deferrals gate `DONE` mechanically — the commit guard, `/flow:lint`, and `/flow:ship` all block a `DONE` spec with an unresolved deferral.
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
- [ ] **Index status updated + detail archived** — set status in `SPECIFICATIONS.md`; `/flow:run` moves the entry to `## Archive` and the detail file to `specs/archive/<id>.md`.
- [ ] **`specs/<id>.md` Progress/Decisions updated**; CLAUDE.md patterns updated if a new convention was introduced.

## Project Structure

```
flow-toolkit/
├── .github/workflows/  # CI — runs hooks.test.sh on push/PR to main
├── .claude-plugin/      # Plugin distribution — plugin.json (name: flow) + marketplace.json
├── commands/            # Thin slash commands — markdown prompt files (see docs/authoring-commands.md)
│   ├── init.md          #   bootstrap/adopt a project        → /flow:init
│   ├── ship.md          #   cut a release                     → /flow:ship
│   └── lint.md          #   audit CLAUDE.md hierarchy + specs → /flow:lint
├── skills/              # Skills — SKILL.md + on-demand reference/* (namespaced /flow:<name>)
│   ├── run/             #   implement specs, manage backlog, brainstorm — routes each path to its reference/*
│   ├── hunt/            #   opportunity hunting — fans one flow-researcher per dimension (persona-aware)
│   ├── review/          #   audit docs/UX/marketing/product via parallel flow-reviewer agents
│   ├── pr/              #   spec-aware PR/diff review across dimensions via parallel flow-pr-reviewer agents
│   └── validate/        #   live UI/UX validation — drives the running app via serial flow-ux-validator agents
├── agents/              # Sub-agent definitions (pure-prompt md, dispatched by skills)
│   ├── flow-implementer.md  #   builds one task to its local AC (write, worktree-isolated when parallel)
│   ├── flow-verifier.md     #   checks an implementer's diff vs the task AC (read-only, judges never fixes)
│   ├── flow-reviewer.md     #   audits one review lens vs its rubric (read-only, never edits)
│   ├── flow-pr-reviewer.md  #   audits one pr dimension vs its rubric on the diff (read-only, never edits)
│   ├── flow-researcher.md   #   researches one hunt dimension, persona-aware (read-only, never edits)
│   └── flow-ux-validator.md #   drives a running app, scores one UI/UX lens vs a rubric (read-only, never fixes)
├── hooks/               # Always-on bash guards + shared helper (see hooks/CLAUDE.md)
│   ├── flow-spec-guard.sh
│   ├── flow-claude-guard.sh
│   ├── flow-commit-guard.sh
│   ├── flow-session-brief.sh
│   ├── flow-preflight.sh    # shared single-source-of-truth checks
│   ├── hooks.json           # event → hook registrations (${CLAUDE_PLUGIN_ROOT}; installer substitutes for fallback)
│   └── hooks.test.sh        # bash test harness for hook parsing/validation
├── docs/                # how-it-works.md (diagrams), guide.md (usage manual), architecture.md (ADR), authoring-commands.md — dev docs (not shipped as commands)
├── install.sh           # Fallback installer (Mac/Linux) — must mirror install.ps1
├── install.ps1          # Fallback installer (Windows) — must mirror install.sh
├── uninstall.sh         # Purge a manual install (plugin-only migration) — mirrors uninstall.ps1
├── uninstall.ps1        # Purge a manual install (plugin-only migration) — mirrors uninstall.sh
├── README.md            # The user-facing manual — the front door
├── SPECIFICATIONS.md    # The backlog index (status = single source of truth)
└── specs/               # One detail file per spec (flat specs/<id>.md, or a dir specs/<id>/ = orchestrator + <id>.T<n> task files); specs/archive/ for DONE/SUPERSEDED
```

## Releasing

There is no deploy target. A release is a **git tag on GitHub**; plugin users pick it up via `/plugin update` (fallback users via `git pull` + reinstall). `/flow:ship` proposes the version from conventional-commit history, confirms with you, and tags — and should bump `.claude-plugin/plugin.json`'s `version` to match, since that field drives plugin updates. Keep `README.md`'s command docs current before tagging — the README is the release surface.

## See Also

- `README.md` — the user-facing front door (install + quick start); links to the two docs below.
- `docs/guide.md` — the full usage manual: every command/skill/agent/hook with examples + agent-dispatch walkthroughs.
- `docs/how-it-works.md` — five Mermaid diagrams of the core systems (dev cycle, spec model, hooks, install, agent dispatch).
- `docs/architecture.md` — the design decision record (ratified by spec 1.2).
- `docs/authoring-commands.md` — conventions for authoring the slash-command prompt files.
- `hooks/CLAUDE.md` — conventions for the bash hooks and the shared preflight helper.
