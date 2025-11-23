# Mise Task Arguments - Quick Reference Card

## Basic Syntax

```toml
[tasks.example]
description = "Task description"
usage = '''
flag "--option" help="Description" default=#false
arg "[path]" help="Optional path"
'''
run = "command $usage_option $usage_path"
```

## Variable Naming

| Definition | Variable | Example |
|------------|----------|---------|
| `flag "--verbose"` | `$usage_verbose` | `echo $usage_verbose` |
| `flag "--fail-fast"` | `$usage_fail_fast` | `[ "$usage_fail_fast" = "true" ]` |
| `arg "<file>"` | `$usage_file` | `cat "$usage_file"` |
| `arg "[paths...]"` | `$usage_paths` | `echo $usage_paths` |

## Common Flags

```toml
# Boolean flag
flag "--verbose" help="Enable verbose mode" default=#false

# Flag with value
flag "--config <path>" help="Config file path"

# Flag with environment fallback
flag "--token <token>" help="API token" env="API_TOKEN"

# Flag with default
flag "--env <env>" help="Environment" default="development"

# Counting flag (-vvv)
flag "-v --verbose" help="Verbosity level" count=#true

# Negatable flag
flag "--cache" help="Use cache" negate="--no-cache" default=#true

# Flag with choices
flag "--format <fmt>" help="Output format" {
  choices "json" "yaml" "toml"
}

# Required flag
flag "--api-key <key>" help="API key" required=#true

# Conditional requirement
flag "--output <path>" help="Output path" required_if="--format"

# Global flag (all subcommands)
flag "--debug" help="Debug mode" global=#true
```

## Common Arguments

```toml
# Required positional
arg "<file>" help="Input file"

# Optional positional
arg "[file]" help="Optional input file"

# Optional with default
arg "[path]" help="Path" default="."

# Multiple values (variadic)
arg "[files...]" help="Multiple files" var=#true

# Required multiple
arg "<files...>" help="At least one file" var=#true var_min=1

# Constrained count
arg "<items...>" help="2-5 items" var=#true var_min=2 var_max=5
```

## Boolean Checks

```bash
# ✅ Correct - string comparison
if [ "$usage_verbose" = "true" ]; then
  echo "Verbose mode"
fi

# ✅ Also correct
[ "$usage_verbose" = "true" ] && echo "Verbose"

# ⚠️ Works but fragile
if $usage_verbose; then
  echo "Verbose mode"
fi
```

## Variable Quoting

```bash
# ✅ Always quote to handle spaces
pytest "$usage_path"
echo "Value: $usage_value"

# ❌ Breaks with spaces
pytest $usage_path
```

## Common Patterns

### Pattern: Flag → Multiple CLI Args
```toml
usage = 'flag "--debug" default=#false'
run = '''
if [ "$usage_debug" = "true" ]; then
  pytest -vvv -x -s
else
  pytest -v
fi
'''
```

### Pattern: Multiple Flags → Build Command
```toml
usage = '''
flag "--verbose" default=#false
flag "--fail-fast" default=#false
flag "--coverage" default=#false
'''
run = '''
ARGS=""
[ "$usage_verbose" = "true" ] && ARGS="$ARGS -vv"
[ "$usage_fail_fast" = "true" ] && ARGS="$ARGS -x"
[ "$usage_coverage" = "true" ] && ARGS="$ARGS --cov=."
pytest $ARGS
'''
```

### Pattern: Counting Flag → Repeated CLI Args
```toml
usage = 'flag "-v" count=#true'
run = '''
VERBOSE=""
for i in $(seq 1 $usage_v); do
  VERBOSE="$VERBOSE -v"
done
pytest $VERBOSE
'''
```

### Pattern: Pass-Through
```toml
usage = 'arg "[paths...]" var=#true'
run = 'pytest $usage_paths'
```

### Pattern: Choice → Dispatch
```toml
usage = '''
flag "--env <env>" default="local" {
  choices "local" "staging" "prod"
}
'''
run = '''
case "$usage_env" in
  local) pytest ;;
  staging) pytest --env=staging ;;
  prod) pytest --env=production --slow ;;
esac
'''
```

## Multiple Run Commands

```toml
[tasks.ci]
usage = 'flag "--verbose" default=#false'
run = [
  "echo 'Step 1: Lint'",
  "ruff check .",
  '''
  echo "Step 2: Test"
  ARGS=""
  [ "$usage_verbose" = "true" ] && ARGS="-vvv"
  pytest $ARGS
  ''',
  "echo 'Done!'"
]
```

