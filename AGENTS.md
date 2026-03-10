# AGENTS.md

This file defines the default operating contract for Codex-style agents in this
repository.
Use it together with [CONTRIBUTING.md](CONTRIBUTING.md) and the developer
guide.

## Goals

- Deliver minimal, correct changes with explicit validation evidence.
- Keep context compact and assumptions visible.
- Prefer deterministic commands and reproducible checks over intuition.

## Repository map

- `crates/`: Rust engine, adapters, and shared crates.
- `nautilus_trader/`, `python/`: Python package and bindings.
- `tests/`: Python and integration tests.
- `docs/`: User and developer documentation.
- `.github/`: CI workflows and contribution automation.

## Required execution loop

1. Clarify the requested outcome, constraints, and non-goals.
2. Capture a baseline signal before editing (failing test, missing file, or
   current behavior).
3. Plan small, reversible edits and touch only files needed for the ticket.
4. Implement in small steps, keeping behavior changes explicit.
5. Run targeted validation commands for changed areas.
6. Report exactly what changed, why, and how it was validated.

## Validation defaults

- Docs-only changes:
  - `pre-commit run markdownlint --files <changed-docs>`
- Python behavior changes:
  - `make pytest` or narrowed `pytest` command for touched modules.
- Rust behavior changes:
  - Targeted `cargo test -p <crate>` (or project `make` target when required).
- Cross-cutting or risky changes:
  - `make pre-flight` when toolchain and time budget allow.

If a command cannot run in the current environment, record the blocker and
continue with the strongest available local proof.

## Editing guardrails

- Do not rewrite unrelated files.
- Do not add broad refactors unless the ticket requires them.
- Keep docs and code consistent in the same change.
- Prefer ASCII in new files unless existing files require Unicode.
- Never claim success without command evidence.

## Harness engineering principles

- Externalize intent in durable artifacts (`AGENTS.md`, issue workpad, docs).
- Keep prompts and plans declarative; avoid ambiguous goals.
- Use short feedback loops and verify after each milestone.
- Capture assumptions and risks where reviewers can see them.
- Reduce entropy: fewer touched files, smaller diffs, tighter validation scope.

## Canonical references

- [Contribution guide](CONTRIBUTING.md)
- [Developer guide index](docs/developer_guide/index.md)
- [Testing guide](docs/developer_guide/testing.md)
- [Docs style guide](docs/developer_guide/docs.md)
- [Codex workflow guide](docs/developer_guide/codex.md)
