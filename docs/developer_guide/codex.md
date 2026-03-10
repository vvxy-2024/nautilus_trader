# Codex workflow

This guide explains how Codex-based contributors should operate in this
repository.
It follows OpenAI's Harness Engineering principles: externalize intent,
shorten feedback loops, and require evidence before completion claims.

## Canonical artifacts

- `AGENTS.md`: repository operating contract and default validation gates.
- `WORKFLOW.md`: unattended Linear orchestration workflow template.
- `.codex/skills/`: reusable skill playbooks for commit/push/pull/land/debug and
  Linear operations.

These artifacts should stay consistent with each other.
If one file changes behavior or terminology, update the related docs in the same
PR.

## Standard execution loop

1. Confirm scope and constraints from the issue.
2. Capture a deterministic baseline signal before editing.
3. Plan minimal edits and execute in small, reversible steps.
4. Run targeted validation for touched areas.
5. Report concrete evidence (commands and outcomes) in the issue workpad.

This loop applies to docs changes and behavior changes.

## Working with Linear tickets

- Keep one active `## Codex Workpad` comment per issue.
- Keep `Plan`, `Acceptance Criteria`, `Validation`, and `Notes` current after
  each milestone.
- Treat ticket-authored `Validation`, `Test Plan`, and `Testing` sections as
  required acceptance inputs.
- Before moving an issue to review, complete a PR feedback sweep covering
  top-level comments, inline review comments, and review summaries.

## Validation expectations

Use `AGENTS.md` defaults unless ticket requirements are stricter:

- Docs only: `pre-commit run markdownlint --files <changed-docs>`.
- Python behavior: targeted `pytest` or `make pytest`.
- Rust behavior: targeted `cargo test -p <crate>`.
- Cross-cutting changes: `make pre-flight` when practical.

If a required command cannot run locally, capture the blocker and provide the
strongest available local proof.

## Updating skills and workflow templates

When changing `.codex/skills/*` or `WORKFLOW.md`:

- Keep examples repository-appropriate (default branch, test commands, paths).
- Remove secrets and machine-specific credentials.
- Prefer explicit command examples over ambiguous prose.
- Validate related markdown files in the same PR.

## References

- [AGENTS.md](../../AGENTS.md)
- [Contributing guide](../../CONTRIBUTING.md)
- [Developer guide index](index.md)
- [Harness Engineering](https://openai.com/index/harness-engineering/)
