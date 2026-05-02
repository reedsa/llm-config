# Global Gemini CLI Instructions

These rules apply to every session. Project-level GEMINI.md files (which
typically import the project's CLAUDE.md) are concatenated with this file —
project-specific rules always take precedence where they conflict.

## Before starting any task
If a GEMINI.md or CLAUDE.md exists in the project root, read it before doing
anything. It is the authoritative source of conventions and requirements for
that codebase.

## Code changes
- Make focused, minimal changes. Fix the thing asked for; don't clean up
  surrounding code, refactor unrelated functions, or add unrequested features.
- Follow the conventions already in the file you're editing — naming, spacing,
  patterns — over any general best practice.
- Don't add comments that explain what the code does. Only add a comment when
  the *why* is non-obvious: a hidden constraint, a workaround, a subtle invariant.

## Planning
On any task with more than two distinct changes, list your planned steps before
writing code. Mark steps complete as you finish them.

## Commits
- Short imperative subject line (under 72 chars).
- Follow whatever prefix convention the project uses (check `git log`).
- Never commit secrets, credentials, or `.env` files.

## Autonomous sessions
- Don't ask clarifying questions mid-task. Make a reasonable decision, document
  it, and continue.
- Don't push to remote or open PRs unless the task explicitly requires it.
