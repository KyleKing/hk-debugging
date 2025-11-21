# HouseKeeper (hk) Issues Testing Documentation

## Test Environment Setup

This document tracks the testing of hk issues across different configurations.

## Issues Under Investigation

### Issue #1: Deleted Files Reappearing
**Description**: Sometimes when there are deleted files in a commit (usually when there are also additions/deletions), the commit will succeed, but the deleted files will reappear as untracked and require manual removal.

### Issue #2: Unstaged Changes Lost
**Description**: Sometimes unstaged changes will be lost when committing (my guess is that the automatic staging is interfering).

## Test Scenarios

### Scenario 1: Baseline (No hk.pkl)
- Branch: `claude/investigate-hk-issues-016j5oackuXCqWfqLpbBE9Ah` (current)
- Configuration: No hk configuration
- Purpose: Establish baseline git behavior without hk

### Scenario 2: Full Reference Configuration
- Branch: `test/hk-full-config`
- Configuration: Complete hk.pkl from yak-shears reference
- Purpose: Test with production-like hk configuration

### Scenario 3: No Stash Configuration
- Branch: `test/hk-no-stash`
- Configuration: hk.pkl with `stash` disabled
- Purpose: Test if stashing causes unstaged changes to be lost

### Scenario 4: No Fix Configuration
- Branch: `test/hk-no-fix`
- Configuration: hk.pkl with `fix = false`
- Purpose: Test if automatic fixing causes file issues

## Test Results

### Test 1: Deleted File Behavior
Steps:
1. Create and commit several files
2. Delete one file, add a new file, modify an existing file
3. Commit the changes
4. Check if deleted file reappears as untracked

### Test 2: Unstaged Changes
Steps:
1. Create and commit several files
2. Stage some changes
3. Make additional unstaged changes
4. Commit the staged changes
5. Check if unstaged changes are preserved

## Findings

(To be filled in during testing)
