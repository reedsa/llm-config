# llm-config

Personal LLM CLI customizations: commands, skills, and shared prompt bodies.
Supports Claude Code, Gemini CLI, and (eventually) Codex.

## Structure

```
shared/prompts/     # Tool-agnostic prompt bodies — used by automation runner scripts
claude/commands/    # Claude Code slash commands (.md, $ARGUMENTS)
gemini/commands/    # Gemini CLI custom commands (.toml, {{args}})
codex/              # Placeholder — format TBD
```

## Install

```bash
git clone git@github.com:reedsa/llm-config.git ~/projects/reedsa/llm-config
cd ~/projects/reedsa/llm-config
chmod +x setup.sh
./setup.sh
```

`setup.sh` symlinks command files into each CLI's discovery path:
- `~/.claude/commands/` for Claude Code
- `~/.gemini/commands/` for Gemini CLI

Run it again after pulling to pick up new commands.

## Commands

| Command | Description |
|---|---|
| `implement-task` | Implement a specific Linear task (takes project_key, issue_id, title, body) |
| `implement-next-task` | Query Linear for the next unstarted issue and implement it (takes team key/name) |
| `address-review` | Address PR review comments and push (takes pr_number) |

## Using with automation runners

The `shared/prompts/` files are the canonical prompt bodies for shell-based runners
(e.g. a Flask webhook spawning `claude -p`). Use them like:

```bash
PROMPT=$(cat "$REPO/shared/prompts/implement-task.txt")
claude --model claude-sonnet-4-6 -p "$PROMPT\n\nArguments: loot $ISSUE_ID $TITLE $BODY"
```

This keeps the prompt logic in one place regardless of which runner or CLI is used.
