Find and implement the next unstarted Linear task for the given team or project.

Arguments: $ARGUMENTS
Format: `<team_key_or_name>` (e.g. `DRA` or `loot`)

## Steps

1. **Find the team** — call the Linear MCP `list_teams` tool and match the argument
   case-insensitively against team key or name.

2. **Get next issue** — call `list_issues` for that team with status filter for unstarted/backlog,
   ordered by priority. Pick the highest-priority unstarted issue.

3. **Mark in progress** — call `save_issue` to set the issue status to "In Progress".

4. Read CLAUDE.md thoroughly before writing any code.

5. **Branch setup** — run `git fetch origin` and create `feature/<issue_id>-<slug>` from
   `origin/main`. Slug: title lowercased, non-alphanumeric → hyphens, max 50 chars.

6. Use TodoWrite to plan and track implementation steps before writing code.

7. Implement the task. Follow all CLAUDE.md instructions. Write focused, minimal changes.

8. Commit with a short imperative subject referencing the issue ID.

9. Open a PR against main:
   - Title: `<issue_id>: <title>`
   - Body: what was implemented, key decisions
