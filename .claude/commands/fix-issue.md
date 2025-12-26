---
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, TodoWrite, Task]
description: "Fix a GitHub issue: analyze, implement, test, commit, and close"
---

# /fix-issue - GitHub Issue Fix Workflow

## Purpose
Automates the complete workflow for fixing a GitHub issue: analyze the problem, implement the fix, write tests, commit changes, and close the issue.

## Usage
```
/fix-issue <issue-number> [release-version]
```

## Arguments
- `issue-number` - GitHub issue number to fix (required)
- `release-version` - Version number for changelog/commit message (optional)

**Input**: $ARGUMENTS

## Execution

### Step 1: Parse Arguments
Extract the issue number and release version from `$ARGUMENTS`.
- First word: Issue number (required)
- Second word: Release version (optional)

### Step 2: Fetch Issue Details
Run `gh issue view <issue-number>` to read:
- Title and description
- Labels
- Expected vs actual behavior
- Steps to reproduce

### Step 3: Analyze the Problem
Based on the issue description:
1. Identify affected files and components using Glob/Grep
2. Read relevant source files to understand the root cause
3. Plan the fix approach
4. Identify what tests need to be written

### Step 4: Create Task List
Use TodoWrite to track:
- [ ] Implement the fix
- [ ] Write test cases
- [ ] Run tests to verify
- [ ] Commit changes
- [ ] Comment on issue
- [ ] Close issue

### Step 5: Implement the Fix
1. Make necessary code changes to fix the issue
2. Follow existing code patterns and conventions
3. Keep changes minimal and focused

### Step 6: Write Tests
1. Add test cases that verify the fix
2. Include edge cases mentioned in the issue
3. Run all tests to verify nothing is broken

### Step 7: Commit Changes
Create a commit with format:
```
fix: <concise description> (#<issue-number>)

<detailed explanation if needed>
```

### Step 8: Comment and Close Issue
1. Get commit hash: `git rev-parse --short HEAD`
2. Comment on issue with changes summary:
   ```bash
   gh issue comment <issue-number> --body "Fixed in commit <hash>

   Changes made:
   - <list of changes>

   Tests added:
   - <list of tests>"
   ```
3. Close the issue: `gh issue close <issue-number>`

## Claude Code Integration
- Uses Read/Write/Edit for code modifications
- Leverages Glob and Grep for codebase exploration
- Applies TodoWrite for progress tracking
- Uses Bash for git and gh CLI operations

## Examples
```
/fix-issue 5
/fix-issue 5 v0.1.3
/fix-issue 12 v0.2.0
```

## Notes
- Always run full test suite before committing
- If tests fail, fix issues before proceeding
- If the issue is unclear, ask for clarification first
