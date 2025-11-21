# HouseKeeper (hk) Issues Analysis

## Executive Summary

This document analyzes two reported issues with HouseKeeper (hk) git hooks and provides test scenarios, root cause analysis, and recommendations for resolution.

## Reported Issues

### Issue #1: Deleted Files Reappearing as Untracked
**Description**: When committing changes that include file deletions along with additions/modifications, the commit succeeds but deleted files reappear as untracked and require manual removal.

**Severity**: Medium - Requires manual cleanup, could lead to accidentally re-committing deleted files.

### Issue #2: Unstaged Changes Lost During Commit
**Description**: Unstaged changes are sometimes lost when committing staged changes, potentially due to automatic staging interference.

**Severity**: High - Data loss risk for uncommitted work.

## Root Cause Analysis

### Issue #1: Deleted Files Reappearing

**Suspected Root Causes:**

1. **Git Stash Interaction**: The `stash = "git"` configuration causes hk to:
   - Stash unstaged changes before running hooks
   - Run fix steps that may modify files
   - Apply the stash back after hooks complete

   If a deleted file is stashed and then reapplied, it could reappear as an untracked file.

2. **Fix Step File Restoration**: Some fix steps (like `end-of-file-fixer`, `mixed-line-ending`, `trailing-whitespace-fixer`) have `check_first = false`, meaning they run on ALL matched files. If these steps somehow access or restore deleted files from git history during the fix process, they could recreate them.

3. **Race Condition in File Operations**: The sequence of operations:
   ```
   User deletes file → Stages deletion → hk stashes unstaged → Runs fixes →
   Commits staged changes → Restores stash
   ```

   May have timing issues where the stash restore brings back the deleted file.

### Issue #2: Unstaged Changes Lost

**Suspected Root Causes:**

1. **Stash Apply Failure**: After running hooks, if the stash application fails (e.g., due to conflicts with files modified by fix steps), unstaged changes could be lost or left in the stash.

2. **Fix Steps Modifying Unstaged Files**: With `fix = true` and `stash = "git"`:
   - Unstaged files are stashed
   - Hooks run and may create new changes
   - When stash is reapplied, conflicts might cause changes to be lost

3. **Automatic Staging Interference**: The `fix = true` setting automatically modifies files. If these modifications conflict with or overwrite unstaged changes during the stash/unstash cycle, data could be lost.

## Test Branch Configuration

### Branch: `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah` (Baseline)
- **Config**: No hk.pkl (pure git behavior)
- **Purpose**: Establish baseline - should NOT exhibit either issue

### Branch: `test/hk-full-config`
- **Config**: Complete reference hk.pkl from yak-shears
  - `fix = true`
  - `stash = "git"`
  - Full linter suite
- **Purpose**: Should reproduce both issues (most likely)

### Branch: `test/hk-no-stash`
- **Config**: Simplified hk.pkl without stashing
  - `fix = true`
  - No `stash` configuration
  - Minimal linters
- **Purpose**: Test if removing stash prevents Issue #2 (unstaged changes lost)

### Branch: `test/hk-no-fix`
- **Config**: Simplified hk.pkl without automatic fixing
  - `fix = false`
  - `stash = "git"`
  - Minimal linters
- **Purpose**: Test if disabling fixes prevents both issues

## Testing Methodology

### Prerequisites
```bash
# Install hk if not already installed
# See: https://github.com/jdx/hk

# Verify installation
hk --version
```

### Test Execution

For each test branch, run both test scripts:

```bash
# Test Issue #1
git checkout <branch-name>
./test-issue-1.sh > results-issue1-<branch-name>.txt 2>&1

# Test Issue #2
git checkout <branch-name>
./test-issue-2.sh > results-issue2-<branch-name>.txt 2>&1
```

### Expected Results

| Branch | Issue #1 Expected | Issue #2 Expected |
|--------|-------------------|-------------------|
| baseline (no hk) | ✅ Pass (no issue) | ✅ Pass (no issue) |
| full-config | 🔴 Fail (issue reproduced) | 🔴 Fail (issue reproduced) |
| no-stash | ✅ Pass OR 🔴 Fail | ✅ Pass (fixed) |
| no-fix | ✅ Pass (fixed) | ✅ Pass OR 🔴 Fail |

