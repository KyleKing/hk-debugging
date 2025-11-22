#!/bin/bash
# Comprehensive test runner for exit code behavior across all configurations

set -e

echo "==============================================="
echo "Comprehensive Exit Code Testing Suite"
echo "==============================================="
echo ""

# Check if hk is installed
if ! command -v hk &> /dev/null; then
    echo "⚠️  WARNING: hk is not installed"
    echo "   These tests require hk to be installed"
    echo "   See: https://github.com/jdx/hk"
    echo ""
    echo "   Running baseline tests without hk..."
    HAVE_HK=false
else
    echo "✓ hk is installed: $(hk --version)"
    HAVE_HK=true
fi

echo ""

# Store original branch
ORIGINAL_BRANCH=$(git branch --show-current)
echo "Original branch: $ORIGINAL_BRANCH"
echo ""

# Create results directory
RESULTS_DIR="test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"
echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Test configurations to run
declare -a TEST_CONFIGS=(
    "baseline:$ORIGINAL_BRANCH:no-hk"
    "exit-fail:test/exit-code-fail:always-fails"
    "modify-fail:test/exit-code-modify-fail:modifies-then-fails"
    "no-stash:test/exit-code-fail-no-stash:fails-without-stash"
    "mixed:test/exit-code-mixed:mixed-results"
    "realistic:test/exit-code-realistic:realistic-validation"
)

# Function to run tests on a branch
run_tests_on_branch() {
    local config_name="$1"
    local branch_name="$2"
    local description="$3"

    echo "=============================================="
    echo "Testing: $description"
    echo "Branch: $branch_name"
    echo "=============================================="
    echo ""

    # Check if branch exists
    if ! git rev-parse --verify "$branch_name" &>/dev/null; then
        echo "⚠️  Branch $branch_name does not exist, skipping..."
        echo ""
        return
    fi

    # Checkout branch
    git checkout "$branch_name" 2>&1 | head -5

    # Run exit code test
    echo ""
    echo "Running exit code tests..."
    ./test-exit-codes.sh 2>&1 | tee "$RESULTS_DIR/${config_name}-exit-codes.txt"

    echo ""
    echo "---"
    echo ""
}

# Run baseline test (no hk)
run_tests_on_branch "baseline" "$ORIGINAL_BRANCH" "Baseline (no hk.pkl)"

# Only run hk tests if hk is installed
if [ "$HAVE_HK" = true ]; then
    # Set up test branches if they don't exist
    if ! git rev-parse --verify test/exit-code-fail &>/dev/null; then
        echo "Setting up exit code test branches..."
        git checkout "$ORIGINAL_BRANCH"
        ./setup-exit-code-tests.sh
        echo ""
    fi

    # Run tests on each configuration
    for config in "${TEST_CONFIGS[@]}"; do
        if [ "$config" = "baseline:$ORIGINAL_BRANCH:no-hk" ]; then
            continue  # Already ran baseline
        fi

        IFS=':' read -r config_name branch_name description <<< "$config"
        run_tests_on_branch "$config_name" "$branch_name" "$description"
    done
else
    echo "Skipping hk-specific tests (hk not installed)"
fi

# Return to original branch
git checkout "$ORIGINAL_BRANCH"

echo ""
echo "==============================================="
echo "All Tests Complete"
echo "==============================================="
echo ""
echo "Results saved in: $RESULTS_DIR/"
echo ""
echo "Summary of test files:"
ls -lh "$RESULTS_DIR/"
echo ""

# Generate summary report
echo "Generating summary report..."
cat > "$RESULTS_DIR/SUMMARY.md" <<EOF
# Exit Code Test Results Summary

**Test Run**: $(date)
**HK Installed**: $HAVE_HK

## Test Configurations

EOF

for config in "${TEST_CONFIGS[@]}"; do
    IFS=':' read -r config_name branch_name description <<< "$config"

    if [ -f "$RESULTS_DIR/${config_name}-exit-codes.txt" ]; then
        echo "### $description (\`$branch_name\`)" >> "$RESULTS_DIR/SUMMARY.md"
        echo "" >> "$RESULTS_DIR/SUMMARY.md"

        # Extract pass/fail counts
        PASS_COUNT=$(grep -c "✅ PASS" "$RESULTS_DIR/${config_name}-exit-codes.txt" || echo 0)
        FAIL_COUNT=$(grep -c "🔴 FAIL" "$RESULTS_DIR/${config_name}-exit-codes.txt" || echo 0)

        echo "- **Passed**: $PASS_COUNT" >> "$RESULTS_DIR/SUMMARY.md"
        echo "- **Failed**: $FAIL_COUNT" >> "$RESULTS_DIR/SUMMARY.md"
        echo "" >> "$RESULTS_DIR/SUMMARY.md"

        # Extract key findings
        if grep -q "🔴 FAIL" "$RESULTS_DIR/${config_name}-exit-codes.txt"; then
            echo "**Failures detected:**" >> "$RESULTS_DIR/SUMMARY.md"
            echo '```' >> "$RESULTS_DIR/SUMMARY.md"
            grep "🔴 FAIL" "$RESULTS_DIR/${config_name}-exit-codes.txt" >> "$RESULTS_DIR/SUMMARY.md"
            echo '```' >> "$RESULTS_DIR/SUMMARY.md"
        fi

        echo "" >> "$RESULTS_DIR/SUMMARY.md"
    fi
done

cat >> "$RESULTS_DIR/SUMMARY.md" <<EOF

## Bug Analysis

Based on test results, the following bugs were identified:

### Expected Bugs to Find

1. **Exit Code Propagation**: Does hk properly propagate non-zero exit codes from failed fix steps?
2. **Commit Prevention**: When a fix step exits 1, is the commit properly prevented?
3. **File State After Failure**: When a fix step modifies files then fails, what state are the files left in?
   - Are modifications kept in working tree?
   - Are changes still staged?
   - Are changes unstaged?
4. **Stash Orphaning**: When fix fails, does the stash get properly restored or is it orphaned?
5. **Unstaged Change Preservation**: When fix fails with stash enabled, are unstaged changes preserved?
6. **Partial Fix Application**: If multiple fix steps run and one fails, are previous fixes committed or rolled back?

### Investigation Needed

Review the test output files to identify which of these bugs are present.

## Files

$(ls -1 "$RESULTS_DIR/" | grep -v SUMMARY.md)

## Next Steps

1. Review individual test output files
2. Identify specific bugs from test failures
3. Document root causes
4. Propose fixes or configuration changes
EOF

echo "✅ Summary report generated: $RESULTS_DIR/SUMMARY.md"
echo ""
cat "$RESULTS_DIR/SUMMARY.md"
