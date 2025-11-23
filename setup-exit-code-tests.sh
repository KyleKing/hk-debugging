#!/bin/bash
# Script to set up test branches for exit code investigation

set -e

echo "=== Setting up Exit Code Test Branches ==="
echo ""

# Get current branch to return to later
ORIGINAL_BRANCH=$(git branch --show-current)

# Test branch 1: Fix step that always fails (exit 1)
echo "Creating test/exit-code-fail branch..."
git checkout -b test/exit-code-fail 2>/dev/null || git checkout test/exit-code-fail
cat > hk.pkl <<'EOF'
// Test configuration: fix step always exits with 1
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local fail_linter = new Mapping<String, Step> {
  ["always-fail-check"] {
    check = "exit 1"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = fail_linter
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add config with always-failing fix step"
echo "✅ test/exit-code-fail ready"

# Test branch 2: Fix step modifies then fails
echo ""
echo "Creating test/exit-code-modify-fail branch..."
git checkout "$ORIGINAL_BRANCH"
git checkout -b test/exit-code-modify-fail 2>/dev/null || git checkout test/exit-code-modify-fail
cat > hk.pkl <<'EOF'
// Test configuration: fix step modifies files then exits with 1
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local modify_fail_linter = new Mapping<String, Step> {
  ["modify-then-fail"] {
    check_first = false  // Always run fix
    fix = "echo '# Modified by fix step' >> {{ files }} && exit 1"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = modify_fail_linter
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add config with modify-then-fail fix step"
echo "✅ test/exit-code-modify-fail ready"

# Test branch 3: Fix step fails WITHOUT stash
echo ""
echo "Creating test/exit-code-fail-no-stash branch..."
git checkout "$ORIGINAL_BRANCH"
git checkout -b test/exit-code-fail-no-stash 2>/dev/null || git checkout test/exit-code-fail-no-stash
cat > hk.pkl <<'EOF'
// Test configuration: fix step fails, NO stash
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local fail_linter = new Mapping<String, Step> {
  ["always-fail-check"] {
    check = "exit 1"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    // NO stash - testing without stash
    steps = fail_linter
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add config with failing fix, no stash"
echo "✅ test/exit-code-fail-no-stash ready"

# Test branch 4: Mixed success and failure
echo ""
echo "Creating test/exit-code-mixed branch..."
git checkout "$ORIGINAL_BRANCH"
git checkout -b test/exit-code-mixed 2>/dev/null || git checkout test/exit-code-mixed
cat > hk.pkl <<'EOF'
// Test configuration: multiple fix steps, some pass, some fail
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local mixed_linters = new Mapping<String, Step> {
  ["step-1-pass"] {
    glob = "*.txt"
    check = "exit 0"
  }
  ["step-2-fail"] {
    glob = "*.txt"
    check = "exit 1"
  }
  ["step-3-pass"] {
    glob = "*.txt"
    check = "exit 0"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = mixed_linters
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add config with mixed pass/fail steps"
echo "✅ test/exit-code-mixed ready"

# Test branch 5: Realistic fixer that can fail
echo ""
echo "Creating test/exit-code-realistic branch..."
git checkout "$ORIGINAL_BRANCH"
git checkout -b test/exit-code-realistic 2>/dev/null || git checkout test/exit-code-realistic
cat > hk.pkl <<'EOF'
// Test configuration: realistic fix step that validates and can fail
// Simulates a code formatter that might fail on syntax errors
amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"

min_hk_version = "1.15.6"

local realistic_linters = new Mapping<String, Step> {
  // Simulates a formatter that checks file validity before formatting
  ["validate-then-format"] {
    glob = "*.txt"
    // This check looks for files containing "INVALID" and fails
    check = "! grep -q 'INVALID' {{ files }}"
    // Fix attempts to remove INVALID markers, but fails if too many
    fix = "if grep -c 'INVALID' {{ files }} | grep -q '^[0-9]$'; then sed -i 's/INVALID//g' {{ files }}; else exit 1; fi"
  }

  // Simulates end-of-file fixer (common use case)
  ["eof-fixer"] {
    check_first = false
    // Adds newline if missing, can't fail
    fix = "sed -i -e '$a\\' {{ files }}"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps = realistic_linters
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add realistic config with validation"
echo "✅ test/exit-code-realistic ready"

# Return to original branch
echo ""
echo "Returning to $ORIGINAL_BRANCH..."
git checkout "$ORIGINAL_BRANCH"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Exit code test branches created:"
echo "  - test/exit-code-fail (fix always exits 1)"
echo "  - test/exit-code-modify-fail (modifies then exits 1)"
echo "  - test/exit-code-fail-no-stash (fails without stash)"
echo "  - test/exit-code-mixed (multiple steps, some fail)"
echo "  - test/exit-code-realistic (realistic validator/fixer)"
echo ""
echo "Run tests with:"
echo "  ./test-exit-codes.sh"
echo ""
