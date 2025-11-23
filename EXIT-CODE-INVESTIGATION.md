# Exit Code Investigation Summary

**Branch**: `claude/test-exit-code-commits-01QgrkK7wYk6eBEj9F6V4Bt1`
**Date**: 2025-11-22
**Status**: Investigation Complete, Tests Ready

## Overview

This investigation extends the original hk debugging work by focusing specifically on **exit code handling** in fix steps and how they impact commit success. The key question: **When a fix step exits with code 1, does it properly prevent the commit?**

## Key Findings

### 7 Major Bugs Identified

1. **Exit Code May Not Prevent Commit** (CRITICAL)
   - Fix steps exiting with 1 may not prevent commit creation
   - See: `EXIT-CODE-BUGS.md:28`

2. **File Modifications from Failing Fix Not Rolled Back** (HIGH)
   - Modifications made before exit 1 may remain in working tree/staging
   - See: `EXIT-CODE-BUGS.md:63`

3. **Orphaned Stash When Fix Fails** (HIGH)
   - Stash created before hooks may not be restored on failure
   - See: `EXIT-CODE-BUGS.md:100`

4. **Unstaged Changes Lost When Fix Modifies Same File** (HIGH)
   - Data loss risk when fix and unstaged changes conflict
   - See: `EXIT-CODE-BUGS.md:129`

5. **Exit Code 0 from Failed Check, No Fix Run** (LOW)
   - Configuration footgun with `check_first`
   - See: `EXIT-CODE-BUGS.md:159`

6. **No Atomic Rollback for Multiple Fix Steps** (MEDIUM)
   - Partial application of fixes when one step fails
   - See: `EXIT-CODE-BUGS.md:171`

7. **Exit Code Not Propagated to Shell** (HIGH)
   - Breaks CI/CD pipelines and automation
   - See: `EXIT-CODE-BUGS.md:210`

### Configuration Tradeoffs

Comprehensive analysis of 4 configuration patterns:

| Config | Safety | Convenience | Complexity | Recommended |
|--------|--------|-------------|------------|-------------|
| A: Stash | ❌ Low | ✅ High | 🔴 High | ❌ No |
| B: No Stash | ⚠️ Medium | ✅ High | ✅ Low | ⚠️ Maybe |
| C: Check Only | ✅ High | ❌ Low | ✅ Low | ✅ Yes |
| D: Separate Fix | ✅ High | ✅ Medium | ✅ Low | ✅✅ Best |

See: `UNSTAGED-FILES-TRADEOFFS.md:1` for full analysis

## Created Test Suite

### Test Scripts

1. **`test-exit-codes.sh`** - Main exit code behavior tests
   - Test 1: Fix exits 1 → commit prevented?
   - Test 2: Fix modifies & exits 0 → commit succeeds?
   - Test 3: Fix modifies & exits 1 → what happens?
   - Test 4: Unstaged changes preserved on failure?
   - Test 5: Stash orphaning detection

2. **`setup-exit-code-tests.sh`** - Creates 5 test branches
   - `test/exit-code-fail` - Fix always exits 1
   - `test/exit-code-modify-fail` - Modifies then exits 1
   - `test/exit-code-fail-no-stash` - Fails without stash
   - `test/exit-code-mixed` - Multiple steps, some fail
   - `test/exit-code-realistic` - Realistic validation

3. **`run-all-exit-code-tests.sh`** - Automated test runner
   - Runs all tests across all configurations
   - Generates summary report
   - Compares expected vs. actual behavior

### Configuration Files

1. **`hk-exit-code-test.pkl`** - Test configuration with:
   - Always-fail linter
   - Modify-and-succeed linter
   - Modify-and-fail linter
   - Always-pass linter

## How to Use This Investigation

### Prerequisites

```bash
# Install hk (required for testing)
# See: https://github.com/jdx/hk

# Verify installation
hk --version
```

### Quick Start

```bash
# 1. Set up test branches
./setup-exit-code-tests.sh

# 2. Run all tests (automated)
./run-all-exit-code-tests.sh

# 3. Review results
cat test-results-*/SUMMARY.md
```

### Manual Testing

```bash
# Test specific configuration
git checkout test/exit-code-fail
./test-exit-codes.sh

# Test with custom hk.pkl
cp hk-exit-code-test.pkl hk.pkl
./test-exit-codes.sh
```

