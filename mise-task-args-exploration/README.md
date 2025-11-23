# Mise Task Arguments Exploration

This directory contains comprehensive examples and edge case testing for mise task arguments feature.

## Overview

Mise task arguments use the [usage](https://github.com/jdx/usage) specification library to define CLI-like arguments for tasks. This is the modern replacement for the deprecated Tera template functions (`{{arg()}}`, `{{option()}}`, `{{flag()}}`).

## Files in This Directory

- **.mise.toml** - 15 comprehensive examples covering common use cases
- **.mise.edge-cases.toml** - 20 edge cases and potential bugs to explore
- **README.md** - This file
- **FINDINGS.md** - Documented findings and potential bugs

## Quick Start

```bash
# Install mise if not already installed
curl https://mise.run | sh

# List available tasks
mise tasks

# Run a basic example
mise run test:basic -- tests/

# Run with argument transformation
mise run test:debug --verbose --fail-fast

# Run with coverage
mise run test:coverage --html tests/
```

## Key Concepts

### Usage Field Syntax

The `usage` field uses KDL-like syntax to define arguments:

```toml
[tasks.example]
usage = '''
flag "--verbose" help="Enable verbose output" default=#false
arg "[path]" help="Optional path argument"
'''
run = "pytest $usage_verbose $usage_path"
```

### Variable Naming Convention

Arguments are exposed as environment variables with the `usage_` prefix:
- `flag "--verbose"` → `$usage_verbose`
- `arg "<file>"` → `$usage_file`
- Flag names are converted to snake_case: `--fail-fast` → `$usage_fail_fast`

### Boolean Values

Flags default to boolean behavior:
- `default=#true` / `default=#false`
- Values are string literals `"true"` or `"false"` in bash
- Use string comparison: `if [ "$usage_verbose" = "true" ]; then`

### Variadic Arguments

Use `var=#true` for multiple values:
```toml
arg "[files...]" var=#true
```
Constraints:
- `var_min=2` - minimum number of arguments
- `var_max=5` - maximum number of arguments

## Example Categories

### 1. Basic Pass-Through (.mise.toml)
- `test:basic` - Direct argument pass-through to pytest
- `test:env-vars` - Environment variable integration

### 2. Argument Transformation (.mise.toml)
- `test:debug` - Transform flags (--verbose → -vvv -x)
- `test:mixed` - Combination of transformation and pass-through
- `test:count` - Counting flags (-vvv pattern)

### 3. Coverage Integration (.mise.toml)
- `test:coverage` - Basic coverage with HTML/XML options
- `test:full` - Complete workflow with all options

### 4. Multiple Run Commands (.mise.toml)
- `test:multi` - Sequential commands with shared args
- `test:pipeline` - Multi-stage pipeline (lint → test → coverage)

### 5. Advanced Features (.mise.toml)
- `test:env` - Choice constraints
- `test:negate` - Negatable flags (--cache / --no-cache)
- `test:conditional` - Conditional requirements
- `test:variadic` - Min/max constraints on arguments

### 6. Edge Cases (.mise.edge-cases.toml)
See FINDINGS.md for detailed analysis of edge cases and potential bugs.

## Pytest-Specific Examples

### Simple Test Run
```bash
mise run test:basic -- tests/test_auth.py
```

### Verbose Mode with Fail-Fast
```bash
mise run test:debug --verbose --fail-fast
```

### Coverage with HTML Report
```bash
mise run test:coverage --html
```

### Full Suite with All Options
```bash
mise run test:full --verbose --coverage --html-report --marker unit
```

### Specific Environment
```bash
mise run test:env --env staging --verbose
```

### Multi-Stage Pipeline
```bash
# Run everything
mise run test:pipeline --stage all --verbose

# Run only tests
mise run test:pipeline --stage test --fail-fast
```

## Argument Transformation Patterns

### Pattern 1: Simple Flag Mapping
```toml
usage = 'flag "--verbose" default=#false'
run = '''
if [ "$usage_verbose" = "true" ]; then
  pytest -vvv
else
  pytest -v
fi
'''
```

### Pattern 2: Multiple Flag Accumulation
```toml
usage = '''
flag "--verbose" default=#false
flag "--fail-fast" default=#false
'''
run = '''
ARGS=""
[ "$usage_verbose" = "true" ] && ARGS="$ARGS -vvv"
[ "$usage_fail_fast" = "true" ] && ARGS="$ARGS -x"
pytest $ARGS
'''
```

### Pattern 3: Direct Pass-Through
```toml
usage = 'arg "[paths...]" var=#true'
run = 'pytest $usage_paths'
```

### Pattern 4: Hybrid Approach
```toml
usage = '''
flag "--debug" default=#false
arg "[paths...]" var=#true
'''
run = '''
ARGS="-v"
[ "$usage_debug" = "true" ] && ARGS="-vvv -x -s"
pytest $ARGS $usage_paths
'''
```

## Common Patterns for Coverage

### Pattern 1: Optional Coverage
```toml
usage = '''
flag "--coverage" default=#false
flag "--html" default=#false
'''
run = '''
if [ "$usage_coverage" = "true" ]; then
  COV="--cov=. --cov-report=term"
  [ "$usage_html" = "true" ] && COV="$COV --cov-report=html"
  pytest $COV
else
  pytest
fi
'''
```

### Pattern 2: Always Coverage, Optional Formats
```toml
usage = '''
flag "--html" default=#false
flag "--xml" default=#false
'''
run = '''
COV="--cov=. --cov-report=term"
[ "$usage_html" = "true" ] && COV="$COV --cov-report=html"
[ "$usage_xml" = "true" ] && COV="$COV --cov-report=xml"
pytest $COV
'''
```

## Multiple Run Commands

Tasks can have multiple sequential run commands:

```toml
[tasks.example]
usage = 'flag "--verbose" default=#false'
run = [
  "echo 'Starting tests...'",
  "ruff check .",
  "pytest",
  "echo 'Tests complete!'"
]
```

**Important Notes:**
- Each command in the array runs sequentially
- If any command fails, subsequent commands don't run (by default)
- All usage variables are available in all run commands
- Environment variables set in one command may not persist to the next (each might be a separate shell)

## Best Practices

### 1. Always Quote Variable Expansions
```bash
# Good
pytest "$usage_path"

# Bad (fails with spaces)
pytest $usage_path
```

### 2. Use Explicit Boolean Comparisons
```bash
# Good
if [ "$usage_verbose" = "true" ]; then

# Risky
if $usage_verbose; then
```

### 3. Provide Sensible Defaults
```toml
flag "--env <env>" default="local"
arg "[paths...]" var=#true default="tests/"
```

### 4. Use Choices for Validation
```toml
flag "--format <fmt>" {
  choices "html" "xml" "json"
}
```

### 5. Document Required Combinations
```toml
flag "--output-dir <dir>" required_if="--format"
```

### 6. Use Descriptive Help Text
```toml
flag "--marker <marker>" help="Run tests with specific pytest marker (e.g., unit, integration)"
```

## Potential Issues & Workarounds

### Issue 1: Variadic Arguments with Spaces

**Problem:** Environment variables don't preserve arrays well
```bash
# This might fail with files containing spaces
pytest $usage_paths
```

**Workaround:** Quote the expansion
```bash
pytest "$usage_paths"
```

**Better Solution:** Use bash array if possible
```bash
# This is tricky with environment variables
# May need to process into array first
```

### Issue 2: Boolean Type Ambiguity

**Problem:** Booleans are strings, not true booleans
```bash
# Might not work as expected
if $usage_flag; then
```

**Workaround:** Always use string comparison
```bash
if [ "$usage_flag" = "true" ]; then
```

### Issue 3: Complex Argument Transformations

**Problem:** Mapping simple flags to complex CLI patterns requires bash logic

**Solution:** Use bash functions or case statements
```bash
get_pytest_args() {
  local args="-v"
  [ "$usage_verbose" = "true" ] && args="$args -vv"
  [ "$usage_debug" = "true" ] && args="$args -s -x"
  echo "$args"
}
pytest $(get_pytest_args) $usage_paths
```

### Issue 4: Count Flags Don't Combine Well

**Problem:** `mise run test -vvv` with `count=#true` requires special handling

**Current Limitation:** Count gives you a number, but you need to convert it
```bash
# Convert count to actual flags
VERBOSE_FLAGS=""
for i in $(seq 1 $usage_verbose); do
  VERBOSE_FLAGS="$VERBOSE_FLAGS -v"
done
pytest $VERBOSE_FLAGS
```

## Migration from Tera Templates

### Old Style (Deprecated)
```toml
[tasks.test]
run = 'pytest {{arg(name="path", default="tests/")}}'
```

### New Style (Recommended)
```toml
[tasks.test]
usage = 'arg "[path]" default="tests/"'
run = 'pytest $usage_path'
```

## Testing Your Task Definitions

### 1. Test with `--help`
```bash
mise run test:full --help
```

### 2. Test Edge Cases
```bash
# No arguments
mise run test:basic

# With arguments
mise run test:basic -- tests/

# Multiple arguments
mise run test:variadic -- file1.py file2.py file3.py

# Special characters
mise run test:basic -- "tests/test with spaces.py"
```

### 3. Verify Environment Variables
```bash
# Add debug output to your run command
echo "Verbose: $usage_verbose"
echo "Paths: $usage_paths"
```

## Resources

- [Mise Task Arguments Documentation](https://mise.jdx.dev/tasks/task-arguments.html)
- [Usage Specification](https://usage.jdx.dev)
- [Usage GitHub Repository](https://github.com/jdx/usage)
- [Mise TOML Tasks Documentation](https://mise.jdx.dev/tasks/toml-tasks.html)
- [GitHub Discussion on Task Arguments](https://github.com/jdx/mise/discussions/6766)

## Contributing

To add more examples or report bugs:
1. Add your example to `.mise.toml` or `.mise.edge-cases.toml`
2. Document any findings in FINDINGS.md
3. Test the example and note any unexpected behavior

## License

These examples are provided as-is for educational and testing purposes.
