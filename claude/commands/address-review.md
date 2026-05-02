Address code review feedback on an open pull request.

Arguments: $ARGUMENTS
Format: `<pr_number>`

## Steps

1. Fetch the PR details and all review comments:
   ```
   gh pr view <pr_number> --comments
   gh api repos/:owner/:repo/pulls/<pr_number>/reviews
   gh api repos/:owner/:repo/pulls/<pr_number>/comments
   ```

2. Read the current branch code to understand context for each comment.

3. For each comment or requested change:
   - Understand what the reviewer wants and why.
   - Make the minimal change that satisfies the feedback.
   - If a comment is unclear or the suggestion seems wrong, note it in the PR rather than guessing.

4. Do not make unrequested changes while addressing review feedback.

5. Commit all changes in a single commit: `Address review feedback on PR #<pr_number>`

6. Push to the existing branch (do not open a new PR).

7. Reply to each addressed inline comment:
   ```
   gh api repos/:owner/:repo/pulls/<pr_number>/comments/<comment_id>/replies \
     -f body="Addressed in <commit_sha>"
   ```

8. End your output with exactly one of:
   ```
   STATUS: READY_TO_MERGE
   STATUS: BLOCKERS_REMAIN
   ```
