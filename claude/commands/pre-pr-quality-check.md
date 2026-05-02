Review the current branch changes for code quality issues before a PR is opened.

Run `git diff origin/main..HEAD` to get the diff, then review it for:
- Correctness: logic errors, missing edge cases, off-by-ones
- Clarity: confusing names, unclear intent, missing context
- Maintainability: duplication, brittle patterns, missing tests for new behaviour
- API contracts: broken interfaces, incorrect error handling

Format your response as:

## BLOCKERS
Issues that must be fixed before merging (incorrect behaviour, broken tests, API breakage).
If none, write "None."

## SUGGESTIONS
Non-blocking improvements (naming, minor simplifications, optional test coverage).
If none, write "None."

## VERDICT
APPROVE or REQUEST_CHANGES
