# hk-debugging

Investigation repository for HouseKeeper (hk) git hook issues.

## Issues Under Investigation

1. **Deleted Files Reappearing**: When committing changes that include file deletions along with additions/modifications, the commit succeeds but deleted files reappear as untracked and require manual removal
2. **Unstaged Changes Lost**: Unstaged changes are sometimes lost when committing staged changes, potentially due to automatic staging interference

Note: the most recent version of hk may have resolved these issues: https://github.com/jdx/hk

## Documentation

- **[SUMMARY.md](SUMMARY.md)** - Executive summary and overview
- **[QUICK-START.md](QUICK-START.md)** - Quick guide to running tests
- **[ANALYSIS.md](ANALYSIS.md)** - Comprehensive root cause analysis and recommendations
- **[TESTING.md](TESTING.md)** - Testing methodology and results tracking

## Test Branches

This repository contains multiple branches with different hk configurations for testing:

| Branch | Configuration | Purpose |
|--------|--------------|---------|
| `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah` | No hk.pkl | Baseline (pure git) |
| `test/hk-full-config` | Full reference config | Should reproduce issues |
| `test/hk-no-stash` | No stashing | Test stash impact |
| `test/hk-no-fix` | No auto-fix | Test fix impact |

## Quick Start

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

See [QUICK-START.md](QUICK-START.md) for detailed instructions.

**Note**: Test branches (`test/*`) are local-only and created by the setup script.

## Key Findings

### Suspected Root Causes

**Issue #1 (Deleted Files):**
- Git stash interaction during hook execution
- Fix steps potentially restoring files from history
- Race condition in file operations

**Issue #2 (Unstaged Changes):**
- Stash apply failures after fix steps
- Conflicts between automatic fixes and unstaged changes
- Auto-staging interference with manual staging

### Recommended Solutions

1. **Disable auto-fix in pre-commit hooks** - Use manual `hk fix` workflow
2. **Remove stashing** - If you don't need automatic fixes on clean workspace
3. **Use check-only hooks** - Prevent automatic file modifications

See [ANALYSIS.md](ANALYSIS.md) for detailed recommendations and configuration examples.

## Contributing

To add test results:
1. Run the test scripts on your branch
2. Update `TESTING.md` with your results
3. Submit findings to help identify the root cause
