# Exit Code Bug Analysis

**Date**: 2025-11-22
**Branch**: claude/test-exit-code-commits-01QgrkK7wYk6eBEj9F6V4Bt1
**Focus**: Exit code handling in fix steps and their impact on commit success

## Executive Summary

This document analyzes bugs related to how HouseKeeper (hk) handles exit codes from fix steps, particularly focusing on:
- Whether failing fix steps (exit 1) properly prevent commits
- How file modifications from failing fixes are handled
- Interaction between exit codes, stash operations, and file states
- Edge cases in unstaged file handling when fixes fail

## Background: How Fix Steps Should Work

### Expected Behavior

When `fix = true` and `stash = "git"` are configured:

```
1. User runs: hk commit -m "message"
2. hk stashes unstaged changes (if any)
3. For each fix step:
   a. Run the fix command on matched files
   b. If exit code != 0: STOP and fail the commit
   c. If exit code == 0: Continue to next step
4. If all steps pass: git commit
5. Restore stash (if any)
6. Exit with appropriate code
```

**Key Principle**: A failing fix step (exit 1) should:
- ✅ Prevent the commit from being created
- ✅ Propagate the non-zero exit code to the user
- ✅ Leave staged changes staged (not lost)
- ✅ Preserve unstaged changes
- ✅ Not create orphaned stashes

## Identified Bugs

### BUG #1: Exit Code May Not Prevent Commit ⚠️ CRITICAL

**Description**: It's unclear whether hk properly stops the commit process when a fix step exits with code 1.

**Evidence**:
- The existing test scripts (`test-issue-1.sh`, `test-issue-2.sh`) don't check exit codes
- They only check file state after commit
- No test validates that commit is prevented on fix failure

**Expected**:
```bash
$ hk commit -m "test"
# Fix step exits 1
error: Fix step 'some-fixer' failed
$ echo $?
1
$ git log -1 --oneline
# Should show previous commit, not new one
```

**Actual** (suspected):
```bash
$ hk commit -m "test"
# Fix step exits 1, but commit might still succeed?
$ echo $?
0  # Wrong! Should be 1
$ git log -1 --oneline
abc1234 test  # New commit created despite failure
```

**Test Case**: `test-exit-codes.sh` Test 1
**Severity**: CRITICAL - May allow broken code to be committed

---

### BUG #2: File Modifications from Failing Fix Not Rolled Back

**Description**: When a fix step modifies files then exits 1, the modifications may remain in the working tree and/or staging area, leading to unexpected state.

**Scenario**:
```pkl
["buggy-fixer"] {
  check_first = false
  fix = "echo '# Added by fixer' >> {{ files }} && exit 1"
}
```

**Execution Flow**:
1. User stages file with content "line 1"
2. hk runs fix step
3. Fix step appends "# Added by fixer"
4. Fix step exits 1
5. **QUESTION**: What happens to the modification?

**Possible Outcomes**:

| Outcome | Working Tree | Staging Area | Stash State | Bug? |
|---------|--------------|--------------|-------------|------|
| A | Modified | Modified | Clean | ⚠️ Unexpected modification from failed fix |
| B | Modified | Original | Clean | ⚠️ Modification in working tree, not staged |
| C | Original | Original | Clean | ✅ Rolled back (ideal) |
| D | Modified | Modified | Orphaned | 🔴 Modification + orphaned stash |
| E | Original | Lost | Orphaned | 🔴🔴 Data loss! |

**Expected Behavior**: Outcome C (rollback) or clear documentation of behavior

**Test Case**: `test-exit-codes.sh` Test 3
**Severity**: HIGH - Can lead to unexpected file states or data loss

---

### BUG #3: Orphaned Stash When Fix Fails

**Description**: When `stash = "git"` is enabled and a fix step fails, the stash created before running hooks may not be properly restored, leading to orphaned stashes.

**Execution Flow**:
```
1. User has unstaged changes
2. hk stashes them: stash@{0}
3. Fix step runs and fails (exit 1)
4. hk attempts to restore stash
5. QUESTION: Is stash restored? Or orphaned?
```

**Evidence from ANALYSIS.md**:
> "If the stash application fails (e.g., due to conflicts with files modified by fix steps), unstaged changes could be lost or left in the stash."

