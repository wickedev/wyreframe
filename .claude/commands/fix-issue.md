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
<optional context>
```

## Arguments
- `issue-number` - GitHub issue number to fix (required)
- `release-version` - Version number for changelog/commit message (optional)
- `context` - Additional hints, related files, constraints, or notes (optional, can be multi-line)

**Input**: $ARGUMENTS

## Execution

### Step 1: Parse Arguments
Extract the issue number, release version, and context from `$ARGUMENTS`.
- First word: Issue number (required)
- Second word: Release version (optional, use `-` to skip)
- Remaining text: Additional context (optional)

Examples:
```
/fix-issue 5
/fix-issue 5 v0.1.3
/fix-issue 5 -
관련 파일: src/parser.ts
빈 문자열 입력 시 에러 발생
/fix-issue 5 v0.1.3
이 버그는 offset 계산 로직 문제임
```

### Step 2: Fetch Issue Details
Run `gh issue view <issue-number>` to read:
- Title and description
- Labels
- Expected vs actual behavior
- Steps to reproduce

### Step 3: Analyze the Problem
Based on the issue description and user-provided context:
1. If context mentions specific files, start there; otherwise use Glob/Grep to identify affected files
2. Read relevant source files to understand the root cause
3. Consider any hints or constraints from the provided context
4. Plan the fix approach
5. Identify what tests need to be written

### Step 4: Create Task List
Use TodoWrite to track:
- [ ] Implement the fix
- [ ] Write test cases
- [ ] Run tests to verify
- [ ] Commit changes
- [ ] Create version tag (if release-version provided)
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

### Step 8: Create Version Tag (if release-version provided)
If a release version was specified:
1. Create an annotated tag:
   ```bash
   git tag -a v<release-version> -m "Release v<release-version>: fix #<issue-number>"
   ```
2. The tag will be pushed when the user pushes changes

### Step 9: Comment and Close Issue
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
/fix-issue 7 -
src/renderer.ts 의 render() 함수에서 발생
경계 조건 체크 누락된 것 같음
```

## Notes
- Always run full test suite before committing
- If tests fail, fix issues before proceeding
- If the issue is unclear, ask for clarification first
