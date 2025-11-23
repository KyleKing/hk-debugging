# Mise Task Arguments Exploration - Summary

## Project Overview

This project provides a comprehensive exploration of mise's task arguments feature, including:
- 15 practical examples for common use cases (especially pytest)
- 20 edge cases and potential bug scenarios
- Complete documentation of findings
- A Claude Skill for mise expertise
- Automated test runner

## What's Included

### Configuration Files

1. **`.mise.toml`** - Main examples file
   - 15 task definitions covering real-world scenarios
   - Focus on pytest with coverage integration
   - Examples of argument transformation and pass-through
   - Multiple run command patterns
   - All common usage features (flags, args, choices, etc.)

2. **`.mise.edge-cases.toml`** - Edge cases and bugs
   - 20 edge case scenarios to test
   - Security considerations (shell injection)
   - Unicode and special character handling
   - Validation timing tests
   - Potential bug scenarios

### Documentation

3. **`README.md`** - Complete user guide
   - Quick start instructions
   - Example categories and explanations
   - Common patterns for pytest and coverage
   - Best practices and troubleshooting
   - Migration guide from Tera templates

4. **`FINDINGS.md`** - Technical analysis
   - 18 documented issues/edge cases
   - Severity classifications
   - Test recommendations
   - Feature requests
   - Workarounds for known issues

5. **`SUMMARY.md`** - This file
   - High-level project overview
   - Key takeaways
   - Usage instructions

### Tools

6. **`test-runner.sh`** - Automated testing
   - Tests all examples systematically
   - Colored output for readability
   - Categorized test suites
   - Pass/fail/skip tracking

### Claude Integration

7. **`.claude/skills/mise/mise-expert.md`** - Claude Skill
   - Expert knowledge base for mise
   - Common patterns and best practices
   - Usage syntax reference
   - Example interactions
   - Security and quality guidelines

## Key Examples Highlights

### Example 1: Simple Pass-Through
```bash
mise run test:basic -- tests/test_auth.py
```
Direct argument forwarding to pytest.

### Example 2: Flag Transformation
```bash
mise run test:debug --verbose --fail-fast
```
Transforms `--verbose` → `-vvv` and `--fail-fast` → `-x` for pytest.

### Example 6: Full Pytest Workflow
```bash
mise run test:full --verbose --coverage --html-report --marker unit tests/
```
Complete test suite with all options (verbosity, coverage, markers, paths).

### Example 12: Multi-Stage Pipeline
```bash
mise run test:pipeline --stage all --verbose
```
Sequential execution: lint → test → coverage.

### Example 13: Variadic with Constraints
```bash
mise run test:variadic file1.py file2.py file3.py
```
Enforces 1-5 file arguments.

## Important Findings

### Critical Issues

1. **Variadic Arguments with Spaces** (MISE-ARG-001)
   - Environment variables don't preserve arrays well
   - Files with spaces may break without proper quoting
   - **Workaround:** Always quote: `pytest "$usage_paths"`

2. **Shell Injection Risk** (MISE-ARG-002)
   - Task arguments are shell-expanded
   - Malicious input could be dangerous
   - **Mitigation:** Quote expansions, avoid `eval`, use validation

### Medium Priority

3. **Count Flag Conversion** (MISE-ARG-003)
   - `count=#true` gives a number, not repeated flags
   - Converting `-vvv` requires bash loops
   - Example workaround provided

4. **Boolean Type Confusion** (MISE-ARG-004)
   - Booleans are strings "true"/"false"
   - Use string comparison: `[ "$usage_flag" = "true" ]`

### Low Priority

- Empty string vs undefined behavior (needs testing)
- Arg/flag name collision (potential bug)
- Multi-run command variable scope (needs clarification)
- Various validation timing questions

## Best Practices Discovered

### 1. Always Quote Variable Expansions
```bash
pytest "$usage_path"  # Good
pytest $usage_path    # Bad - breaks with spaces
```

### 2. Use String Comparison for Booleans
```bash
if [ "$usage_verbose" = "true" ]; then  # Good
if $usage_verbose; then                 # Risky
```

### 3. Provide Sensible Defaults
```toml
flag "--env <env>" default="local"
arg "[paths...]" default="tests/"
```

### 4. Use Choices for Validation
```toml
flag "--format <fmt>" {
  choices "html" "xml" "json"
}
```

### 5. Use `set -e` for Error Handling
```bash
run = '''
set -e  # Exit on any error
command1
command2
'''
```

## Usage Patterns

### Pattern 1: Simple Transformation
Transform a simple flag into complex CLI arguments.

**Use case:** `--debug` → `pytest -vvv -x -s`

**Example:** See `test:debug` in `.mise.toml`

### Pattern 2: Accumulation
Combine multiple flags into a command line.

**Use case:** Build pytest command from `--verbose`, `--fail-fast`, `--coverage`

**Example:** See `test:full` in `.mise.toml`

### Pattern 3: Pass-Through
Forward arguments directly to the underlying tool.

**Use case:** `mise run test -- tests/unit/` → `pytest tests/unit/`

**Example:** See `test:basic` in `.mise.toml`

### Pattern 4: Hybrid
Combine transformation and pass-through.

**Use case:** Transform flags but pass paths through

**Example:** See `test:mixed` in `.mise.toml`

### Pattern 5: Multi-Stage
Chain multiple commands with shared arguments.

**Use case:** Lint → test → coverage pipeline

**Example:** See `test:pipeline` in `.mise.toml`

## How to Use This Project

