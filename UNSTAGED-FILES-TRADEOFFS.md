# Unstaged Files Handling: Scenarios and Tradeoffs

**Date**: 2025-11-22
**Purpose**: Comprehensive analysis of how different hk configurations handle unstaged files under various scenarios

## Table of Contents

1. [Configuration Options](#configuration-options)
2. [Scenario Matrix](#scenario-matrix)
3. [Detailed Scenario Analysis](#detailed-scenario-analysis)
4. [Edge Cases](#edge-cases)
5. [Recommendations by Use Case](#recommendations-by-use-case)
6. [Migration Guide](#migration-guide)

---

## Configuration Options

### Config A: Full Auto-Fix with Stash (Most Complex)

```pkl
hooks = new {
  ["pre-commit"] {
    fix = true       // Automatically fix files
    stash = "git"    // Stash unstaged changes
    steps = linters
  }
}
```

**Behavior**:
- Stashes unstaged changes before running fixes
- Applies fixes to staged files
- Restores stash after commit

**Use Case**: Strict staged/unstaged separation, automated fixes

---

### Config B: Auto-Fix Without Stash (Simple but Aggressive)

```pkl
hooks = new {
  ["pre-commit"] {
    fix = true       // Automatically fix files
    // NO stash     // No unstaged change handling
    steps = linters
  }
}
```

**Behavior**:
- Runs fixes on ALL files (staged AND unstaged)
- Stages all fixes
- Commits everything that was fixed

**Use Case**: "Fix everything" approach, don't care about staging granularity

---

### Config C: Check-Only (Safest)

```pkl
hooks = new {
  ["pre-commit"] {
    fix = false      // Only check, don't fix
    steps = linters
  }
}
```

**Behavior**:
- Only runs checks
- Prevents commit if checks fail
- User must manually fix and re-stage

**Use Case**: Maximum control, no surprises

---

### Config D: Separate Fix Command (Recommended)

```pkl
hooks = new {
  ["pre-commit"] {
    fix = false      // Check only
    steps = linters
  }

  ["fix"] {
    fix = true       // Manual fix
    steps = linters
  }
}
```

**Behavior**:
- Pre-commit: Checks only, prevents bad commits
- Manual `hk fix`: Fixes files when needed
- User controls what to stage

**Use Case**: Best practice, balance of safety and convenience

---

## Scenario Matrix

| Scenario | Config A<br/>(Stash) | Config B<br/>(No Stash) | Config C<br/>(Check Only) | Config D<br/>(Separate) |
|----------|----------------------|-------------------------|---------------------------|-------------------------|
| **1. Simple staged file** | ✅ Fixed, committed | ✅ Fixed, committed | ⚠️ Blocked if fails | ✅ Manual fix |
| **2. Staged + unstaged on same file** | ⚠️ Complex stash | ❌ Both fixed | ✅ Staged only | ✅ User controls |
| **3. Unstaged files only** | ✅ Untouched | ❌ Fixed & staged | ✅ Untouched | ✅ Untouched |
| **4. Fix step fails (exit 1)** | 🔴 Orphaned stash? | 🔴 Partial fixes? | ✅ Clean failure | ✅ Clean failure |
| **5. Deleted file + unstaged changes** | 🔴 File reappears? | ❌ Conflicts | ✅ Works | ✅ Works |
| **6. Binary files** | ⚠️ Stash issues | ❌ May stage all | ✅ User decides | ✅ User decides |
| **7. Large files** | ⚠️ Slow stash | ⚠️ Slow fixes | ✅ Fast | ✅ Fast check |
| **8. Multiple files, one fails** | 🔴 Inconsistent | 🔴 Partial | ✅ All blocked | ✅ All blocked |

**Legend**:
- ✅ Works as expected
- ⚠️ Works but with caveats
- ❌ Unexpected behavior
- 🔴 Bug or data loss risk

---

## Detailed Scenario Analysis

### Scenario 1: Simple Staged File

**Setup**:
```bash
echo "hello" > file.txt
git add file.txt
# file.txt is staged, needs trailing newline fix
```

#### Config A (Stash):
```
1. No unstaged changes, stash is empty
2. Fix adds newline to file.txt
3. Stages the fix
4. Commits
✅ Result: file.txt committed with newline
```

#### Config B (No Stash):
```
1. Fix adds newline to file.txt
2. Stages the fix
3. Commits
✅ Result: file.txt committed with newline
```

#### Config C (Check Only):
```
1. Check detects missing newline
2. Blocks commit with error
3. User must run fix manually
⚠️ Result: Commit blocked, requires manual fix
```

#### Config D (Separate):
```
1. Pre-commit check detects issue
2. Blocks commit
3. User runs: hk fix
4. User runs: git add file.txt
5. User runs: hk commit -m "msg"
✅ Result: Controlled workflow, explicit fixes
```

**Winner**: A or B for convenience, D for control

---

### Scenario 2: Staged + Unstaged on Same File ⚠️ CRITICAL

**Setup**:
```bash
# Initial: file.txt contains "line1\nline2\n"
echo "line3" >> file.txt
git add file.txt
# Staged: "line1\nline2\nline3\n"

echo "line4" >> file.txt
# Working tree: "line1\nline2\nline3\nline4\n"
# Unstaged: the line4 addition
```

#### Config A (Stash):
```
1. Stash creates: "diff: +line4"
2. Working tree reverts to: "line1\nline2\nline3\n"
3. Fix step runs (e.g., adds final newline)
4. Working tree now: "line1\nline2\nline3\n\n"
5. Commit created
6. Stash apply: "diff: +line4"
7. Apply to: "line1\nline2\nline3\n\n"

Result depends on patch application:
- ✅ If applies cleanly: "line1\nline2\nline3\n\nline4\n"
- 🔴 If conflicts: Merge conflict or stash orphaned
- ⚠️ If fix modified line3: High chance of conflict

Risk: HIGH for conflicts if fix touches nearby lines
```

#### Config B (No Stash):
```
1. Fix runs on working tree: "line1\nline2\nline3\nline4\n"
2. Fix adds final newline: "line1\nline2\nline3\nline4\n\n"
3. Stages ALL of file.txt
4. Commits including line4

❌ Result: Committed MORE than intended (line4 was unstaged!)
Risk: CRITICAL - auto-stages unstaged changes
```

#### Config C (Check Only):
```
1. Check runs on staged version: "line1\nline2\nline3\n"
2. If check fails: Blocks commit
3. Unstaged line4 untouched

✅ Result: Clean, predictable
Risk: NONE
```

#### Config D (Separate):
```
1. Pre-commit checks staged version
2. If fails: User runs `hk fix`
3. Fix modifies working tree with line4
4. User reviews changes
5. User decides: stage all or partial

✅ Result: User controls what gets committed
Risk: NONE
```

**Winner**: C or D - A risks conflicts, B risks unintended commits

---

### Scenario 3: Only Unstaged Files Present

**Setup**:
```bash
# Nothing staged
echo "new content" > new-file.txt
# new-file.txt is untracked/unstaged
```

#### Config A (Stash):
```
1. Stash saves new-file.txt
2. Working tree is clean
3. No files to fix
4. Commit (might be empty commit?)
5. Stash restore

✅ Result: new-file.txt restored, untouched
Risk: LOW
```

#### Config B (No Stash):
```
1. Fix runs on new-file.txt
2. Stages new-file.txt
3. Commits it

❌ Result: Untracked file committed!
Risk: CRITICAL - commits unintended files
```

#### Config C (Check Only):
```
1. Check runs on staged files only
2. new-file.txt ignored (not staged)

✅ Result: Clean, predictable
Risk: NONE
```

#### Config D (Separate):
```
Same as Config C

✅ Result: User controls staging
Risk: NONE
```

**Winner**: A, C, or D - B is dangerous!

---

### Scenario 4: Fix Step Fails (Exit 1) 🔴 BUG TERRITORY

**Setup**:
```bash
echo "content" > file.txt
git add file.txt
# Fix step will exit 1
```

#### Config A (Stash):
```
1. Stash created (if unstaged changes exist)
2. Fix step runs
3. Fix exits 1 ❌
4. Commit should be prevented
5. Stash restore should happen

Potential bugs:
- 🔴 BUG: Stash not restored (orphaned)
- 🔴 BUG: Partial fixes committed before failure
- 🔴 BUG: Exit code not propagated

Test with: test-exit-codes.sh Test 4, 5
```

#### Config B (No Stash):
```
1. Fix step runs
2. Fix exits 1 ❌
3. Commit should be prevented
4. Modified files left in working tree?

Potential bugs:
- 🔴 BUG: Modifications from failed fix left in tree
- 🔴 BUG: Partial staging

Test with: test-exit-codes.sh Test 3
```

#### Config C (Check Only):
```
1. Check runs
2. Check exits 1 ❌
3. Commit prevented
4. Clean error message

✅ Result: Clean failure, no side effects
Risk: NONE
```

#### Config D (Separate):
```
Same as Config C for pre-commit

If user runs `hk fix` and it fails:
- Files may be modified
- User sees error
- User can inspect and decide

✅ Result: Transparent failures
Risk: LOW - user initiated
```

**Winner**: C or D - A and B have potential bugs

---

### Scenario 5: Deleted File + Other Changes

**Setup**:
```bash
# file1.txt exists, committed
rm file1.txt
git add file1.txt  # Stage deletion

echo "new" > file2.txt
git add file2.txt  # Stage addition
```

#### Config A (Stash):
```
1. Stash may save file1.txt deletion (?)
2. Fix runs on staged files
3. Commit
4. Stash restore

Potential issues:
- 🔴 file1.txt might reappear (Issue #1)
- Depends on how git stash handles deletions

Test with: test-issue-1.sh
```

#### Config B (No Stash):
```
1. Fix runs on file2.txt
2. file1.txt deletion staged
3. Commit

⚠️ Result: Depends on fix behavior
May or may not have Issue #1
```

#### Config C (Check Only):
```
1. Check runs
2. Deletion and addition committed
3. No fix interference

✅ Result: Clean deletion
Risk: NONE
```

#### Config D (Separate):
```
Same as Config C

✅ Result: User controls process
Risk: NONE
```

**Winner**: C or D - A may have deletion reappearance bug

---

### Scenario 6: Binary Files

**Setup**:
```bash
# Add image.png
git add image.png
echo "text" > text.txt  # Unstaged
```

#### Config A (Stash):
```
1. Stash text.txt
2. Fix runs (likely skips binary files)
3. Commit
4. Stash restore

⚠️ Issues:
- Stashing binary files can be slow
- Stash diffs may be large
- Generally works but inefficient

Test needed: Binary file stash performance
```

#### Config B (No Stash):
```
1. Fix runs, skips binary
2. text.txt also processed

❌ Result: May stage text.txt
Risk: MEDIUM
```

#### Config C (Check Only):
```
1. Checks likely skip binary
2. Clean commit

✅ Result: Works well
Risk: NONE
```

#### Config D (Separate):
```
Same as C

✅ Result: Explicit control
Risk: NONE
```

**Winner**: C or D - A is slow, B may auto-stage

---

### Scenario 7: Multiple Files, One Fix Fails

**Setup**:
```bash
echo "content1" > file1.txt
echo "content2" > file2.txt
echo "content3" > file3.txt
git add *.txt

# file1.txt fix succeeds
# file2.txt fix fails (exit 1)
# file3.txt fix never runs
```

#### Config A (Stash):
```
Order of operations:
1. Fix file1.txt ✅
2. Fix file2.txt ❌ (exit 1)
3. file3.txt not processed

Questions:
- Is file1.txt fix committed?
- Is file1.txt fix staged?
- Is file1.txt fix rolled back?

🔴 CRITICAL BUG TERRITORY: No atomic rollback?

Test with: test/exit-code-mixed branch
```

#### Config B (No Stash):
```
Same issues as Config A

🔴 CRITICAL: Partial fixes may be committed
```

#### Config C (Check Only):
```
If any check fails:
- Entire commit blocked
- No partial staging

✅ Result: All-or-nothing
Risk: NONE
```

#### Config D (Separate):
```
User runs `hk fix`:
- Partial fixes possible
- User can review before committing

✅ Result: Transparent
Risk: LOW - user sees the state
```

**Winner**: C or D - A and B lack atomicity

---

### Scenario 8: Glob Patterns and File Selection

**Setup**:
```bash
# Different globs for different linters
echo "code" > src/code.js
echo "test" > test/test.js
git add src/code.js  # Staged

# Unstaged:
echo "more code" > src/more.js
```

**Config with globs**:
```pkl
["js-linter"] {
  glob = "src/**/*.js"
  fix = "prettier --write {{ files }}"
}
```

#### Config A (Stash):
```
1. Stash src/more.js (unstaged)
2. Fix src/code.js (staged, matches glob)
3. Commit
4. Restore stash

✅ Result: Only staged files in src/ fixed
Risk: LOW - glob isolation works
```

#### Config B (No Stash):
```
1. Fix BOTH src/code.js AND src/more.js (both match glob)
2. Stage BOTH files
3. Commit BOTH

❌ Result: Unstaged src/more.js committed!
Risk: CRITICAL with globs
```

#### Config C (Check Only):
```
1. Check only staged src/code.js
2. src/more.js ignored

✅ Result: Predictable
Risk: NONE
```

#### Config D (Separate):
```
User runs fix, sees both files changed, chooses what to stage

✅ Result: User controls
Risk: NONE
```

**Winner**: A, C, or D - B is very dangerous with globs

---

## Edge Cases

### Edge Case 1: Empty Staged Changes

```bash
# Nothing staged
hk commit -m "empty"
```

**Expected**: Prevent empty commit or create empty commit (configurable)

**Config A**: Stash is no-op, may create empty commit
**Config B**: May find unstaged files and commit them ❌
**Config C**: Likely prevents commit
**Config D**: User controls

---

### Edge Case 2: File Renamed

```bash
git mv old.txt new.txt
git add .

# Unstaged changes to new.txt
echo "more" >> new.txt
```

**Config A**: Stashes changes to new.txt, commits rename
**Config B**: Commits rename + unstaged changes ❌
**Config C**: Commits rename only
**Config D**: User controls

---

### Edge Case 3: Submodule Changes

```bash
cd submodule
git pull
cd ..
git add submodule  # Staged submodule update

# Other unstaged changes
echo "readme" > README.md
```

**Config A**: Stashes README.md, commits submodule
**Config B**: May commit both ❌
**Config C**: Commits submodule only
**Config D**: User controls

---

### Edge Case 4: Symlink Handling

```bash
ln -s target.txt link.txt
git add link.txt

# Unstaged: modify target
echo "new" > target.txt
```

**Behavior varies by config and fix step**

---

### Edge Case 5: File Permissions

```bash
chmod +x script.sh
git add script.sh

# Unstaged: modify content
echo "# comment" >> script.sh
```

**Config A**: Stashes content change, commits permission
**Config B**: Commits both ❌
**Config C**: Commits permission only
**Config D**: User controls

---

### Edge Case 6: Very Large Files

**Config A**: Stashing large files is SLOW
**Config B**: Fixing large files is SLOW
**Config C**: Checking is usually fast
**Config D**: User decides when to pay the cost

---

## Recommendations by Use Case

### Use Case 1: Solo Developer, Small Project

**Recommended**: Config B (No Stash)

**Rationale**:
- Simplicity over precision
- Unlikely to have complex staged/unstaged splits
- Fast workflow

**Risks**:
- May commit more than intended
- Need to review commits carefully

---

### Use Case 2: Team Project, CI/CD

**Recommended**: Config C or D (Check Only / Separate Fix)

**Rationale**:
- Safety critical
- Clear failure modes
- CI-friendly exit codes
- No surprises

**Risks**:
- Less convenient (manual fixes)
- More steps in workflow

---

### Use Case 3: Monorepo with Many File Types

**Recommended**: Config D (Separate Fix)

**Rationale**:
- Different fixes for different file types
- User needs control over what's staged
- Partial commits common

**Risks**:
- Requires discipline to run fixes

---

### Use Case 4: Automated Commits (CI Bot)

**Recommended**: Config B or C

**Config B** if auto-fixing is goal:
```bash
git add .
hk commit -m "auto: format all files"
```

**Config C** if validation is goal:
```bash
git add .
if ! hk commit -m "auto: update"; then
  echo "Validation failed!"
  exit 1
fi
```

---

### Use Case 5: Strict Code Review Process

**Recommended**: Config C (Check Only)

**Rationale**:
- No automatic modifications
- Reviewers see exactly what developer wrote
- Fixes are explicit

---

### Use Case 6: Learning Git/Hooks

**Recommended**: Config C (Check Only)

**Rationale**:
- Predictable behavior
- No hidden magic
- Clear error messages

---

## Migration Guide

### From Config A (Stash) to Config D (Separate)

**Before** (`hk.pkl`):
```pkl
["pre-commit"] {
  fix = true
  stash = "git"
  steps = linters
}
```

**After**:
```pkl
["pre-commit"] {
  fix = false  // Changed
  steps = linters
}

["fix"] {      // Added
  fix = true
  steps = linters
}
```

**Workflow Change**:
```bash
# Old workflow:
git add file.txt
hk commit -m "msg"  # Auto-fixes and commits

# New workflow:
git add file.txt
hk commit -m "msg"  # Fails if issues found
hk fix              # Fix issues
git add file.txt    # Stage fixes
hk commit -m "msg"  # Succeeds
```

**Migration Steps**:
1. Update `hk.pkl` configuration
2. Test on a feature branch
3. Update team documentation
4. Communicate workflow change
5. Add to onboarding docs

---

### From Config B (No Stash) to Config D

**Benefit**: Prevent accidental commits of unstaged changes

**Risk**: More manual steps

**Migration**: Same as above

---

### From Config C to Config D

**Benefit**: Add convenient fix command

**Risk**: None (only adding feature)

**Migration**: Just add `["fix"]` hook

---

## Summary

### Best Practices

1. **Default to Config D** (Separate Fix) for most projects
2. **Use Config C** (Check Only) if maximum safety is required
3. **Avoid Config A** (Stash) unless you need strict staged/unstaged separation and understand the risks
4. **Avoid Config B** (No Stash) unless you're okay with auto-staging

### Key Insights

1. **Stashing is complex** and error-prone
2. **Auto-fixing without stash** can commit unintended changes
3. **Check-only is safest** but less convenient
4. **Separate fix command** is best balance

### Testing Checklist

- [ ] Test simple staged file
- [ ] Test staged + unstaged on same file
- [ ] Test only unstaged files
- [ ] Test fix step failure
- [ ] Test deleted files
- [ ] Test binary files
- [ ] Test multiple files, one fails
- [ ] Test glob patterns
- [ ] Test file renames
- [ ] Test large files

### Files for Reference

- Test scripts: `test-exit-codes.sh:1`
- Bug analysis: `EXIT-CODE-BUGS.md:1`
- Configuration examples: `setup-exit-code-tests.sh:1`
- Original issues: `ANALYSIS.md:1`

---

**End of Document**
