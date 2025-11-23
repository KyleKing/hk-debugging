# Fix step that modifies files then exits 1 leaves files in unexpected state

## Description

When a fix step modifies files and then exits with code 1, the modifications remain in the working tree and/or staging area. The expected behavior is unclear, but this creates unexpected file states that can confuse users and lead to accidental commits of broken fixes.

## Reproduction

Create a minimal test repository:

```bash
# Create test repo
mkdir hk-test && cd hk-test
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Create hk.pkl with a fix step that modifies then fails
cat > hk.pkl <<'EOF'
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local modify_then_fail = new Mapping<String, Step> {
  ["broken-fixer"] {
    glob = "*.txt"
    check_first = false  // Always run fix
    fix = "echo '# BROKEN FIX APPLIED' >> {{ files }} && exit 1"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = modify_then_fail
  }
}
EOF

git add hk.pkl
git commit -m "initial commit"

# Create a test file
echo "original content" > test.txt
git add test.txt

# Save original content for comparison
ORIGINAL=$(cat test.txt)

# Attempt commit (fix will modify then fail)
hk commit -m "test commit" || true

# Check file state
echo "=== Working tree content ==="
cat test.txt
echo ""
echo "=== Staged content ==="
git show :test.txt 2>/dev/null || echo "Not staged"
echo ""
echo "=== Git status ==="
git status --short
```

## Expected behavior

**Option A** (Rollback):
```
=== Working tree content ===
original content

=== Staged content ===
original content

=== Git status ===
A  test.txt
```

The fix step's modifications should be **rolled back** since it failed.

**Option B** (Keep but clear documentation):
Clear documentation of what happens to modifications when fix fails.

## Actual behavior

```
=== Working tree content ===
original content
# BROKEN FIX APPLIED

=== Staged content ===
original content
# BROKEN FIX APPLIED

=== Git status ===
A  test.txt
```

The broken modification from the failing fix step remains in the file. This is problematic because:
1. User doesn't know the file was modified
2. Next commit attempt might include the broken fix
3. Unclear if this is in working tree, staging area, or both

## Impact

- **Broken state**: Files contain modifications from failed fixes
- **User confusion**: Unexpected file states after failed commits
- **Accidental commits**: Broken fixes may be committed on retry
- **Data integrity**: Files may be in inconsistent state

## Example problematic scenario

```bash
# Step 1: User commits file, fix modifies then fails
hk commit -m "add feature"  # Fails, but file is modified

# Step 2: User fixes the validation error manually
vim test.txt  # User doesn't realize file already has broken modifications

# Step 3: User commits again
hk commit -m "add feature"  # Succeeds, but includes BOTH user's fix AND broken modification
```

## Environment

- **hk version**: `1.15.6` (or specify your version)
- **OS**: Linux / macOS / Windows
- **Shell**: bash

## Possible solutions

1. **Rollback modifications on fix failure**: Save file state before fix, restore on failure
2. **Document behavior clearly**: Explicitly state that modifications are kept
3. **Warn user**: Print warning when fix modifies files then fails
4. **Stash modifications**: Put failed fix modifications in a separate stash

## Workaround

Avoid fix steps that can fail after modifying files. Use validation before modification:

```pkl
["safe-fixer"] {
  check = "validate {{ files }}"  // Check first
  fix = "safe-fix {{ files }}"    // Only fix if check passes
}
```

Or use `fix = false` and manual fixing:

```pkl
["pre-commit"] {
  fix = false  // Check only, never modify
}
```
