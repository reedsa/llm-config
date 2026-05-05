Find and implement the next unstarted Linear task for the current project.

Arguments: $ARGUMENTS
Format: `[project_name]` — optional. If omitted, the project is inferred from the
working directory.

## Steps

1. **Find the project** — determine the search term:
   - If an argument was provided, use it as the search term.
   - Otherwise, use `basename $PWD` as the search term (e.g. working directory
     `/Users/stu/projects/reedsa/loot-app-basic` → search term `loot-app-basic`).
   Call `list_projects` and find the project whose name contains the search term
   (case-insensitive). If exactly one match, use it. If multiple, prefer the closest
   match. If none, fall back to `list_teams` and match by team key or name instead.

2. **Get next issue** — call `list_issues` filtered to that project (or team if fallback),
   status unstarted/backlog, ordered by priority. Pick the highest-priority unstarted issue.

3. **Mark in progress** — call `save_issue` to set the issue status to "In Progress".

4. Read CLAUDE.md thoroughly before writing any code.

5. **Branch setup** — run `git fetch origin` and create `feature/<issue_id>-<slug>` from
   `origin/main`. Slug: title lowercased, non-alphanumeric → hyphens, max 50 chars.

6. Use TodoWrite to plan and track implementation steps before writing code.

7. Implement the task. Follow all CLAUDE.md instructions. Write focused, minimal changes.

8. Commit with a short imperative subject referencing the issue ID.

9. Push the branch. Do NOT open a PR — tell the user the branch is ready and
   suggest running `/pre-pr-review` to walk through multi-LLM review findings
   interactively before opening the PR.
