#!/bin/bash
# Test Exit Code Handling: How fix steps with exit codes impact commits
# This tests whether failing fix steps (exit 1) properly prevent commits

set -e

echo "=== Testing Exit Code Handling in Fix Steps ==="
echo "Branch: $(git branch --show-current)"
echo "Has hk.pkl: $([ -f hk.pkl ] && echo 'YES' || echo 'NO')"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function to report test results
report_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        echo "   Expected: $expected, Got: $actual"
    else
        echo -e "${RED}🔴 FAIL${NC}: $test_name"
        echo "   Expected: $expected, Got: $actual"
    fi
    echo ""
}

# Clean up any previous test
echo "Cleaning up previous test state..."
git reset --hard HEAD
git clean -fd
echo ""

# Test 1: Fix step that exits with code 1 should prevent commit
echo "=================================================="
echo "TEST 1: Fix step exits with 1 → commit should FAIL"
echo "=================================================="

# Create a test file
echo "test content" > test-file.txt
git add test-file.txt

# Get initial commit count
INITIAL_COMMITS=$(git rev-list --count HEAD)

# Try to commit (this will fail if hk.pkl has a failing fix step)
if [ -f hk.pkl ]; then
    echo "Running: hk commit -m 'test: should fail'"
    EXIT_CODE=0
    hk commit -m "test: should fail with exit 1" || EXIT_CODE=$?

    # Check if commit was prevented
    FINAL_COMMITS=$(git rev-list --count HEAD)

    if [ $EXIT_CODE -ne 0 ]; then
        echo "✓ hk commit returned non-zero exit code: $EXIT_CODE"
    else
        echo "✗ hk commit returned zero exit code (success)"
    fi

    if [ "$INITIAL_COMMITS" = "$FINAL_COMMITS" ]; then
        echo "✓ Commit was prevented (commit count unchanged)"
        COMMIT_PREVENTED="true"
    else
        echo "✗ Commit was created despite exit 1"
        COMMIT_PREVENTED="false"
    fi

    # Check file state
    if git diff --cached --quiet; then
        echo "✗ No staged changes (file was unstaged)"
        FILE_STATE="unstaged"
    else
        echo "✓ File remains staged"
        FILE_STATE="staged"
    fi

    report_result "Fix exit 1 prevents commit" "prevented" "$COMMIT_PREVENTED"
    report_result "Exit code propagation" "non-zero" "$([ $EXIT_CODE -ne 0 ] && echo 'non-zero' || echo 'zero')"
    report_result "File state after failed fix" "staged" "$FILE_STATE"
else
    echo "SKIPPED: No hk.pkl found (using pure git)"
    git commit -m "test: baseline commit"
fi

# Clean up for next test
git reset --hard HEAD
git clean -fd
echo ""

# Test 2: Fix step that modifies file and exits 0 should commit
echo "=================================================="
echo "TEST 2: Fix step modifies file & exits 0 → commit should SUCCEED"
echo "=================================================="

echo "line without newline" > test-file-2.txt
# Note: file ends without newline
git add test-file-2.txt

INITIAL_COMMITS=$(git rev-list --count HEAD)

if [ -f hk.pkl ]; then
    echo "Running: hk commit -m 'test: should succeed'"
    EXIT_CODE=0
    hk commit -m "test: should succeed with auto-fix" || EXIT_CODE=$?

    FINAL_COMMITS=$(git rev-list --count HEAD)

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✓ hk commit returned zero exit code"
    else
        echo "✗ hk commit returned non-zero: $EXIT_CODE"
    fi

    if [ "$FINAL_COMMITS" -gt "$INITIAL_COMMITS" ]; then
        echo "✓ Commit was created"
        COMMIT_CREATED="true"
    else
        echo "✗ Commit was not created"
        COMMIT_CREATED="false"
    fi

    # Check if fix was applied (should have newline now)
    LAST_CHAR=$(tail -c 1 test-file-2.txt | od -An -tx1)
    if [ -n "$LAST_CHAR" ] && [ "$LAST_CHAR" != " 00" ]; then
        echo "✓ Fix was applied (file ends with newline)"
        FIX_APPLIED="true"
    else
        echo "✗ Fix was not applied"
        FIX_APPLIED="false"
    fi

    report_result "Fix exit 0 allows commit" "created" "$COMMIT_CREATED"
    report_result "Auto-fix applied to committed file" "true" "$FIX_APPLIED"
else
    echo "SKIPPED: No hk.pkl found"
fi

# Clean up for next test
git reset --hard HEAD
git clean -fd
echo ""

# Test 3: Fix step modifies file and exits 1 - what happens to changes?
echo "=================================================="
echo "TEST 3: Fix step modifies file & exits 1 → what happens to changes?"
echo "=================================================="

echo "test content without modifications" > test-file-3.txt
git add test-file-3.txt
git commit -m "test: initial commit for modification test"

# Now modify and stage
echo "staged modification" >> test-file-3.txt
git add test-file-3.txt

# Save the staged content
STAGED_CONTENT_BEFORE=$(git show :test-file-3.txt)

INITIAL_COMMITS=$(git rev-list --count HEAD)

