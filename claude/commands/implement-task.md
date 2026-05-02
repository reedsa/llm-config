Implement a Linear task in the current repository.

Arguments: $ARGUMENTS
Format: `<project_key> <issue_id> <title> [body]`

Parse the arguments — first token is project_key, second is issue_id, third (possibly quoted) is
the title, and everything after is the body/context.

## Steps

1. Read CLAUDE.md thoroughly before writing any code.

2. **Branch setup** — check the current git branch.
   - If already on `feature/<issue_id>-*`, proceed.
   - Otherwise, run `git fetch origin` and create `feature/<issue_id>-<slug>` from `origin/main`.
     Slug: title lowercased, non-alphanumeric → hyphens, max 50 chars.

3. Use TodoWrite to plan and track implementation steps before writing code.

4. Implement the task described by the title and body. Follow all CLAUDE.md instructions.
   Write focused, minimal changes — no refactors or cleanup beyond the task.

5. Commit with a short imperative subject referencing the issue ID.

6. Push the branch. Do NOT open a PR — run `pre-pr-review <issue_id> <title>` from
   the terminal after this session to run multi-LLM review and open the PR.
