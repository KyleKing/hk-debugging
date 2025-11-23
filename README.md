# hk-debugging

Investigation repository for HouseKeeper (hk) git hook issues.

## Issues Under Investigation

### Original Issues

1. **Deleted Files Reappearing**: When committing changes that include file deletions along with additions/modifications, the commit succeeds but deleted files reappear as untracked and require manual removal
2. **Unstaged Changes Lost**: Unstaged changes are sometimes lost when committing staged changes, potentially due to automatic staging interference

### Exit Code Investigation (NEW)

3. **Fix Exit Codes Not Preventing Commits**: When fix steps exit with code 1 (failure), the commit may still be created, and exit codes may not propagate to the shell
4. **File Modifications from Failed Fixes**: Files modified by fix steps that then fail (exit 1) may be left in unexpected states
5. **Orphaned Stashes on Fix Failure**: When fix steps fail, stashed changes may not be restored, creating orphaned stashes

See **[EXIT-CODE-INVESTIGATION.md](EXIT-CODE-INVESTIGATION.md)** for comprehensive exit code analysis.

Note: the most recent version of hk may have resolved these issues: https://github.com/jdx/hk

## Documentation

### Original Investigation

- **[SUMMARY.md](SUMMARY.md)** - Executive summary and overview
- **[QUICK-START.md](QUICK-START.md)** - Quick guide to running tests
- **[ANALYSIS.md](ANALYSIS.md)** - Comprehensive root cause analysis and recommendations
- **[TESTING.md](TESTING.md)** - Testing methodology and results tracking

### Exit Code Investigation (NEW)

- **[EXIT-CODE-INVESTIGATION.md](EXIT-CODE-INVESTIGATION.md)** - Executive summary of exit code findings
- **[EXIT-CODE-BUGS.md](EXIT-CODE-BUGS.md)** - Detailed analysis of 7 identified bugs
- **[UNSTAGED-FILES-TRADEOFFS.md](UNSTAGED-FILES-TRADEOFFS.md)** - Comprehensive tradeoff analysis of configuration options

## Test Branches

This repository contains multiple branches with different hk configurations for testing:

### Original Investigation Branches

| Branch | Configuration | Purpose |
|--------|--------------|---------|
| `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah` | No hk.pkl | Baseline (pure git) |
| `test/hk-full-config` | Full reference config | Should reproduce issues |
| `test/hk-no-stash` | No stashing | Test stash impact |
| `test/hk-no-fix` | No auto-fix | Test fix impact |

### Exit Code Investigation Branches (NEW)

| Branch | Configuration | Purpose |
|--------|--------------|---------|
| `claude/test-exit-code-commits-01QgrkK7wYk6eBEj9F6V4Bt1` | Current branch | Exit code investigation |
| `test/exit-code-fail` | Fix always exits 1 | Test commit prevention |
| `test/exit-code-modify-fail` | Modifies then exits 1 | Test file state after failure |
| `test/exit-code-fail-no-stash` | Fails without stash | Test stash-free failure |
| `test/exit-code-mixed` | Multiple steps, some fail | Test partial application |
| `test/exit-code-realistic` | Realistic validation | Test real-world scenario |

## Quick Start

### Original Investigation Tests

```bash
# 1. Set up test branches locally
./setup-test-branches.sh

# 2. Install hk if needed
cargo install hk

# 3. Run tests on all branches
for branch in claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah test/hk-full-config test/hk-no-stash test/hk-no-fix; do
    git checkout "$branch"
    ./test-issue-1.sh
    ./test-issue-2.sh
done
```

### Exit Code Investigation Tests (NEW)

```bash
# 1. Set up exit code test branches
./setup-exit-code-tests.sh

# 2. Run all exit code tests (automated)
./run-all-exit-code-tests.sh

# 3. Or run manually on specific branch
git checkout test/exit-code-fail
./test-exit-codes.sh
```

See [QUICK-START.md](QUICK-START.md) and [EXIT-CODE-INVESTIGATION.md](EXIT-CODE-INVESTIGATION.md) for detailed instructions.

**Note**: Test branches (`test/*`) are local-only and created by the setup scripts.

## Key Findings

### Original Investigation - Suspected Root Causes

**Issue #1 (Deleted Files):**
- Git stash interaction during hook execution
- Fix steps potentially restoring files from history
- Race condition in file operations

**Issue #2 (Unstaged Changes):**
- Stash apply failures after fix steps
- Conflicts between automatic fixes and unstaged changes
- Auto-staging interference with manual staging

### Exit Code Investigation - Identified Bugs (NEW)

**7 Major Bugs Identified** (see [EXIT-CODE-BUGS.md](EXIT-CODE-BUGS.md)):

1. **Exit Code May Not Prevent Commit** (CRITICAL) - Fix exits 1 but commit may still succeed
2. **File Modifications from Failing Fix Not Rolled Back** (HIGH) - Unexpected file states
3. **Orphaned Stash When Fix Fails** (HIGH) - Stash not restored on failure
4. **Unstaged Changes Lost When Fix Modifies Same File** (HIGH) - Data loss risk
5. **Exit Code 0 from Failed Check** (LOW) - Configuration footgun
6. **No Atomic Rollback for Multiple Fix Steps** (MEDIUM) - Partial fix application
7. **Exit Code Not Propagated to Shell** (HIGH) - Breaks CI/CD

**Configuration Recommendations** (see [UNSTAGED-FILES-TRADEOFFS.md](UNSTAGED-FILES-TRADEOFFS.md)):

1. **✅ RECOMMENDED**: Separate fix command (`fix = false` in pre-commit, separate `["fix"]` hook)
2. **✅ SAFE**: Check-only (`fix = false`, no stash needed)
3. **⚠️ RISKY**: No stash (`fix = true`, no stash - may auto-stage)
4. **❌ AVOID**: Stash configuration (`stash = "git"` - too many failure modes)

See [ANALYSIS.md](ANALYSIS.md) and [EXIT-CODE-INVESTIGATION.md](EXIT-CODE-INVESTIGATION.md) for detailed recommendations and configuration examples.

## Contributing

To add test results:
1. Run the test scripts on your branch
2. Update `TESTING.md` with your results
3. Submit findings to help identify the root cause