**Indicators**:
```bash
# After failed commit
$ git stash list
stash@{0}: On branch-name: autostash  # Orphaned!

# User's unstaged changes are lost from working tree
$ git diff
# Empty! But changes are in stash
```

**Test Case**: `test-exit-codes.sh` Test 5
**Severity**: HIGH - Can lead to confusion and perceived data loss

---

### BUG #4: Unstaged Changes Lost When Fix Modifies Same File

**Description**: When a fix step modifies a file that has unstaged changes, the stash restore may fail or cause data loss.

**Scenario**:
1. File `foo.txt` has content "A\nB\n"
2. User stages change: "A\nB\nC\n"
3. User makes unstaged change: "A\nB\nC\nD\n"
4. hk stashes unstaged change (D)
5. Fix step modifies file: "A\nB\nC\nE\n" (added E instead of D)
6. hk attempts to restore stash with D
7. **CONFLICT**: Both stash and fix modified the same location

**Outcomes**:
- ❌ Stash apply fails, unstaged change lost in stash
- ❌ Conflict markers added to file
- ❌ Stash apply succeeds but overwrites fix
- ✅ Proper 3-way merge (ideal but complex)

**Test Case**: `test-exit-codes.sh` Test 4 (different file), needs enhancement for same-file test
**Severity**: HIGH - Data loss risk
**Related**: Issue #2 from ANALYSIS.md

---

### BUG #5: Exit Code 0 from Failed Check, No Fix Run

**Description**: When `check_first = true` (default) and check exits 0 (success), the fix step is not run even if the file actually needs fixing.

**Configuration**:
```pkl
["fixer"] {
  check_first = true  // Default
  check = "some-lint-check {{ files }}"
  fix = "some-fixer {{ files }}"
}
```

**Problem**: If the check has a bug and exits 0 when it should exit 1, files won't be fixed.

**Not a bug in hk itself**, but a footgun. Relates to the `check_first = false` pattern used by pre-commit fixers.

**Severity**: LOW - User configuration issue

---

### BUG #6: No Atomic Rollback for Multiple Fix Steps

**Description**: When multiple fix steps are configured and one fails partway through, previous fixes may already be applied and committed.

**Scenario**:
```pkl
local linters = new Mapping<String, Step> {
  ["step-1"] { fix = "fixer-1 {{ files }}" }  // Succeeds, modifies files
  ["step-2"] { fix = "fixer-2 {{ files }}" }  // Fails with exit 1
  ["step-3"] { fix = "fixer-3 {{ files }}" }  // Never runs
}
```

**Execution**:
1. step-1 runs, modifies files
2. step-2 runs, fails
3. step-3 never runs
4. **QUESTION**: Are step-1 modifications committed? Staged? In working tree?

**Expected Behaviors** (choose one):
- A: All-or-nothing: If any step fails, roll back all fixes
- B: Incremental: Each fix is staged separately, partial progress kept
- C: Best-effort: Fixes up to failure are staged, commit is prevented

**Current Behavior**: Unknown, needs testing

**Test Case**: `test-exit-codes.sh` Test 5 with `test/exit-code-mixed` config
**Severity**: MEDIUM - Unexpected partial application of fixes

---

### BUG #7: Exit Code Not Propagated to Shell

**Description**: When hk commit fails due to a fix step error, the exit code may not propagate to the shell, breaking CI/CD pipelines.

**Expected**:
```bash
#!/bin/bash
set -e  # Exit on error

hk commit -m "auto commit"
# If fix fails, script should exit here

echo "This should not print if commit failed"
```

**Actual** (suspected):
```bash
#!/bin/bash
set -e

hk commit -m "auto commit"
# Fix fails, but hk exits with 0???

echo "This DOES print even though commit failed"  # BUG!
```

**Impact**:
- CI/CD pipelines don't detect failures
- Automated scripts proceed despite failed commits
- Silent failures in automation

**Test Case**: Check exit code in `test-exit-codes.sh` Test 1
**Severity**: HIGH - Breaks automation and CI/CD

---

## Tradeoffs in Unstaged File Handling

The core tension is: **How to handle unstaged changes when fix steps modify files?**