## Task Dependencies

```toml
[tasks.build]
run = "cargo build"

[tasks.test]
depends = ["build"]
run = "cargo test"
```

## Error Handling

```bash
# Exit on error
run = '''
set -e  # Stop on any error
command1
command2
command3
'''

# Continue on error
run = '''
set +e  # Don't stop on error
command1 || echo "Command 1 failed but continuing"
command2
'''
```

## Environment Variables

```toml
# Use environment variable
flag "--home <path>" env="HOME"

# Fallback chain: CLI → ENV → default
flag "--config <path>" env="CONFIG_PATH" default="config.yaml"
```

## Validation Attributes

```toml
required=#true              # Must provide
default="value"             # Default value
env="VAR"                   # Environment variable
global=#true                # Available everywhere
count=#true                 # Count occurrences (-vvv = 3)
negate="--no-flag"          # Create negation flag
overrides="--other"         # Override other flag
required_if="--other"       # Required if other is set
required_unless="--other"   # Required unless other is set
var=#true                   # Variadic (multiple values)
var_min=1                   # Minimum count
var_max=10                  # Maximum count
```

## Choice Blocks

```toml
flag "--level <level>" help="Log level" default="info" {
  choices "debug" "info" "warn" "error"
}
```

## Common Pytest Examples

### Basic Test
```toml
[tasks.test]
usage = 'arg "[paths...]" var=#true default="tests/"'
run = 'pytest $usage_paths'
```

### With Coverage
```toml
[tasks.test-cov]
usage = '''
flag "--html" default=#false
arg "[paths...]" var=#true default="tests/"
'''
run = '''
COV="--cov=. --cov-report=term"
[ "$usage_html" = "true" ] && COV="$COV --cov-report=html"
pytest $COV $usage_paths
'''
```

### Full Options
```toml
[tasks.test-full]
usage = '''
flag "--verbose" default=#false
flag "--fail-fast" default=#false
flag "--marker <m>" help="Test marker"
arg "[paths...]" var=#true default="tests/"
'''
run = '''
ARGS="-v"
[ "$usage_verbose" = "true" ] && ARGS="$ARGS -vv"
[ "$usage_fail_fast" = "true" ] && ARGS="$ARGS -x"
[ -n "$usage_marker" ] && ARGS="$ARGS -m $usage_marker"
pytest $ARGS $usage_paths
'''
```

## Common Mistakes

### ❌ Unquoted variables
```bash
pytest $usage_path  # Breaks with spaces
```
**Fix:** `pytest "$usage_path"`

### ❌ Wrong boolean check
```bash
if [ $usage_verbose ]; then  # May fail
```
**Fix:** `if [ "$usage_verbose" = "true" ]; then`

### ❌ Expecting arrays
```bash
for file in $usage_files; do  # Breaks with spaces in filenames
```
**Fix:** Use careful quoting or workarounds

### ❌ Direct execution of user input
```bash
eval "$usage_command"  # SECURITY RISK!
```
**Fix:** Validate, sanitize, or use choices

## Security Checklist

- [ ] Quote all variable expansions
- [ ] Never use `eval` with user input
- [ ] Use `choices` for restricted values
- [ ] Validate paths before use
- [ ] Use `set -e` to catch errors
- [ ] Sanitize special characters
- [ ] Test with malicious input

## Testing Your Tasks

```bash
# List all tasks
mise tasks

# Get help
mise run task-name --help

# Run with args
mise run task-name --flag value -- arg1 arg2

# Debug mode
mise run task-name --verbose
```

## Migration from Tera

### Before (Deprecated)
```toml
run = 'pytest {{arg(name="file", default="tests/")}}'
```

### After (Current)
```toml
usage = 'arg "[file]" default="tests/"'
run = 'pytest $usage_file'
```

## Resources

- **Docs:** https://mise.jdx.dev/tasks/task-arguments.html
- **Usage Spec:** https://usage.jdx.dev
- **Examples:** See `.mise.toml` in this repo

---

**Pro Tips:**
1. Always quote `"$usage_*"` variables
2. Use `[ "$var" = "true" ]` for booleans
3. Provide defaults for optional flags
4. Use choices for validation
5. Test with spaces and special chars
6. Read FINDINGS.md for edge cases

**Quick Commands:**
```bash
mise tasks              # List
mise run task --help    # Help
mise run task args      # Run
```

**Variable Format:**
`flag "--my-flag"` → `$usage_my_flag` (kebab → snake_case)

---
**Happy mise task building!**
