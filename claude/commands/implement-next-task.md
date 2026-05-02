Find and implement the next unstarted Linear task for the given project.

Arguments: $ARGUMENTS
Format: `<project_name>` (e.g. `loot-app-basic`) — matches a Linear project name,
case-insensitive substring OK.

## Steps

1. **Find the project** — call `list_projects` and find the project whose name contains
   the argument (case-insensitive). If exactly one match, use it. If multiple, prefer the
   closest match. If none, fall back to `list_teams` and match by team key or name instead.

2. **Get next issue** — call `list_issues` filtered to that project (or team if fallback),
   status unstarted/backlog, ordered by priority. Pick the highest-priority unstarted issue.

3. **Mark in progress** — call `save_issue` to set the issue status to "In Progress".

4. Read CLAUDE.md thoroughly before writing any code.

5. **Branch setup** — run `git fetch origin` and create `feature/<issue_id>-<slug>` from
   `origin/main`. Slug: title lowercased, non-alphanumeric → hyphens, max 50 chars.

6. Use TodoWrite to plan and track implementation steps before writing code.

7. Implement the task. Follow all CLAUDE.md instructions. Write focused, minimal changes.

8. Commit with a short imperative subject referencing the issue ID.

9. Push the branch. Do NOT open a PR — run `pre-pr-review <issue_id> <title>` from
   the terminal after this session to run multi-LLM review and open the PR.