if [ -f hk.pkl ]; then
    echo "Running: hk commit with a fix that modifies then fails"
    EXIT_CODE=0
    hk commit -m "test: fix modifies then fails" || EXIT_CODE=$?

    FINAL_COMMITS=$(git rev-list --count HEAD)

    # Check what happened to the file
    if [ -f test-file-3.txt ]; then
        WORKING_CONTENT=$(cat test-file-3.txt)
        if git diff --cached --quiet test-file-3.txt; then
            STAGED_STATUS="no staged changes"
        else
            STAGED_CONTENT_AFTER=$(git show :test-file-3.txt 2>/dev/null || echo "NOT_STAGED")
            if [ "$STAGED_CONTENT_AFTER" = "$STAGED_CONTENT_BEFORE" ]; then
                STAGED_STATUS="staged (unchanged)"
            else
                STAGED_STATUS="staged (modified by fix)"
            fi
        fi
    else
        WORKING_CONTENT="FILE DELETED"
        STAGED_STATUS="unknown"
    fi

    report_result "Commit prevented by failing fix" "prevented" "$([ $INITIAL_COMMITS -eq $FINAL_COMMITS ] && echo 'prevented' || echo 'created')"
    echo "Working tree state: $WORKING_CONTENT"
    echo "Staged state: $STAGED_STATUS"
else
    echo "SKIPPED: No hk.pkl found"
fi

echo ""

# Test 4: Unstaged changes preserved when fix step fails
echo "=================================================="
echo "TEST 4: Unstaged changes preserved when fix exits 1"
echo "=================================================="

git reset --hard HEAD
git clean -fd

# Create initial file
echo "initial content" > test-file-4.txt
git add test-file-4.txt
git commit -m "test: initial for unstaged test"

# Make staged change
echo "staged change" >> test-file-4.txt
git add test-file-4.txt

# Make unstaged change to DIFFERENT file
echo "unstaged change - should be preserved" > unstaged-file.txt

UNSTAGED_CONTENT_BEFORE=$(cat unstaged-file.txt)

if [ -f hk.pkl ]; then
    echo "Running: hk commit (fix will fail)"
    hk commit -m "test: unstaged should be preserved" || true

    # Check if unstaged file still exists with same content
    if [ -f unstaged-file.txt ]; then
        UNSTAGED_CONTENT_AFTER=$(cat unstaged-file.txt)
        if [ "$UNSTAGED_CONTENT_BEFORE" = "$UNSTAGED_CONTENT_AFTER" ]; then
            echo "✓ Unstaged file preserved with correct content"
            UNSTAGED_PRESERVED="true"
        else
            echo "✗ Unstaged file content changed"
            UNSTAGED_PRESERVED="modified"
        fi
    else
        echo "✗ Unstaged file was deleted"
        UNSTAGED_PRESERVED="false"
    fi

    # Check stash list for orphaned stashes
    STASH_COUNT=$(git stash list | wc -l)
    if [ "$STASH_COUNT" -gt 0 ]; then
        echo "⚠️  Warning: $STASH_COUNT stash(es) found - possible orphaned stash"
        git stash list
    fi

    report_result "Unstaged changes preserved on fix failure" "true" "$UNSTAGED_PRESERVED"
else
    echo "SKIPPED: No hk.pkl found"
fi

echo ""

# Test 5: Interaction with stash when fix fails
echo "=================================================="
echo "TEST 5: Stash interaction when fix exits 1"
echo "=================================================="

git reset --hard HEAD
git clean -fd

# Create initial file
echo "initial" > test-file-5.txt
git add test-file-5.txt
git commit -m "test: initial for stash test"

# Stage a change
echo "staged change" >> test-file-5.txt
git add test-file-5.txt

# Make unstaged change to SAME file
echo "unstaged change to same file" >> test-file-5.txt

WORKING_TREE_BEFORE=$(cat test-file-5.txt)
STASH_COUNT_BEFORE=$(git stash list | wc -l)

if [ -f hk.pkl ] && grep -q 'stash = "git"' hk.pkl; then
    echo "Config has stash enabled, testing stash behavior..."

    hk commit -m "test: stash interaction with failing fix" || true

    WORKING_TREE_AFTER=$(cat test-file-5.txt)
    STASH_COUNT_AFTER=$(git stash list | wc -l)

    if [ "$WORKING_TREE_BEFORE" = "$WORKING_TREE_AFTER" ]; then
        echo "✓ Working tree unchanged after failed commit"
        WORKING_TREE_STATUS="preserved"
    else
        echo "✗ Working tree changed"
        echo "Before: $WORKING_TREE_BEFORE"
        echo "After: $WORKING_TREE_AFTER"
        WORKING_TREE_STATUS="changed"
    fi

    if [ "$STASH_COUNT_AFTER" -gt "$STASH_COUNT_BEFORE" ]; then
        echo "⚠️  Stash count increased: orphaned stash detected"
        STASH_STATUS="orphaned"
        git stash list
    else
        echo "✓ No orphaned stashes"
        STASH_STATUS="clean"
    fi

    report_result "Working tree preserved on failed commit" "preserved" "$WORKING_TREE_STATUS"
    report_result "No orphaned stashes" "clean" "$STASH_STATUS"
elif [ -f hk.pkl ]; then
    echo "Config does not have stash enabled, skipping stash test"
else
    echo "SKIPPED: No hk.pkl found"
fi

echo ""
echo "=== Summary ==="
echo ""
echo "All tests completed. Review the results above for:"
echo "1. Whether fix exit 1 properly prevents commits"
echo "2. Whether exit codes propagate correctly"
echo "3. What happens to file modifications when fix fails"
echo "4. Whether unstaged changes are preserved"
echo "5. Whether stash creates orphaned entries on failure"
echo ""
echo "Expected behavior:"
echo "  - Fix step with exit 1 should PREVENT commit"
echo "  - Exit code should propagate (non-zero)"
echo "  - Staged changes should remain staged (not lost)"
echo "  - Unstaged changes should be preserved"
echo "  - No orphaned stashes should be created"
echo ""
