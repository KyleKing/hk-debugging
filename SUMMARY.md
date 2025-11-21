# Investigation Summary: HouseKeeper (hk) Issues

## Overview

This repository contains a comprehensive investigation into two HouseKeeper (hk) git hook issues:

1. **Deleted files reappearing as untracked** after successful commits
2. **Unstaged changes being lost** during commit operations

## What Was Delivered

### Documentation

1. **[README.md](README.md)** - Main repository overview and quick start guide
2. **[ANALYSIS.md](ANALYSIS.md)** - In-depth root cause analysis with 8+ pages of detailed findings
3. **[TESTING.md](TESTING.md)** - Testing methodology and results tracking template
4. **[QUICK-START.md](QUICK-START.md)** - Step-by-step testing instructions

### Test Infrastructure

1. **Test Scripts**:
   - `test-issue-1.sh` - Automated test for deleted files issue
   - `test-issue-2.sh` - Automated test for unstaged changes issue

2. **Setup Script**:
   - `setup-test-branches.sh` - Creates test branches with different configurations

3. **Test Files**:
   - `test-file-1.txt`, `test-file-2.txt`, `test-file-3.txt` - Sample files for testing

### Test Branch Configurations

Four test scenarios were designed (main branch + 3 local test branches):

| Configuration | Purpose | Key Settings |
|--------------|---------|--------------|
| Baseline | Pure git behavior | No hk.pkl |
| Full Config | Production-like setup | `fix=true`, `stash="git"` |
| No Stash | Test stash impact | `fix=true`, no stash |
| No Fix | Test fix impact | `fix=false`, `stash="git"` |

## Key Findings

### Root Cause Analysis

#### Issue #1: Deleted Files Reappearing

**Most Likely Causes:**
1. Git stash/unstash cycle during hook execution may restore deleted files
2. Fix steps with `check_first = false` run on all files, potentially recreating them
3. Race conditions in file operation sequencing

#### Issue #2: Unstaged Changes Lost

**Most Likely Causes:**
1. Stash apply failures when fix steps modify files
2. Conflicts between automatic fixes and unstaged changes
3. Auto-staging overwriting manually unstaged content

### Recommended Solutions

#### Short-term Workarounds

**For Issue #1:**
```bash
# After committing, clean untracked files
git clean -fd
```

**For Issue #2:**
```bash
# Manually stash before committing
git stash push -u -m "Save unstaged changes"
hk commit -m "message"
git stash pop
```

#### Long-term Configuration Changes

**Option 1: Manual Fix Workflow (Recommended)**
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // Only check, don't auto-fix
    steps = linters
  }
}
```

Workflow: `hk fix` → `git add` → `hk commit`

**Option 2: Disable Stashing**
```pkl
hooks = new {
  ["pre-commit"] {
    fix = true
    // Remove: stash = "git"
    steps = linters
  }
}
```

**Option 3: Conservative Checks Only**
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false
    // No stash needed
    steps = linters  // Checks only
  }
}
```

## How to Use This Repository

### 1. Set Up Environment

```bash
# Clone and enter repository
git checkout claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah

# Set up test branches
./setup-test-branches.sh

# Install hk
cargo install hk
```

### 2. Run Tests

```bash
# Test all configurations
for branch in claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah test/hk-full-config test/hk-no-stash test/hk-no-fix; do
    git checkout "$branch"
    ./test-issue-1.sh
    ./test-issue-2.sh
done
```

### 3. Analyze Results

- Look for "🔴 ISSUE REPRODUCED" messages in test output
- Compare behavior across different configurations
- Update `TESTING.md` with your findings

### 4. Implement Solution

Based on test results:
1. Choose appropriate configuration from `ANALYSIS.md`
2. Update your project's `hk.pkl`
3. Test in your project
4. Monitor for recurrence

## Technical Details

### Configuration Analysis

The reference `hk.pkl` from yak-shears uses:

```pkl
hooks = new {
  ["pre-commit"] {
    fix = true              // Auto-modifies files
    stash = "git"           // Stashes unstaged changes
    steps = linters         // Runs multiple linters
  }
}
```

**Execution Flow:**
1. User runs `hk commit -m "message"`
2. hk stashes unstaged changes
3. hk runs fix steps on staged files
4. Fix steps may modify files automatically
5. Git commits the changes
6. hk restores the stash
7. **Issue**: Stash restore may conflict or bring back deleted files

### Test Script Logic

**test-issue-1.sh**:
- Creates and commits files
- Deletes one, adds one, modifies one
- Commits via hk (if available)
- Checks if deleted file reappears

**test-issue-2.sh**:
- Creates and commits files
- Makes staged changes
- Makes separate unstaged changes
- Commits only staged changes
- Verifies unstaged changes preserved

## Repository Structure

```
hk-debugging/
├── README.md                    # Main overview
├── SUMMARY.md                   # This file
├── ANALYSIS.md                  # Detailed analysis
├── TESTING.md                   # Test tracking
├── QUICK-START.md               # Quick reference
├── setup-test-branches.sh       # Branch setup script
├── test-issue-1.sh             # Test deleted files
├── test-issue-2.sh             # Test unstaged changes
└── test-file-*.txt             # Sample test files
```

## Next Steps

### For Users Experiencing These Issues

1. **Immediate**: Use short-term workarounds from `ANALYSIS.md`
2. **Testing**: Run test scripts to confirm issues in your environment
3. **Configuration**: Implement recommended configuration changes
4. **Monitoring**: Watch for issue recurrence after changes

### For Contributing to Root Cause Analysis

1. Run tests with `hk` installed
2. Document results in `TESTING.md`
3. Try different `hk` versions
4. Report findings to: https://github.com/jdx/hk/issues

### For hk Project Maintainers

This repository provides:
- Reproducible test cases
- Detailed analysis of suspected causes
- Multiple test configurations
- Automated test scripts

Consider:
- Running these tests in CI
- Adding regression tests for these scenarios
- Documenting stash/fix interaction behavior

## References

- **hk Project**: https://github.com/jdx/hk
- **hk Documentation**: https://hk.jdx.dev/
- **Reference Config**: https://github.com/KyleKing/yak-shears/blob/9abbcd478fe512edcc64b10015befcba124af16f/hk.pkl

## Version Info

- **Investigation Date**: 2025-11-21
- **Reference hk Version**: 1.15.6
- **Test Branch**: `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah`

## Status

- ✅ Issues documented and analyzed
- ✅ Root causes identified (suspected)
- ✅ Test infrastructure created
- ✅ Solutions recommended
- ⬜ Issues reproduced with hk (requires hk installation)
- ⬜ Configuration changes validated
- ⬜ Issues reported upstream

## Contact & Feedback

If you successfully reproduce or resolve these issues:
1. Update the `TESTING.md` file with your results
2. Consider reporting to the hk project with your findings
3. Share your configuration if you find a better solution

---

**Note**: This investigation was conducted without `hk` installation. Actual testing with `hk` is required to confirm the issues and validate solutions.