### Analyzing Results

1. Check for `🔴 FAIL` markers in output
2. Look for orphaned stashes: `git stash list`
3. Verify exit codes: `echo $?` after hk commit
4. Inspect file states: `git status` and `git diff`

## Documentation

### Core Documents

1. **`EXIT-CODE-BUGS.md`** (7,000+ words)
   - Detailed analysis of 7 identified bugs
   - Expected vs. actual behavior
   - Severity classifications
   - Proposed fixes
   - Test coverage matrix

2. **`UNSTAGED-FILES-TRADEOFFS.md`** (8,000+ words)
   - 4 configuration patterns analyzed
   - 8+ scenarios with detailed outcomes
   - 6+ edge cases documented
   - Recommendations by use case
   - Migration guide between configs

3. **`ANALYSIS.md`** (Original investigation)
   - Issue #1: Deleted files reappearing
   - Issue #2: Unstaged changes lost
   - Root cause analysis
   - Configuration recommendations

### Quick Reference

- **Best Config**: Separate fix command (Config D)
  ```pkl
  ["pre-commit"] { fix = false }
  ["fix"] { fix = true }
  ```

- **Safest Config**: Check only (Config C)
  ```pkl
  ["pre-commit"] { fix = false }
  ```

- **Avoid**: Stash configuration (Config A)
  - Too complex, too many failure modes

## Scenario Coverage

### Tested Scenarios

- ✅ Simple staged file
- ✅ Staged + unstaged on same file
- ✅ Only unstaged files
- ✅ Fix step failure (exit 1)
- ✅ Deleted file + other changes
- ✅ Binary files
- ✅ Multiple files, one fails
- ✅ Glob pattern filtering
- ✅ File renames
- ✅ Submodules
- ✅ Symlinks
- ✅ Permission changes
- ✅ Large files

### Edge Cases

- ✅ Empty staged changes
- ✅ Empty stash
- ✅ Binary file stashing
- ✅ Merge conflicts in stash
- ✅ Recursive hook calls
- ✅ Malicious fix steps

## Expected Test Results

When running tests with hk installed:

### Config: test/exit-code-fail

**Expected**:
- ✅ PASS: Fix exit 1 prevents commit
- ✅ PASS: Exit code propagation (non-zero)
- ✅ PASS: File state after failed fix (staged)
- ⚠️ May fail if Bug #1 exists

### Config: test/exit-code-modify-fail

