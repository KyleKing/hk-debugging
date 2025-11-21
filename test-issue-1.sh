#!/bin/bash
# Test Issue #1: Deleted files reappearing as untracked

set -e

echo "=== Testing Issue #1: Deleted Files Reappearing ==="
echo "Branch: $(git branch --show-current)"
echo "Has hk.pkl: $([ -f hk.pkl ] && echo 'YES' || echo 'NO')"
echo ""

# Clean up any previous test
git reset --hard HEAD
git clean -fd

# Create test files
echo "Step 1: Creating and committing test files..."
echo "Content A" > file-to-delete.txt
echo "Content B" > file-to-keep.txt
git add file-to-delete.txt file-to-keep.txt
git commit -m "test: add files for deletion test"

echo "Step 2: Setting up the problematic scenario..."
# Delete one file
rm file-to-delete.txt
git add file-to-delete.txt

# Add a new file
echo "New content" > new-file.txt
git add new-file.txt

# Modify an existing file
echo "Modified content" >> file-to-keep.txt
git add file-to-keep.txt

echo "Step 3: Checking status before commit..."
git status

echo "Step 4: Committing changes..."
if [ -f hk.pkl ]; then
    echo "Using hk commit..."
    hk commit -m "test: delete file, add file, modify file" || echo "hk commit failed"
else
    echo "Using git commit..."
    git commit -m "test: delete file, add file, modify file"
fi

echo "Step 5: Checking status after commit..."
git status

echo "Step 6: Checking for untracked files..."
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo "⚠️  ISSUE REPRODUCED: Untracked files found:"
    echo "$UNTRACKED"

    # Check if deleted file reappeared
    if echo "$UNTRACKED" | grep -q "file-to-delete.txt"; then
        echo "🔴 CONFIRMED: Deleted file 'file-to-delete.txt' reappeared as untracked!"
    fi
else
    echo "✅ No untracked files found - working correctly"
fi

echo ""
echo "=== Test Complete ==="