### Option 1: Stash Unstaged Changes (`stash = "git"`)

**How it works**:
```
1. Stash unstaged changes
2. Run fix steps on staged files only
3. Commit fixes
4. Restore stash
```

**Pros**:
- ✅ Fix steps only touch staged files
- ✅ Clean separation of staged vs. unstaged
- ✅ Follows "commit only what's staged" principle

**Cons**:
- ❌ Stash conflicts if fix modifies same lines as unstaged changes
- ❌ Can lose unstaged changes if stash apply fails
- ❌ Creates orphaned stashes on failure
- ❌ Complex state management

**When to use**: When you need strict separation and don't mind stash complexity

---

### Option 2: No Stash (`fix = true`, no `stash`)

**How it works**:
```
1. Run fix steps on ALL files (staged + unstaged)
2. Stage all fixes
3. Commit
```

**Pros**:
- ✅ Simpler, no stash complexity
- ✅ No risk of orphaned stashes
- ✅ Fixes apply to entire working tree

**Cons**:
- ❌ May auto-stage unstaged changes
- ❌ Commit includes more than user intended
- ❌ Violates "commit only staged" principle

**When to use**: When you want all files fixed and don't mind auto-staging

---

### Option 3: No Auto-Fix (`fix = false`)

**How it works**:
```
1. Run check steps only
2. If checks fail, prevent commit
3. User manually runs `hk fix`
4. User stages fixes
5. User commits
```

**Pros**:
- ✅ No automatic modifications
- ✅ User has full control
- ✅ No stash complexity
- ✅ No data loss risk
- ✅ Clear separation of check vs. fix

**Cons**:
- ❌ Manual workflow, less convenient
- ❌ Users may forget to fix
- ❌ Extra steps

**When to use**: Maximum safety and control (RECOMMENDED for most users)

---

### Option 4: Check-Only Pre-Commit, Fix in Separate Command

**How it works**:
```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // Only check
    steps = linters
  }

  ["fix"] {
    fix = true   // Manual fix command
    // No stash needed, user controls what's staged
    steps = linters
  }
}
```

**Workflow**:
```bash
$ git add file.txt
$ hk commit -m "msg"
error: trailing whitespace found
$ hk fix
Fixed 3 files
$ git add file.txt  # Stage fixes
$ hk commit -m "msg"
Success!
```

**Pros**:
- ✅ Best of both worlds
- ✅ Pre-commit prevents bad commits
- ✅ Manual fix when needed
- ✅ User controls staging
- ✅ No stash complexity

**Cons**:
- ❌ Requires two commands for fixes

**When to use**: Best practice for most projects (RECOMMENDED)

---

### Comparison Matrix

| Feature | Stash | No Stash | No Fix | Separate Fix |
|---------|-------|----------|--------|--------------|
| **Complexity** | High | Medium | Low | Low |
| **Data Loss Risk** | High | Low | None | None |
| **Auto-staging** | No | Yes | No | No |
| **Convenience** | High | High | Low | Medium |
| **Safety** | Low | Medium | High | High |
| **Stash Issues** | Yes | No | No | No |
| **CI/CD Friendly** | Medium | Medium | High | High |
| **Recommended** | ❌ | ⚠️ | ✅ | ✅✅ |

---

## Edge Cases to Test

### Edge Case 1: Empty Stash
- No unstaged changes
- Fix step fails
- Should work correctly

### Edge Case 2: Binary Files
- Stashing binary files
- Fix modifies binary
- Stash restore behavior?