## Recommendations

### Short-term Workarounds

1. **For Issue #1 (Deleted Files Reappearing)**:
   ```bash
   # After committing, clean untracked files
   git clean -fd

   # Or, explicitly remove the deleted file again
   rm <file-name>
   ```

2. **For Issue #2 (Unstaged Changes Lost)**:
   ```bash
   # Before committing, manually stash unstaged changes
   git stash push -u -m "Manual stash before hk commit"

   # Commit staged changes
   hk commit -m "your message"

   # Restore unstaged changes
   git stash pop
   ```

### Configuration Adjustments

#### Option A: Disable Stashing (Addresses Issue #2)
```pkl
hooks = new {
  ["pre-commit"] {
    fix = true
    // Remove: stash = "git"
    steps = linters
  }
}
```

**Trade-off**: Fix steps will run on all files including unstaged changes, which may not be desired.

#### Option B: Disable Automatic Fixes (Addresses Both Issues)
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // Changed from true
    stash = "git"
    steps = linters
  }
}
```

**Trade-off**: Files won't be automatically fixed, requiring manual `hk fix` runs.

#### Option C: Use Manual Fix Workflow (Recommended)
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // Only check, don't fix
    steps = linters  // Just run checks
  }

  ["fix"] {
    fix = true  // Manual fix command
    steps = linters
  }
}
```

**Workflow**:
```bash
# Manual workflow
git add <files>
hk fix            # Manually fix issues
git add <fixed-files>
hk commit -m "msg"  # Commit with checks only
```

### Upstream Investigation

Consider reporting these issues to the hk project with:
1. Test scripts from this repository
2. Results from test branches
3. Configuration that reproduces the issues

Check for updates: https://github.com/jdx/hk

## Configuration Recommendations by Use Case

### Case 1: Maximum Safety (Prevent Data Loss)
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // No automatic modifications
    // No stash needed since we're not fixing
    steps = linters  // Checks only
  }
}
```

### Case 2: Convenience with Safety
```pkl
hooks = new {
  ["pre-commit"] {
    fix = true
    // No stash - fix runs on all files
    batch = true  // Run linters in batches for performance
    steps = safe_linters  // Only safe, non-destructive linters
  }
}
```

### Case 3: Strict CI-like Checks
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false
    steps = all_linters
  }

  ["pre-push"] {
    fix = false
    steps = all_linters
  }
}
```

## Monitoring and Verification

After applying configuration changes, monitor for:

1. **Unexpected file states** after commits:
   ```bash
   git status  # Should be clean after commit
   ```

2. **Missing unstaged changes**:
   ```bash
   git diff  # Verify expected changes remain
   ```

3. **Stash list growth**:
   ```bash
   git stash list  # Should not accumulate orphaned stashes
   ```

## Additional Resources

- hk Documentation: https://hk.jdx.dev/
- hk GitHub: https://github.com/jdx/hk
- hk Configuration Reference: https://hk.jdx.dev/configuration.html
- Git Hooks Documentation: https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks

## Appendix: Test Script Reference

### test-issue-1.sh
Tests for deleted files reappearing as untracked after commit.

**Key Test Steps**:
1. Create and commit test files
2. Delete one file, add another, modify a third
3. Stage all changes
4. Commit using hk (if available) or git
5. Check for untracked files
6. Verify if deleted file reappeared

### test-issue-2.sh
Tests for unstaged changes being lost during commit.

**Key Test Steps**:
1. Create and commit initial files
2. Make staged changes to one file
3. Make unstaged changes to another file
4. Commit only staged changes
5. Verify unstaged changes are preserved
6. Compare file content before/after commit

## Next Steps

1. ✅ **Test branches created** with different configurations
2. ✅ **Test scripts written** for reproducible testing
3. 🔲 **Run tests** with hk installed (requires hk installation)
4. 🔲 **Document results** from each test scenario
5. 🔲 **Implement recommended configuration** based on test results
6. 🔲 **Monitor for recurrence** after configuration changes