### 1. Browse Examples
```bash
cd mise-task-args-exploration
cat .mise.toml          # Read main examples
cat .mise.edge-cases.toml  # Read edge cases
```

### 2. Test with Mise (if installed)
```bash
# List all tasks
mise tasks

# Get help for a specific task
mise run test:full --help

# Run a task
mise run test:coverage --html tests/

# Run the automated test suite
./test-runner.sh
```

### 3. Read Documentation
```bash
cat README.md      # User guide and patterns
cat FINDINGS.md    # Technical findings and bugs
```

### 4. Use the Claude Skill
The Claude Skill at `.claude/skills/mise/mise-expert.md` can be activated in Claude Code to get expert mise assistance.

When activated, Claude will have deep knowledge of:
- Mise configuration and setup
- Task argument syntax
- Common patterns and best practices
- Troubleshooting and edge cases

### 5. Copy Patterns
Use the examples as templates for your own mise tasks:

```bash
# Copy the structure
cp .mise.toml ~/my-project/.mise.toml

# Edit for your needs
# Keep the patterns you need, remove the rest
```

## Pytest-Specific Insights

### Coverage Integration
Multiple examples show how to integrate pytest-cov:
- `test:coverage` - Basic coverage with format options
- `test:full` - Complete workflow with coverage flag
- `test:pipeline` - Separate coverage stage

### Common Flags Mapped
- `--verbose` → `-vvv` (very verbose)
- `--fail-fast` → `-x` (stop on first failure)
- `--debug` → `-vvv -x -s` (verbose, fail-fast, show output)
- `--coverage` → `--cov=. --cov-report=term`
- `--html` → `--cov-report=html`
- `--xml` → `--cov-report=xml`
- `--marker <m>` → `-m <m>` (marker selection)

### Multiple Run Commands
Examples show how to chain:
1. Linting (ruff/flake8)
2. Testing (pytest)
3. Coverage reporting

## Migration Guide

### From Tera Templates

**Old (Deprecated):**
```toml
[tasks.test]
run = 'pytest {{arg(name="file", default="tests/")}}'
```

**New (Current):**
```toml
[tasks.test]
usage = 'arg "[file]" default="tests/"'
run = 'pytest $usage_file'
```

### Benefits of New Approach
- Cleaner syntax
- Better performance (no two-pass parsing)
- More features (validation, choices, etc.)
- Works with file tasks
- Standard usage specification
- Better error messages

## Testing Recommendations

### Priority 1: Security
- [ ] Test shell injection scenarios
- [ ] Test special characters and escaping
- [ ] Validate input sanitization

### Priority 2: Core Functionality
- [ ] Test variadic arguments with spaces
- [ ] Test boolean behavior
- [ ] Test required validation
- [ ] Test choice validation

### Priority 3: Edge Cases
- [ ] Run all examples in `.mise.edge-cases.toml`
- [ ] Test count flag patterns
- [ ] Test min/max validation
- [ ] Test name collision scenarios

### Priority 4: Documentation
- [ ] Verify all examples work
- [ ] Test on different shells (bash, zsh)
- [ ] Test on different platforms (Linux, macOS)

## Resources

### Official Documentation
- [Mise Documentation](https://mise.jdx.dev)
- [Task Arguments](https://mise.jdx.dev/tasks/task-arguments.html)
- [TOML Tasks](https://mise.jdx.dev/tasks/toml-tasks.html)
- [Usage Specification](https://usage.jdx.dev)

### Community
- [Mise GitHub](https://github.com/jdx/mise)
- [Usage GitHub](https://github.com/jdx/usage)
- [Task Arguments Discussion](https://github.com/jdx/mise/discussions/6766)

### This Project
- All examples are self-contained in `.mise.toml` and `.mise.edge-cases.toml`
- Documentation is comprehensive and cross-referenced
- Test runner automates validation
- Claude Skill provides expert assistance

## Next Steps

1. **Install Mise** (if not already)
   ```bash
   curl https://mise.run | sh
   ```

2. **Test Examples**
   ```bash
   cd mise-task-args-exploration
   mise tasks
   ./test-runner.sh
   ```

3. **Customize for Your Project**
   - Copy relevant patterns
   - Adapt to your tools (pytest, npm, cargo, etc.)
   - Add your own tasks

4. **Report Findings**
   - If you find bugs, report to [mise issues](https://github.com/jdx/mise/issues)
   - If you create useful patterns, contribute back

5. **Use the Claude Skill**
   - Activate the mise-expert skill in Claude Code
   - Get expert help with configuration
   - Learn best practices interactively

## Conclusion

This exploration reveals that mise's task arguments feature is:

**Strengths:**
- ✅ Clean, declarative syntax
- ✅ Powerful validation (choices, required, min/max)
- ✅ Better than deprecated Tera templates
- ✅ Integration with usage specification standard
- ✅ Good documentation foundation

**Areas for Improvement:**
- ⚠️ Variadic arguments with special characters
- ⚠️ Count flag conversion patterns
- ⚠️ Boolean type clarity
- ⚠️ Some edge case documentation gaps

**Overall Assessment:**
Mise task arguments are production-ready with awareness of limitations. Follow best practices (quoting, validation, error handling) and you'll have robust, maintainable task definitions.

## License

These examples are provided as-is for educational and testing purposes.

## Contributing

Found a bug? Have a better pattern? Contributions welcome!

1. Test your example thoroughly
2. Document any unexpected behavior
3. Add to appropriate file (.mise.toml or .mise.edge-cases.toml)
4. Update FINDINGS.md if relevant
5. Share with the community

---

**Happy mise task building!** 🚀
