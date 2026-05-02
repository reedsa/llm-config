# Global Claude Code Instructions

These rules apply to every session. Project-level CLAUDE.md files add to and
override these where they conflict — project-specific rules always win.

## Before starting any task
Read the project's CLAUDE.md if one exists. It is the authoritative source of
conventions, architecture, and Definition of Done for that codebase.

## Code changes
- Make focused, minimal changes. Fix the thing asked for; don't clean up
  surrounding code, refactor unrelated functions, or add unrequested features.
- Follow the conventions already in the file you're editing — naming, spacing,
  patterns — over any personal preference or general best practice.
- Don't add comments that explain what the code does. Only add a comment when
  the *why* is non-obvious: a hidden constraint, a workaround, a subtle invariant.
- Don't add error handling or validation for scenarios that can't happen in the
  current call context.

## Planning and tracking
Use TodoWrite to plan and track steps before writing code on any task with more
than two distinct changes. Mark items complete as you go — don't batch.

## Commits
- Short imperative subject line (under 72 chars).
- Follow whatever prefix convention the project uses (check `git log`). If
  there's no convention, use none — don't invent one.
- Never commit secrets, credentials, or `.env` files.

## Autonomous sessions
- Don't ask clarifying questions mid-task. Make a reasonable decision, note it
  in the PR or commit message, and continue.
- Don't open PRs or push to remote unless the task explicitly requires it or
  the project's CLAUDE.md specifies it.
