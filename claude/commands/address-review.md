Address code review feedback on an open pull request.

Arguments: $ARGUMENTS
Format: `<pr_number>`

## Step 1 — Fetch PR feedback

Retrieve all feedback on the PR:

```bash
gh pr view <pr_number> --json title,body,headRefName,baseRefName,author
gh api repos/:owner/:repo/pulls/<pr_number>/reviews
gh api repos/:owner/:repo/pulls/<pr_number>/comments
gh api repos/:owner/:repo/issues/<pr_number>/comments
```

Three distinct sources to process:
- **Formal reviews** (`/reviews`): include the review `body` as a finding when it is
  non-empty and contains actual feedback (not just "LGTM" or a summary with no action).
  Note the review `state` (APPROVED / CHANGES_REQUESTED / COMMENTED).
- **Inline code comments** (`/pulls/comments`): capture file path, line number, and a
  5-line context window around the cited line (read the file via the Read tool).
- **PR conversation comments** (`/issues/comments`): top-level thread comments not tied
  to a specific line. Include these as findings with reviewer name and full comment body.

## Step 2 — Present findings summary

Print a numbered list of all reviewer findings, grouped by severity (blockers →
suggestions → nits). For each finding print:
- One-line description, reviewer name, file:line if known
- A 3–5 line code excerpt with the cited line marked (prefix `>`)
- The reviewer's verbatim comment beneath it

Example:
```
BLOCKERS
  1. [reviewer] PaymentScreen.tsx:42 — amount written without rounding
     40 │ const parsed = parseFloat(input);
     41 │ await adjustWalletBalance(walletId, parsed);
   > 42 │ // BUG: floating-point cents (e.g. 0.1 + 0.2) stored directly
     43 │
     "You need to round to 2 decimal places before writing to Firestore."

SUGGESTIONS
  2. [reviewer] wallets.ts:88 — consider extracting the retry logic
     ...
```

Ask: **"Which findings do you want to address? (numbers, ranges like 1-3, 'all', or 'none')"**

If the user says none, skip to Step 6 (push is not needed; just summarize).

## Step 3 — Apply fixes

For each selected finding, in order:

1. Read the relevant code to understand full context.
2. Apply the minimal fix that satisfies the feedback. Do not touch unrelated code.
3. Show the proposed change as a unified diff (`git diff -- <path>`) before committing.
4. Commit with a short imperative message referencing the issue
   (e.g. `fix: round amount to cents before Firestore write`).
   Default to one commit per finding; bundle only when fixes touch the same
   lines and splitting would produce a confusing history.

Do not skip pre-commit hooks. If a hook fails, fix the underlying issue and create
a new commit.

## Step 4 — Analyze prompt improvement opportunities

After all fixes are applied, read all three canonical prompt files:

- `~/projects/reedsa/llm-config/shared/prompts/pre-pr-quality-check.txt`
- `~/projects/reedsa/llm-config/shared/prompts/pre-pr-security-check.txt`
- `~/projects/reedsa/llm-config/shared/prompts/implement-task.txt`

For each addressed finding, determine:

1. **Is this pattern already covered?** Does any existing prompt have an instruction
   that would have caught or prevented this issue? If yes, mark it "already covered" and skip.

2. **What was missing?** Identify the specific pattern or invariant that no prompt mentions.
   Be precise: "no instruction to check rounding before currency writes" is better than "edge cases".

3. **Route to the right prompt** using this decision rule:
   - **implement-task.txt** — the rule is specific and actionable at write time: a developer
     writing the code would immediately know how to apply it (e.g. "use 'Recent' not 'All'
     when data is limited or paginated"). Specific, context-rich rules belong here.
   - **pre-pr-quality-check.txt / pre-pr-security-check.txt** — the rule catches a class of
     subtle error that is easy to miss even when paying attention: architectural invariants,
     correctness patterns, security properties. Broad, pattern-level rules belong here.
   - When in doubt, prefer **implement-task.txt**. A specific rule in a reviewer prompt adds
     noise across every future PR; the same rule in the implementation prompt fires only
     when the implementer is writing the relevant code.

4. **Draft an addition** in the same imperative style as the target file's existing content:
   - **General**: catches the class of issue, not just this PR's code.
   - **Concrete**: tells the reader what to look for or do, not just "be careful about X".
   - **Minimal**: one or two sentences at most.

## Step 5 — Prompt improvement gate (before pushing)

If any additions were drafted, present them **before pushing**:

Print: **"These issues reached PR review without being caught earlier. Suggested prompt additions:"**

Show a unified diff for each affected file. Under each addition, print one sentence naming
which finding motivated it and which prompt it targets (and briefly why that prompt).

Ask: **"Apply these prompt improvements? (yes / no / edit)"**

- **yes**: write the updated files and commit from the llm-config repo:
  ```bash
  git -C ~/projects/reedsa/llm-config add shared/prompts/pre-pr-quality-check.txt \
      shared/prompts/pre-pr-security-check.txt \
      shared/prompts/implement-task.txt
  git -C ~/projects/reedsa/llm-config commit -m \
      "chore: improve prompts from PR #<pr_number> feedback"
  ```
- **no**: skip, proceed to push.
- **edit**: let the user adjust the draft, then re-present before applying.

If no additions were drafted (all findings already covered by existing prompts),
skip this step and note it in one sentence.

## Step 6 — Push and reply

Push the fix commits to the existing branch (do not open a new PR):

```bash
git push
```

Reply to each addressed finding with the commit SHA:

- **Inline code comment** — reply in-thread:
  ```bash
  gh api repos/:owner/:repo/pulls/<pr_number>/comments/<comment_id>/replies \
    -f body="Addressed in <commit_sha>"
  ```
- **PR conversation comment** — post a new top-level PR comment referencing the original:
  ```bash
  gh pr comment <pr_number> --body "Addressed in <commit_sha> (re: @<user>'s comment)"
  ```
- **Review body finding** — post a new top-level PR comment tagging the reviewer:
  ```bash
  gh pr comment <pr_number> --body "Addressed in <commit_sha> (re: @<reviewer>'s review feedback)"
  ```

## Step 7 — Wrap up

Print a concise summary:
- Findings reviewed (total, by severity)
- Findings addressed (one line per fix, with commit SHA)
- Findings skipped (and why — user declined, or a TODO was left)
- Prompt improvements applied (N to implement-task, N quality, N security) or "none needed"

End with exactly one of:
```
STATUS: READY_TO_MERGE
STATUS: BLOCKERS_REMAIN
```
