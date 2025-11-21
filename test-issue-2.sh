#!/bin/bash
# Test Issue #2: Unstaged changes lost when committing

set -e

echo "=== Testing Issue #2: Unstaged Changes Lost ==="
echo "Branch: $(git branch --show-current)"
echo "Has hk.pkl: $([ -f hk.pkl ] && echo 'YES' || echo 'NO')"
echo ""

# Clean up any previous test
git reset --hard HEAD
git clean -fd

# Create test files
echo "Step 1: Creating and committing initial files..."
echo "Initial content A" > file-with-staged-changes.txt
echo "Initial content B" > file-with-unstaged-changes.txt
git add file-with-staged-changes.txt file-with-unstaged-changes.txt
git commit -m "test: add files for unstaged changes test"

echo "Step 2: Making staged changes..."
echo "Staged modification" >> file-with-staged-changes.txt
git add file-with-staged-changes.txt

echo "Step 3: Making unstaged changes (should be preserved)..."
echo "Unstaged modification - should NOT be lost" >> file-with-unstaged-changes.txt

# Save the expected content
EXPECTED_CONTENT=$(cat file-with-unstaged-changes.txt)

echo "Step 4: Checking status before commit..."
git status
echo ""
echo "Content of file-with-unstaged-changes.txt BEFORE commit:"
cat file-with-unstaged-changes.txt
echo ""

echo "Step 5: Committing ONLY staged changes..."
if [ -f hk.pkl ]; then
    echo "Using hk commit..."
    hk commit -m "test: commit staged changes only" || echo "hk commit failed"
else
    echo "Using git commit..."
    git commit -m "test: commit staged changes only"
fi

echo "Step 6: Checking status after commit..."
git status

echo "Step 7: Verifying unstaged changes are preserved..."
echo "Content of file-with-unstaged-changes.txt AFTER commit:"
ACTUAL_CONTENT=$(cat file-with-unstaged-changes.txt 2>/dev/null || echo "FILE NOT FOUND")
echo "$ACTUAL_CONTENT"
echo ""

if [ "$EXPECTED_CONTENT" = "$ACTUAL_CONTENT" ]; then
    echo "✅ Unstaged changes preserved correctly"
else
    echo "🔴 ISSUE REPRODUCED: Unstaged changes were lost or modified!"
    echo "Expected:"
    echo "$EXPECTED_CONTENT"
    echo ""
    echo "Actual:"
    echo "$ACTUAL_CONTENT"
fi

# Check if file still has modifications
if git diff file-with-unstaged-changes.txt | grep -q "Unstaged modification"; then
    echo "✅ Unstaged modification still present in diff"
else
    echo "⚠️  Unstaged modification not found in diff"
fi

echo ""
echo "=== Test Complete ==="
