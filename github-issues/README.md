# GitHub Issues for hk Project

This directory contains standalone, minimal reproduction issues ready to submit to the [hk project](https://github.com/jdx/hk/issues).

## Issues Prepared

### Issue 1: Fix step exit code 1 does not prevent commit (CRITICAL)
**File**: `issue-1-exit-code-not-preventing-commit.md`

**Summary**: When fix steps exit with code 1, commits may still be created and/or exit codes don't propagate to the shell.

**Impact**:
- Breaks CI/CD pipelines
- Broken code gets committed
- Automation scripts fail silently

**Severity**: CRITICAL

---

### Issue 2: Fix step that modifies files then exits 1 leaves files in unexpected state (HIGH)
**File**: `issue-2-failed-fix-leaves-modifications.md`

**Summary**: When fix steps modify files then fail, the modifications remain in the working tree/staging area without rollback.

**Impact**:
- Files left in broken state
- User confusion
- Accidental commits of broken fixes

**Severity**: HIGH

---

### Issue 3: Orphaned stash when fix step fails with `stash = "git"` (HIGH)
**File**: `issue-3-orphaned-stash-on-failure.md`

**Summary**: When `stash = "git"` is enabled and fix steps fail, stashes are not restored, leading to orphaned stashes and perceived data loss.

**Impact**:
- Unstaged changes appear lost
- Stash pollution
- Manual recovery required

**Severity**: HIGH

---

## Submission Checklist

Before submitting each issue:

- [ ] Test the reproduction steps on latest hk version
- [ ] Verify the issue still exists
- [ ] Update hk version in issue template
- [ ] Add actual output from reproduction
- [ ] Search existing issues for duplicates
- [ ] Submit to https://github.com/jdx/hk/issues

## Issue Format

Each issue follows a consistent structure:

1. **Title**: Clear, concise description of the bug
2. **Description**: Brief summary of the issue and impact
3. **Reproduction**: Standalone bash script that reproduces the issue from scratch
4. **Expected behavior**: What should happen
5. **Actual behavior**: What actually happens
6. **Impact**: Real-world consequences
7. **Environment**: Version and system info
8. **Workaround**: Temporary solution if available

## Related Documentation

For detailed analysis of these bugs and additional bugs not included here:

- `../EXIT-CODE-BUGS.md` - Analysis of all 7 identified bugs
- `../EXIT-CODE-INVESTIGATION.md` - Executive summary
- `../UNSTAGED-FILES-TRADEOFFS.md` - Configuration recommendations
- `../test-exit-codes.sh` - Comprehensive test suite

## Testing

To test these issues locally:

```bash
# Test Issue 1
bash -xe issue-1-exit-code-not-preventing-commit.md

# Test Issue 2
bash -xe issue-2-failed-fix-leaves-modifications.md

# Test Issue 3
bash -xe issue-3-orphaned-stash-on-failure.md
```

Or use the comprehensive test suite:

```bash
cd ..
./setup-exit-code-tests.sh
./run-all-exit-code-tests.sh
```

## Notes

- All reproduction scripts create a fresh `hk-test` directory
- Issues are written to be self-contained with no external dependencies
- Each issue can be copy-pasted directly into GitHub
- Includes workarounds and suggested fixes where applicable
