# Progress Tracker

Update this file after every meaningful implementation change.

## Current Phase

**Phase 0 — Project Foundation**

Template hardening: making the execution protocol enforceable so AI agents actually follow it.

## Current Goal

Fix the template so agents comply with the workflow: auto-loaded entry point, hard gates,
unambiguous rules, and instant project understanding via the three living context files.

## Completed

- **Root `AGENTS.md` added** — auto-loaded by agents; contains the 3 non-negotiable rules, file reading order, and failure consequences so agents see the protocol even if they never open `Agent.md`.
- **`Agent.md` rewritten for enforceability** — mandatory routine (read context → classify → load skill → design-first → implement → sync context → verify), required response status block, hard approval gate in the design workflow, context sync protocol, expanded pre-exit checks.
- **`context/flow.md` added** — Mermaid architecture/user-flow/request-response diagrams, function call maps, route + API tables, mandatory update protocol.
- **`context/decision.md` added** — append-only ADR-style decision log with template, index, and update rules.
- **`Scaffold.py` removed** — npm/create-app provides boilerplate; the `folder-structure` skill's canonical trees are now the source of truth, materialized by hand.
- **References updated** — `SKILLS.md`, `README.md`, `.agents/AGENTS.md`, `.agents/folder-structure/SKILL.md`, `context/ai-workflow-rules.md` all updated to remove Scaffold.py and point to the canonical trees + new context files.
- **Skills bootstrap installed (2026-09-24)** — ran `python Skills.py --yes`: npm/npx verified (11.19.1), `package.json` auto-created (node sidecar in Flutter repo), 36 skills installed into `.agents/skills/` (8 GSAP + 1 hallmark + 13 taste + 13 emilkowalski + 1 impeccable engine). Then ran `specify init . --integration opencode --force --non-interactive --script ps` (specify-cli 1.0.5.dev0 already present via uv 0.12.5): created `.specify/`, `.opencode/`, `.codex/`, speckit workflow commands available (`/speckit.constitution`, `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`). Note: `uv tool install specify-cli --from git+...@latest` fails (`@latest` is not a git ref) — used pre-installed CLI instead.

## Next Up

1. Decide whether the `folder-structure` skill trees need simplification (user wants "concise and clear, senior-engineer hierarchy")
2. Fill the template `context/*.md` placeholders per project
3. Run `/speckit.constitution` to ratify project principles (constitution.md is still template placeholders)

## Open Questions

- `package.json` was auto-created by Skills.py inside a Flutter (`shop`) repo — keep as node sidecar for npx skills, or gitignore? Currently untracked.
- `.agents/`, `.specify/`, `.opencode/`, `.codex/` are all untracked — decide what to commit vs gitignore (agent credential-leak warning from specify init).

## Architecture Decisions

See `context/decision.md` for full decision records.

