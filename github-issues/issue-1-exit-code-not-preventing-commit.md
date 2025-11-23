# Fix step exit code 1 does not prevent commit

## Description

When a fix step in `hk.pkl` exits with code 1 (failure), the commit should be prevented and `hk commit` should exit with a non-zero code. However, the commit may still be created and/or the exit code may not propagate to the shell.

This breaks CI/CD pipelines that rely on exit codes to detect failures, and can result in broken code being committed.

## Reproduction

Create a minimal test repository:

```bash
# Create test repo
mkdir hk-test && cd hk-test
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Create hk.pkl with a fix step that always fails
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
    steps = failing_linter
  }
}
EOF

git add hk.pkl
git commit -m "initial commit"

# Create a test file and try to commit
echo "test content" > test.txt
git add test.txt

# Attempt commit with failing fix step
hk commit -m "test commit"
EXIT_CODE=$?

# Check results
echo "Exit code: $EXIT_CODE"
git log --oneline | head -1
```

## Expected behavior

```
Exit code: 1
<previous commit hash> initial commit
```

The commit should be **prevented** because the fix step failed, and `hk commit` should exit with code 1.

## Actual behavior

**Scenario A** (if bug exists):
```
Exit code: 0
<new commit hash> test commit
```

The commit was created despite the failing fix step, and exit code is 0.

**Scenario B** (alternate bug):
```
Exit code: 1
<new commit hash> test commit
```

Exit code is correctly 1, but the commit was still created.

## Impact

- **CI/CD failures**: Pipelines using `set -e` or checking exit codes will not detect failures
- **Broken commits**: Code that fails validation gets committed anyway
- **Automation issues**: Scripts that depend on exit codes will proceed incorrectly

Example broken CI script:
```bash
#!/bin/bash
set -e  # Exit on error

hk commit -m "auto: update files"
# This should fail and exit if commit fails
# Instead, it continues silently

deploy.sh  # Deploys broken code!
```

## Environment

- **hk version**: `1.15.6` (or specify your version)
- **OS**: Linux / macOS / Windows
- **Shell**: bash

## Additional context

This issue appears to affect all configurations where `fix = true` is set. The problem may be related to:
1. Exit code from fix step not being checked
2. Exit code not propagating through hook execution chain
3. Commit proceeding even when hooks fail

Related: This may also affect other hook types (`pre-push`, `commit-msg`) where steps can fail.

## Workaround

Use `fix = false` and run fixes manually:

```pkl
hooks = new {
  ["pre-commit"] {
    fix = false  // Only check, don't fix
    steps = linters
  }
  ["fix"] {
    fix = true   // Manual fix command
    steps = linters
  }
}
```

Then manually run:
```bash
hk fix       # Apply fixes
git add .    # Stage fixes
hk commit    # Commit with checks only
```
