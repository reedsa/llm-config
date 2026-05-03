Run an interactive, multi-LLM pre-PR review of the current branch and walk
through findings together with the user before opening a PR.

Arguments: $ARGUMENTS (optional — free-form context, e.g. issue ID/title)

## Setup

1. Verify there are commits ahead of `origin/main`:
   `git rev-list --count origin/main..HEAD`. If 0, stop and tell the user.
2. Capture the diff: `git diff origin/main..HEAD > <run>/branch.diff`.
3. Pick a label for this run — derive from the current branch name
   (`git rev-parse --abbrev-ref HEAD`). Create `.pre-pr-review/<label>-<YYYYMMDD-HHMMSS>/`
   for review artifacts so prior runs stay around for inspection.
4. Build a **context bundle** so reviewers can evaluate siblings of changed
   code, not just the diff:
   - `git diff --name-only origin/main..HEAD` lists the changed files.
   - For each changed file that still exists in HEAD, copy its full text
     to `<run>/context/<safe-path>.txt`.
   - Build `<run>/review-input.md`: prompt body + the diff in a fenced
     block + each modified file under `## File: <path>` headers in fenced
     blocks. This single file is what each reviewer pass receives.

## Review passes

Run **two separate passes per reviewer** — quality and security — so each
review stays focused. Save raw output for each pass into the run directory
(`claude-quality.txt`, `claude-security.txt`, `gemini-quality.txt`,
`gemini-security.txt`). Tell the user when each pass starts and finishes.

The canonical prompt bodies live at:
- `~/projects/reedsa/llm-config/shared/prompts/pre-pr-quality-check.txt`
- `~/projects/reedsa/llm-config/shared/prompts/pre-pr-security-check.txt`

### Claude passes (this session)
For each pass, read the prompt file, then perform the review yourself in
this session against the assembled `review-input.md` (diff + full files).
Write the structured response (with `## BLOCKERS`,
`## SUGGESTIONS`/`## OBSERVATIONS`, `## VERDICT`) to the matching `.txt`
file.

### Gemini passes (headless)
Invoke Gemini via Bash for each prompt. Concatenate the prompt body with
the assembled context (diff + files) into a temp prompt file:

```bash
PROMPT_FILE=$(mktemp)
{
  cat <prompt_path>
  printf '\n\n```diff\n'; cat <diff_path>; printf '\n```\n'
  for f in <run>/context/*.txt; do
    printf '\n## File: %s\n```\n' "$(basename "$f")"
    cat "$f"
    printf '\n```\n'
  done
} > "$PROMPT_FILE"

env -u GEMINI_API_KEY -u GOOGLE_API_KEY -u GOOGLE_GENAI_API_KEY \
    gemini --output-format json -p "$(cat "$PROMPT_FILE")" 2>"$OUT.stderr" \
| jq -r '.response // empty' > "$OUT" || true
```

If `gemini` is not on PATH or returns nothing, note the skip and continue —
do not fail the whole flow.

## Aggregate and present

After all four passes complete:

1. Parse each output file. Extract individual findings under
   `## BLOCKERS`, `## SUGGESTIONS`, and `## OBSERVATIONS`.
2. De-duplicate near-identical findings across reviewers (e.g. both Claude
   and Gemini flagging the same line). Note which reviewers raised each one.
3. Print a numbered summary, grouped by severity. For each finding, print:
   - One-line description, file:line if known, reviewers who raised it.
   - A 3–5 line **code excerpt** from the file at that line (read it via
     the Read tool), with the cited line marked (e.g. prefix `>`). If the
     finding cites no specific line, omit the excerpt. Example:

     ```
     BLOCKERS
       1. [claude, gemini] firestore.rules:81 — exact-equality on float
          subject to IEEE 754 noise
              79 │ && existsAfter(...)
              80 │ && existsAfter(...transactions/...)
            > 81 │ && getAfter(...).data.amount == request.resource.data.balance - resource.data.balance
              82 │ && getAfter(...).data.createdBy == request.auth.uid
              83 │ )
     ```

4. Print each reviewer's verdict (APPROVE / REQUEST_CHANGES) on its own line.

## Interactive triage

Ask the user two questions, in order:

1. **"Which findings do you want more detail on?"** — accept numbers,
   ranges (`1-3`), `all`, or `none`. For each requested finding, print:
   - The full verbatim text from the source review file(s) (so the user
     sees the raw reviewer rationale, not your paraphrase).
   - A wider code context window (~15 lines) around the cited line.
   - The diff hunk for that file:line if the line falls inside the
     captured `branch.diff` (so the user sees what changed and what was
     pre-existing).

2. **"Which findings do you want to address?"** — same input format. If
   the user picks none, skip to the wrap-up.

Do not assume the user wants every blocker fixed. Wait for explicit
selection.

## Apply fixes

For each selected finding, in order:

1. Read the relevant code to understand context.
2. Apply the minimal fix that resolves the issue. Do not touch unrelated
   code.
3. After the edit, **show the proposed change as a unified diff**
   (`git diff -- <path>`) and a one-line summary of what was changed.
   This is so the user can scan exactly what is about to be committed.
4. Stage and commit (see commit strategy below).

### Commit strategy

Default to **one commit per finding**, with a short imperative subject
referencing the finding (e.g. `Quote $var to prevent word splitting`).

Bundle multiple findings into a single commit only when they are tightly
coupled — e.g. the same fix resolves several reviewers' near-duplicate
findings, or two findings touch the same lines such that splitting them
would produce a confusing history. When you bundle, say so and explain
why in one sentence before committing.

Do not skip hooks. If a pre-commit hook fails, fix the underlying issue
and create a new commit (do not amend).

## Post-fix re-review

Fixes can introduce new issues that the original review did not see. After
all selected fixes are committed, re-run the same four passes against the
*new* state of the branch:

1. Recapture the diff (`git diff origin/main..HEAD > <run>/branch.diff.v2`)
   and refresh the context bundle for any newly-modified files.
2. Re-run all four reviewer passes, writing to
   `claude-quality.v2.txt`, `claude-security.v2.txt`,
   `gemini-quality.v2.txt`, `gemini-security.v2.txt`.
3. Compare findings to the v1 set. Surface only **new** findings
   (file:line + first-sentence fingerprint not present in v1, or v1
   findings that are still present despite a claimed fix). For each new
   finding, also show the **diff that introduced it** — the lines added
   in the fix commits that the new finding cites.
4. If there are new findings, run the same interactive triage on them.
   Loop until either no new findings appear or the user says stop.
5. If the user says stop with unresolved findings, list them in the
   wrap-up under "Findings deferred".

Skip the post-fix pass only if no fixes were applied in the previous
step.

## Wrap up

Print a concise summary:
- Findings reviewed, by severity (initial pass + each post-fix pass)
- Findings addressed, with the commit SHA for each
- Findings deferred, and why (if the user said skip, or if you left a TODO)
- Reviewer verdicts (initial and post-fix)

**Do not open a PR.** Tell the user the branch is ready and that they can
ask you to open the PR when they're ready.
