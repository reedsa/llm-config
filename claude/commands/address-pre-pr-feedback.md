Address blocker-level issues from a multi-LLM pre-PR review before opening a pull request.

Arguments: $ARGUMENTS
Format: `<feedback_file_path>`

Read the combined review feedback from the file at the path provided. It contains labelled
sections from one or more LLM reviewers (Claude quality, Claude security, Gemini quality,
Gemini security, etc.).

## Steps

1. Parse all BLOCKERS sections from the feedback. Ignore SUGGESTIONS and OBSERVATIONS —
   those are for the human author to consider, not to auto-apply.

2. For each unique blocker (de-duplicate near-identical findings across reviewers):
   - Read the relevant code to understand the full context.
   - Apply the minimal fix that resolves the issue without touching unrelated code.
   - If two reviewers flag the same issue differently, use your judgment to apply one fix
     that satisfies both.

3. If a blocker is ambiguous or the suggested fix would require a significant design change,
   leave a TODO comment in the code and note it in your output rather than guessing.

4. If no blockers were found across any reviewer, do nothing and say so.

5. Commit any fixes as a single commit: `Pre-PR review fixes`

Print a concise summary:
- How many blockers were found and from which reviewers
- What was fixed (one line per fix)
- Anything left as a TODO and why
