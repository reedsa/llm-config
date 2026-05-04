Address code review feedback on an open pull request.

Arguments: $ARGUMENTS
Format: `<pr_number>`

## Step 1 — Fetch PR feedback

Retrieve all feedback on the PR:

```bash
gh pr view <pr_number> --json title,body,headRefName,baseRefName,author
gh api repos/:owner/:repo/pulls/<pr_number>/reviews
gh api repos/:owner/:repo/pulls/<pr_number>/comments
```

For each inline comment, capture the file path, line number, and a 5-line context
window around the cited line (read the file via the Read tool).

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

After all fixes are applied, read the canonical reviewer prompt files:

- `~/projects/reedsa/llm-config/shared/prompts/pre-pr-quality-check.txt`
- `~/projects/reedsa/llm-config/shared/prompts/pre-pr-security-check.txt`

For each addressed finding, determine:

1. **Is this pattern already covered?** Does the existing prompt have an instruction
   that would have directed a reviewer to catch this before the PR was opened?
   If yes, mark it "already covered" and skip.

2. **What was missing?** Identify the specific pattern or invariant the prompt doesn't
   mention. Be precise: "no instruction to check rounding before currency writes" is
   better than "edge cases".

3. **Draft an addition** in the same imperative style as the existing checks:
   - **General**: catches the class of issue, not just this PR's code.
   - **Concrete**: tells the reviewer what to look for, not just "be careful about X".
   - **Minimal**: one or two sentences at most.
   - Classify as quality or security (security: auth/authz, injection, privilege,
     crypto, numeric precision in security decisions; quality: everything else).

## Step 5 — Prompt improvement gate (before pushing)

If prompt additions were drafted, present them **before pushing**:

Print: **"These issues reached PR review without being caught pre-PR. Suggested prompt additions:"**

Show a unified diff for each affected prompt file. Under each addition, print one
sentence naming which finding motivated it.

Ask: **"Apply these prompt improvements? (yes / no / edit)"**

- **yes**: write the updated files and commit from the llm-config repo:
  ```bash
  git -C ~/projects/reedsa/llm-config add shared/prompts/pre-pr-quality-check.txt \
      shared/prompts/pre-pr-security-check.txt
  git -C ~/projects/reedsa/llm-config commit -m \
      "chore: improve review prompts from PR #<pr_number> feedback"
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

Reply to each addressed inline comment with the commit SHA:

```bash
gh api repos/:owner/:repo/pulls/<pr_number>/comments/<comment_id>/replies \
  -f body="Addressed in <commit_sha>"
```

## Step 7 — Wrap up

Print a concise summary:
- Findings reviewed (total, by severity)
- Findings addressed (one line per fix, with commit SHA)
- Findings skipped (and why — user declined, or a TODO was left)
- Prompt improvements applied (N quality, N security additions) or "none needed"

End with exactly one of:
```
STATUS: READY_TO_MERGE
STATUS: BLOCKERS_REMAIN
```