### Edge Case 3: File Deletion
- File deleted and staged
- Unstaged changes to other files
- Fix step runs
- Does deleted file reappear? (Related to Issue #1)

### Edge Case 4: Merge Conflicts in Stash
- Stash has conflicts on restore
- Does hk handle this gracefully?
- Are conflicts left for user to resolve?

### Edge Case 5: Pre-commit Hook Called Recursively
- Fix step runs `git commit`
- Infinite recursion?
- Should be prevented

### Edge Case 6: Fix Step Modifies .git Directory
- Malicious or buggy fix step
- Could corrupt repository
- Should hk prevent this?

---

## Recommended Testing Approach

### Phase 1: Basic Exit Code Behavior
1. ✅ Run `test-exit-codes.sh` on each test branch
2. ✅ Verify exit code propagation
3. ✅ Verify commit prevention

### Phase 2: File State Verification
1. Test modifications from failing fixes
2. Test staged vs. unstaged state
3. Test rollback behavior

### Phase 3: Stash Behavior
1. Test stash creation/restoration
2. Test orphaned stash detection
3. Test stash conflicts

### Phase 4: Edge Cases
1. Test all edge cases listed above
2. Document unexpected behaviors
3. File bug reports if needed

---

## Known Limitations

From the ANALYSIS.md investigation:

1. **Issue #1: Deleted Files Reappearing**
   - Severity: Medium
   - Suspected cause: Stash/unstash cycle or fix steps
   - Related to exit codes: Fix failure may leave file in unexpected state

2. **Issue #2: Unstaged Changes Lost**
   - Severity: High
   - Suspected cause: Stash apply failure after fix
   - Related to exit codes: Fix failure may orphan stash

---

## Proposed Fixes

### For BUG #1 (Exit Code Not Preventing Commit)
**If confirmed**: hk should check exit code after EACH fix step and immediately abort if non-zero.

```rust
for step in &hook.steps {
    let exit_code = run_fix_step(step, files);
    if exit_code != 0 {
        // Restore stash if any
        restore_stash()?;
        // Exit with error code
        return Err(exit_code);
    }
}
```

### For BUG #2 (Modifications from Failed Fix)
**Option A**: Rollback modifications on fix failure
```
1. Save file hashes before fix
2. Run fix
3. If exit != 0: restore files from hashes
```

**Option B**: Document behavior clearly
- Make it clear that modifications from failed fixes are kept
- User must manually revert if needed

### For BUG #3 (Orphaned Stash)
Use stash reference and always restore:
```bash
# Before fix
STASH_REF=$(git stash create)

# After fix (even on failure)
trap "git stash apply $STASH_REF || git stash store $STASH_REF -m 'hk autostash'" EXIT
```

### For BUG #7 (Exit Code Not Propagated)
Ensure hk exits with same code as failed step:
```rust
fn main() {
    let result = run_hooks();
    match result {
        Ok(_) => std::process::exit(0),
        Err(code) => std::process::exit(code),
    }
}
```

---

## Documentation Recommendations

### Add to hk Documentation

1. **Exit Code Behavior**
   - Clearly document that fix exit 1 prevents commit
   - Document exit code propagation
   - Show examples in CI/CD

2. **File State After Failure**
   - Document what happens to modifications from failed fixes
   - Document staged vs. unstaged state
   - Provide troubleshooting guide

3. **Stash Behavior**
   - Document stash creation/restoration
   - Warn about potential conflicts
   - Show how to recover from orphaned stashes

4. **Best Practices**
   - Recommend `fix = false` for most users
   - Recommend separate `["fix"]` command
   - Warn about `stash = "git"` complexity

---

## Next Steps

1. ✅ **Created**: Comprehensive test scripts
   - `test-exit-codes.sh` - Main exit code tests
   - `setup-exit-code-tests.sh` - Test branch setup
   - `run-all-exit-code-tests.sh` - Automated test runner

2. ⏳ **TODO**: Run tests with hk installed
   - Set up environment with hk
   - Run on all test configurations
   - Document actual behavior

3. ⏳ **TODO**: Identify actual bugs from test results
   - Compare expected vs. actual
   - Classify severity
   - Prioritize fixes

4. ⏳ **TODO**: Report bugs to hk project
   - Create minimal reproduction
   - File issues on GitHub
   - Propose fixes

5. ⏳ **TODO**: Update documentation
   - Add findings to ANALYSIS.md
   - Create user guide for exit code handling
   - Document workarounds

---

## References

- HouseKeeper (hk): https://github.com/jdx/hk
- hk Documentation: https://hk.jdx.dev/
- This investigation repo: `/home/user/hk-debugging/`
- Related analysis: `ANALYSIS.md`
- Test scripts:
  - `test-exit-codes.sh:1` - Main exit code tests
  - `test-issue-1.sh:1` - Deleted files test
  - `test-issue-2.sh:1` - Unstaged changes test
