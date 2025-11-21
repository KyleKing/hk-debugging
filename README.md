# hk-debugging

Attempting to recreate issues

1. Sometimes when there are deleted files in a commit (usually when there are also additions/deletions), the commit will succeed, but the deleted files will reappear as untracked and require manual removal
1. Sometimes unstaged changes will be lost when committing (my guess is that the automatic staging is interfering)

Note: the most recent version of hk may have resolved these issues: https://github.com/jdx/hk
