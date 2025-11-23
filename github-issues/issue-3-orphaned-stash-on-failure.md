# Orphaned stash when fix step fails with `stash = "git"`

## Description

When `stash = "git"` is configured and a fix step exits with code 1, the stash created before running hooks may not be properly restored. This leaves an orphaned stash entry and can result in perceived data loss of unstaged changes.

## Reproduction

Create a minimal test repository:

```bash
# Create test repo
mkdir hk-test && cd hk-test
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Create hk.pkl with stash enabled and failing fix
cat > hk.pkl <<'EOF'
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local failing_linter = new Mapping<String, Step> {
  ["always-fail"] {
    check = "exit 1"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    stash = "git"  // Enable stashing
    steps = failing_linter
  }
}
EOF

git add hk.pkl
git commit -m "initial commit"

# Create an initial committed file
echo "committed content" > file.txt
git add file.txt
git commit -m "add file"

# Make staged change
echo "staged change" >> file.txt
git add file.txt

# Make unstaged change (this will be stashed)
echo "unstaged change - should be preserved" > other.txt

# Save unstaged content
UNSTAGED_BEFORE=$(cat other.txt)

# Count stashes before
STASH_COUNT_BEFORE=$(git stash list | wc -l)
echo "Stashes before: $STASH_COUNT_BEFORE"

# Attempt commit (will fail, creates stash)
hk commit -m "test commit" || true

# Check stash count after
STASH_COUNT_AFTER=$(git stash list | wc -l)
echo "Stashes after: $STASH_COUNT_AFTER"

# Check if unstaged file still exists
if [ -f other.txt ]; then
    UNSTAGED_AFTER=$(cat other.txt)
    echo "Unstaged file exists: $UNSTAGED_AFTER"
else
    echo "Unstaged file MISSING"
fi

# List stashes
echo ""
echo "=== Stash list ==="
git stash list
```

## Expected behavior

```
Stashes before: 0
Stashes after: 0
Unstaged file exists: unstaged change - should be preserved

=== Stash list ===
(empty)
```

The stash should be **automatically restored** even when the fix step fails, leaving no orphaned stashes.

## Actual behavior

**Scenario A** (orphaned stash):
```
Stashes before: 0
Stashes after: 1
Unstaged file MISSING

=== Stash list ===
stash@{0}: On main: hk autostash
```

The unstaged changes are in the stash but not restored to the working tree.

**Scenario B** (partial restore):
```
Stashes before: 0
Stashes after: 0
Unstaged file exists: <different or corrupted content>
```

Stash was restored but content is incorrect.

## Impact

- **Perceived data loss**: Users think their unstaged changes are gone
- **Stash pollution**: Orphaned stashes accumulate over time
- **User confusion**: Unclear how to recover unstaged changes
- **Manual recovery required**: Users must manually apply stash

## Recovery steps (if orphaned)

```bash
# Check stash list
git stash list

# Manually apply the orphaned stash
git stash pop stash@{0}

# Or if there are conflicts
git stash apply stash@{0}
# Resolve conflicts
git stash drop stash@{0}
```

## Environment

- **hk version**: `1.15.6` (or specify your version)
- **OS**: Linux / macOS / Windows
- **Shell**: bash

## Root cause hypothesis

The stash restore logic may not be in a `finally` block or equivalent error handling, so when the fix step fails, the cleanup code that restores the stash is never reached:

```
Pseudocode:
1. Create stash
2. Run fix steps  <-- Exits here with error
3. Commit
4. Restore stash  <-- Never reached
```

## Suggested fix

Ensure stash restoration happens in all cases:

```rust
// Pseudocode
let stash_ref = create_stash()?;

// Use defer/finally/RAII to ensure restoration
let _guard = StashGuard::new(stash_ref);

// Run hooks (may fail)
run_hooks()?;

// Stash automatically restored by guard destructor
```

Or use trap in shell-based implementation:

```bash
stash_ref=$(git stash create)
trap "git stash apply $stash_ref || true" EXIT

# Run hooks (may fail)
run_hooks

# Trap ensures stash is always restored
```

## Workaround

**Option 1**: Disable stashing

```pkl
hooks = new {
  ["pre-commit"] {
    fix = true
    // Remove: stash = "git"
    steps = linters
  }
}
```

Note: This means fixes will run on unstaged changes too, potentially staging them.

**Option 2**: Manual stash workflow

```bash
# Manually stash before commit
git stash push -u -m "manual stash"

# Commit (no auto-stash needed)
hk commit -m "message"

# Manually restore
git stash pop
```

**Option 3**: Use `fix = false`

```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // No fix, no stash needed
    steps = linters
  }
}
```