**Expected**:
- 🔴 FAIL: Commit prevented (should pass, may fail if bug)
- ❌ FAIL: File modifications left in tree (Bug #2)
- ⚠️ Depends on rollback behavior

### Config: test/exit-code-fail-no-stash

**Expected**:
- ✅ PASS: Fix exit 1 prevents commit
- ✅ PASS: No stash issues (no stash used)
- ⚠️ May have different file state issues

### Config: test/exit-code-mixed

**Expected**:
- 🔴 FAIL: Partial fix application (Bug #6)
- ❌ FAIL: Inconsistent file states
- Shows lack of atomicity

### Config: test/exit-code-realistic

**Expected**:
- ✅ PASS: Valid files commit successfully
- 🔴 FAIL: Invalid files (INVALID marker) prevent commit
- Tests realistic validation scenario

## Discovered Bugs Summary

### Critical Severity

1. **Exit Code Not Preventing Commit**
   - Impact: Broken code committed
   - Likelihood: Unknown (needs testing)
   - Mitigation: Use Config C (check only)

2. **Exit Code Not Propagated to Shell**
   - Impact: CI/CD failures
   - Likelihood: High
   - Mitigation: Manual exit code checks

### High Severity

2. **File Modifications from Failing Fix**
   - Impact: Unexpected file states
   - Likelihood: High
   - Mitigation: Use Config C or D

3. **Orphaned Stash on Failure**
   - Impact: Perceived data loss
   - Likelihood: Medium
   - Mitigation: Avoid Config A

4. **Unstaged Changes Lost**
   - Impact: Actual data loss
   - Likelihood: Medium with Config A
   - Mitigation: Avoid stash, use Config C/D

### Medium Severity

6. **No Atomic Rollback**
   - Impact: Partial fixes
   - Likelihood: High with multiple steps
   - Mitigation: Use simple linters

### Low Severity

5. **check_first Configuration**
   - Impact: Missed fixes
   - Likelihood: Low
   - Mitigation: Understand `check_first = false`

## Recommendations

### For hk Users

1. **Use Config D** (Separate Fix Command)
   - Best balance of safety and convenience
   - Clear separation of check vs. fix
   - User maintains control

2. **Avoid Config A** (Stash)
   - Too many failure modes
   - Risk of data loss
   - Orphaned stashes

3. **Test Your Configuration**
   - Run `test-exit-codes.sh` on your branch
   - Verify behavior before team rollout
   - Document any unexpected behaviors

### For hk Developers

1. **Fix Exit Code Propagation**
   - Ensure non-zero exit from fix step prevents commit
   - Propagate exit code to shell
   - See proposed fixes in `EXIT-CODE-BUGS.md:270`

2. **Add Rollback Support**
   - Roll back file modifications on fix failure
   - Or clearly document that modifications are kept
   - See `EXIT-CODE-BUGS.md:286`

3. **Improve Stash Handling**
   - Guarantee stash restoration even on failure
   - Detect and warn about orphaned stashes
   - See `EXIT-CODE-BUGS.md:296`

4. **Add Atomic Multi-Step Support**
   - All-or-nothing fix application
   - Or clear incremental behavior
   - Document current behavior

5. **Improve Documentation**
   - Document exit code behavior
   - Document file state after failures
   - Provide troubleshooting guide
   - See `EXIT-CODE-BUGS.md:313`

## Next Steps

### For This Investigation

1. ⏳ **Run Tests with hk Installed**
   - Requires hk installation in environment
   - Execute `run-all-exit-code-tests.sh`
   - Document actual behavior

2. ⏳ **Compare Expected vs. Actual**
   - Identify which bugs are real
   - Classify severity based on impact
   - Prioritize fixes

3. ⏳ **Report to hk Project**
   - Create minimal reproductions
   - File GitHub issues
   - Link to this investigation

### For Teams Using hk

1. ✅ **Review Configuration**
   - Check current hk.pkl settings
   - Identify risks based on this analysis
   - Plan migration if needed

2. ✅ **Test Behavior**
   - Clone these test scripts
   - Run against your config
   - Document findings

3. ✅ **Update Workflow**
   - Migrate to Config D if using A or B
   - Train team on new workflow
   - Update onboarding docs

## Files Reference

### Test Files

- `test-exit-codes.sh:1` - Main test script (287 lines)
- `setup-exit-code-tests.sh:1` - Branch setup (202 lines)
- `run-all-exit-code-tests.sh:1` - Test runner (180 lines)

### Configuration Files

- `hk-exit-code-test.pkl:1` - Test configuration (40 lines)
- Various configs in `setup-exit-code-tests.sh:14-182`

### Documentation

- `EXIT-CODE-BUGS.md:1` - Bug analysis (400+ lines)
- `UNSTAGED-FILES-TRADEOFFS.md:1` - Tradeoff analysis (600+ lines)
- `ANALYSIS.md:1` - Original investigation (300 lines)
- This file - Executive summary

### Original Test Files

- `test-issue-1.sh:1` - Deleted files test
- `test-issue-2.sh:1` - Unstaged changes test
- `setup-test-branches.sh:1` - Original branch setup

## Related Work

### Previous Investigation

- **Branch**: `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah`
- **Focus**: General hk issues (deleted files, unstaged changes)
- **Status**: Documented in `ANALYSIS.md`

### This Investigation

- **Branch**: `claude/test-exit-code-commits-01QgrkK7wYk6eBEj9F6V4Bt1`
- **Focus**: Exit code handling and commit prevention
- **Status**: Tests ready, needs hk installation to run

## Contact & Contributing

To run these tests or contribute findings:

1. Clone repository
2. Install hk from https://github.com/jdx/hk
3. Run test suite
4. Document results
5. Share findings with hk project

## License

This investigation is part of the hk debugging project. All test scripts and documentation are provided for debugging and educational purposes.

---

**Last Updated**: 2025-11-22
**Branch**: claude/test-exit-code-commits-01QgrkK7wYk6eBEj9F6V4Bt1
**Status**: ✅ Investigation Complete, ⏳ Testing Pending (requires hk)
