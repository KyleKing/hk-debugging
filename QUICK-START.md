# Quick Start Guide for Testing HK Issues

## Prerequisites

```bash
# Install hk (if not already installed)
# Option 1: Using cargo
cargo install hk

# Option 2: Using homebrew (macOS/Linux)
brew install jdx/tap/hk

# Option 3: Download binary from releases
# https://github.com/jdx/hk/releases

# Verify installation
hk --version
```

## Running Tests

### Quick Test All Scenarios

```bash
# Run all tests and save results
for branch in claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah test/hk-full-config test/hk-no-stash test/hk-no-fix; do
    echo "Testing branch: $branch"
    git checkout "$branch"
    ./test-issue-1.sh > "results-issue1-${branch##*/}.txt" 2>&1
    ./test-issue-2.sh > "results-issue2-${branch##*/}.txt" 2>&1
done

# Review results
ls -la results-*.txt
```

### Manual Test (Issue #1: Deleted Files)

```bash
# 1. Switch to test branch
git checkout test/hk-full-config

# 2. Run test script
./test-issue-1.sh

# 3. Look for "🔴 CONFIRMED" message indicating the issue reproduced
```

### Manual Test (Issue #2: Unstaged Changes)

```bash
# 1. Switch to test branch
git checkout test/hk-full-config

# 2. Run test script
./test-issue-2.sh

# 3. Look for "🔴 ISSUE REPRODUCED" message indicating the issue
```

## Interpreting Results

### Success Indicators
- ✅ Green checkmarks indicate expected behavior
- "working correctly" or "preserved correctly" messages
- No untracked files after deletion commits
- Unstaged changes remain after staged commits

### Failure Indicators
- 🔴 Red circles indicate issues reproduced
- ⚠️  Warning triangles indicate potential problems
- "ISSUE REPRODUCED" or "CONFIRMED" messages
- Deleted files reappearing as untracked
- Unstaged changes missing or modified

## Test Branch Summary

| Branch Name | Config Description | Test Purpose |
|-------------|-------------------|--------------|
| `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah` | No hk.pkl | Baseline - pure git |
| `test/hk-full-config` | Full reference config | Should reproduce issues |
| `test/hk-no-stash` | No stashing | Test if stash causes issue #2 |
| `test/hk-no-fix` | No auto-fix | Test if fix causes both issues |

## Expected Outcomes

### Baseline Branch (No hk.pkl)
Both tests should PASS - no issues expected with pure git

### Full Config Branch
- Issue #1: Likely to FAIL (reproduce issue)
- Issue #2: Likely to FAIL (reproduce issue)

### No Stash Branch
- Issue #1: Unknown
- Issue #2: Should PASS (issue fixed)

### No Fix Branch
- Issue #1: Should PASS (issue fixed)
- Issue #2: Unknown

## Quick Fixes

### If Issue #1 Occurs (Deleted Files Reappear)
```bash
# Clean up untracked files
git clean -fd

# Or selectively remove
rm <filename>
```

### If Issue #2 Occurs (Unstaged Changes Lost)
```bash
# Check if changes are in a stash
git stash list

# Try to recover from most recent stash
git stash show -p stash@{0}

# Apply if it looks correct
git stash pop
```

### Prevent Issues Going Forward
```bash
# Edit hk.pkl based on findings:

# Option 1: Disable stashing
# Remove or comment out: stash = "git"

# Option 2: Disable auto-fix
# Change: fix = true → fix = false

# Option 3: Use manual fix workflow (recommended)
# Set fix = false in pre-commit hook
# Run `hk fix` manually before committing
```

## Reporting Results

If you reproduce the issues, consider:

1. **Save test output**:
   ```bash
   ./test-issue-1.sh > issue1-results.txt 2>&1
   ./test-issue-2.sh > issue2-results.txt 2>&1
   ```

2. **Capture hk version**:
   ```bash
   hk --version > hk-version.txt
   ```

3. **Share configuration**:
   ```bash
   cat hk.pkl > hk-config-used.txt
   ```

4. **Report to hk project**:
   - Create issue at: https://github.com/jdx/hk/issues
   - Include test scripts, results, and configuration

## Advanced Testing

### Test with Different hk Versions

```bash
# Install specific version
cargo install hk --version 1.15.6

# Or test with latest
cargo install hk --git https://github.com/jdx/hk
```

### Custom Configuration Testing

```bash
# Create custom test branch
git checkout -b test/my-custom-config

# Edit hk.pkl with your changes
vim hk.pkl

# Run tests
./test-issue-1.sh
./test-issue-2.sh
```

## Cleanup

```bash
# Return to main branch
git checkout claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah

# Remove test results
rm -f results-*.txt

# Reset any test artifacts
git clean -fd
git reset --hard HEAD
```

## Getting Help

- Full analysis: See `ANALYSIS.md`
- Test details: See `TESTING.md`
- hk documentation: https://hk.jdx.dev/
- Report bugs: https://github.com/jdx/hk/issues
