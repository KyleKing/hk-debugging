#!/bin/bash
# Script to set up test branches locally for hk issue investigation

set -e

echo "=== Setting up HK Test Branches ==="
echo ""

# Get current branch to return to later
ORIGINAL_BRANCH=$(git branch --show-current)

# Test branch 1: Full config
echo "Creating test/hk-full-config branch..."
git checkout -b test/hk-full-config 2>/dev/null || git checkout test/hk-full-config
cat > hk.pkl <<'EOF'
// Install with `hk install --mise` to ensure local tools are available

amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Builtins.pkl"

min_hk_version = "1.15.6"

exclude = List("**/*.min.js", "**/*.ambr", "**/*.png")


local linters = new Mapping<String, Step> {
  ["actionlint"] = Builtins.actionlint

  ["pkl"] {
    glob = "*.pkl"
    check = "pkl eval {{files}} >/dev/null"
  }

  ["pch-check-added-large-files"] {
    check = "check-added-large-files {{ files }}"
  }
  ["pch-check-merge-conflict"] {
    check = "check-merge-conflict {{ files }}"
  }
  ["pch-check-symlinks"] {
    check = "check-symlinks {{ files }}"
  }
  ["pch-check-vcs-permalinks"] {
    check = "check-vcs-permalinks {{ files }}"
  }
  ["pch-check-yaml"] {
    glob = List("**/*.{yml,yaml}")
    check = "check-yaml {{ files }}"
  }
  ["pch-end-of-file-fixer"] {
    // FYI: without check, these fixers are always run!
    check_first = false // FYI: without check_first, these linters request write-locks on all files
    fix = "end-of-file-fixer {{ files }}"
  }
  ["pch-mixed-line-ending"] {
    check_first = false
    fix = "mixed-line-ending {{ files }}"
  }
  ["pch-trailing-whitespace-fixer"] {
    check_first = false
    fix = "trailing-whitespace-fixer {{ files }}"
  }

  ["toml-sort"] {
    glob = List("**/*.toml")
    check = "toml-sort --check {{ files }}"
    fix = "toml-sort --in-place {{ files }}"
  }
}

local commit_msg_checks = new Mapping<String, Step> {
  ["commitizen"] {
    check = "cz check --allow-abort --commit-msg-file={{commit_msg_file}}"
  }
}
local pre_push_checks = new Mapping<String, Step> {
  ["commitizen-branch"] {
    check = "cz check --rev-range origin/HEAD..HEAD"
  }
}

// FYI: there are additional configuration options for batch, workspace_indicator, etc. https://hk.jdx.dev/configuration.html
hooks = new {
  ["pre-commit"] {
    fix = true // automatically modify files with available linter fixes
    stash = "git" // stashes unstaged changes while running fix steps
    steps = linters
  }
  ["pre-push"] {
    steps = new {
      // FYI: PRs aren't required for this project
      // ["pch-no-commit-to-branch"] {
      //   run = "no-commit-to-branch --branch=main"
      // }
      ...pre_push_checks
      ...linters
    }
  }
  ["commit-msg"] {
    steps = commit_msg_checks
  }

  // "fix" and "check" are special steps for `hk fix` and `hk check` commands
  ["fix"] {
    fix = true
    steps = linters
  }
  ["check"] {
    steps = new {
      ...pre_push_checks
      ...linters
    }
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add full reference hk.pkl configuration"
echo "✅ test/hk-full-config ready"

# Test branch 2: No stash
echo ""
echo "Creating test/hk-no-stash branch..."
git checkout "$ORIGINAL_BRANCH"
git checkout -b test/hk-no-stash 2>/dev/null || git checkout test/hk-no-stash
cat > hk.pkl <<'EOF'
// Simplified hk config for testing - NO STASH
// This tests if stashing causes the unstaged changes issue

amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Builtins.pkl"

min_hk_version = "1.15.6"

local simple_linters = new Mapping<String, Step> {
  ["check-merge-conflict"] {
    check = "check-merge-conflict {{ files }}"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = true
    // NO STASH - testing if this causes the unstaged changes issue
    steps = simple_linters
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add hk.pkl with stash disabled"
echo "✅ test/hk-no-stash ready"

# Test branch 3: No fix
echo ""
echo "Creating test/hk-no-fix branch..."
git checkout "$ORIGINAL_BRANCH"
git checkout -b test/hk-no-fix 2>/dev/null || git checkout test/hk-no-fix
cat > hk.pkl <<'EOF'
// Simplified hk config for testing - NO FIX
// This tests if automatic fixing causes file issues

amends "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v1.15.6/hk@1.15.6#/Builtins.pkl"

min_hk_version = "1.15.6"

local simple_linters = new Mapping<String, Step> {
  ["check-merge-conflict"] {
    check = "check-merge-conflict {{ files }}"
  }
}

hooks = new {
  ["pre-commit"] {
    fix = false // NO FIX - testing if this prevents file issues
    stash = "git"
    steps = simple_linters
  }
}
EOF
git add hk.pkl
git diff --cached --quiet || git commit -m "test: add hk.pkl with fix disabled"
echo "✅ test/hk-no-fix ready"

# Return to original branch
echo ""
echo "Returning to $ORIGINAL_BRANCH..."
git checkout "$ORIGINAL_BRANCH"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Test branches created:"
echo "  - test/hk-full-config (full reference config)"
echo "  - test/hk-no-stash (stash disabled)"
echo "  - test/hk-no-fix (auto-fix disabled)"
echo ""
echo "Run tests with:"
echo "  ./test-issue-1.sh"
echo "  ./test-issue-2.sh"
echo ""
echo "Or see QUICK-START.md for automated testing across all branches."
