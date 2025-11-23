# Mise Task Arguments - Findings and Potential Bugs

This document summarizes potential bugs, limitations, and unexpected behaviors discovered during exploration of mise task arguments.

## Critical Issues

### 1. Variadic Arguments with Spaces/Special Characters

**Issue ID:** MISE-ARG-001
**Severity:** High
**Status:** Potential Bug

**Description:**
Environment variables don't preserve array structures. When using `var=#true` for variadic arguments, files/paths with spaces may not be properly handled.

**Example:**
```toml
[tasks.test]
usage = 'arg "[files...]" var=#true'
run = 'pytest $usage_files'
```

**Test Case:**
```bash
mise run test -- "test file.py" "another test.py"
```

**Expected Behavior:**
Pytest should receive two separate file arguments.

**Actual Behavior (Predicted):**
May split on spaces, resulting in four arguments: `test`, `file.py`, `another`, `test.py`

**Workaround:**
```bash
# Quote the expansion
pytest "$usage_files"

# Or use bash array processing (complex)
IFS=$'\n' read -rd '' -a files <<<"$usage_files"
pytest "${files[@]}"
```

**Referenced in:** `.mise.edge-cases.toml` → `edge:special-chars`

---

### 2. Shell Injection Risk

**Issue ID:** MISE-ARG-002
**Severity:** Critical (Security)
**Status:** Design Limitation

**Description:**
Task arguments are exposed as environment variables and expanded in shell scripts. Without proper quoting, this could lead to shell injection if malicious input is provided.

**Example:**
```toml
[tasks.danger]
usage = 'flag "--cmd <command>"'
run = 'eval $usage_cmd'  # DANGEROUS!
```

**Test Case:**
```bash
mise run danger --cmd "; rm -rf /"
```

**Mitigation:**
- Always quote variable expansions: `"$usage_cmd"`
- Avoid `eval` with user input
- Use built-in validation (choices, patterns)
- Document security considerations

**Referenced in:** `.mise.edge-cases.toml` → `edge:injection`

---

## Medium Priority Issues

### 3. Count Flag to CLI Args Conversion

**Issue ID:** MISE-ARG-003
**Severity:** Medium
**Status:** Limitation

**Description:**
The `count=#true` feature gives you a number, but converting that to multiple CLI flags (e.g., `-vvv`) requires manual bash loops.

**Example:**
```toml
[tasks.test]
usage = 'flag "-v" count=#true'
run = 'pytest -vvv'  # How to map count=3 to -vvv?
```

**Current Solution:**
```bash
VERBOSE_FLAGS=""
for i in $(seq 1 $usage_v); do
  VERBOSE_FLAGS="$VERBOSE_FLAGS -v"
done
pytest $VERBOSE_FLAGS
```

**Desired Feature:**
Some built-in way to expand count to repeated flags.

**Referenced in:** `.mise.edge-cases.toml` → `edge:count-edge`

---

### 4. Boolean Type Confusion

**Issue ID:** MISE-ARG-004
**Severity:** Medium
**Status:** Documentation Issue

**Description:**
Boolean flags are exported as string values `"true"` or `"false"`, not bash boolean expressions. This can lead to unexpected behavior.

**Example:**
```toml
[tasks.test]
usage = 'flag "--verbose" default=#false'
run = '''
if $usage_verbose; then  # This might not work as expected
  echo "verbose"
fi
'''
```

**Test Cases:**
- `$usage_verbose` expands to the string `"true"` or `"false"`
- Direct boolean expansion `if $usage_verbose` tries to execute "true" or "false" as commands
- This actually works by accident (true/false are valid commands)
- But it's confusing and fragile

**Best Practice:**
Always use string comparison:
```bash
if [ "$usage_verbose" = "true" ]; then
```

**Referenced in:** `.mise.edge-cases.toml` → `edge:boolean-types`

---

### 5. Empty String vs Undefined

**Issue ID:** MISE-ARG-005
**Severity:** Medium
**Status:** Needs Testing

**Description:**
Unclear how mise distinguishes between:
- An optional argument not provided
- An optional argument provided as empty string
- An argument with `default=""`

**Example:**
```toml
[tasks.test]
usage = '''
flag "--name <name>" default=""
arg "[path]"
'''
run = '''
echo "Name: '$usage_name'"
echo "Path: '$usage_path'"
'''
```

**Test Cases:**
1. `mise run test` - both unset?
2. `mise run test --name ""` - name explicitly empty?
3. `mise run test -- ""` - path explicitly empty?

**Expected Behavior:**
Should be able to distinguish between unset and empty.

**Referenced in:** `.mise.edge-cases.toml` → `edge:empty-vs-undefined`

---

### 6. Arg/Flag Name Collision

**Issue ID:** MISE-ARG-006
**Severity:** Medium
**Status:** Potential Bug

**Description:**
Unclear what happens if a flag and an arg would generate the same environment variable name.

**Example:**
```toml
[tasks.test]
usage = '''
flag "--path <path>"
arg "[path]"
'''
run = 'echo $usage_path'  # Which one?
```

**Expected Behavior:**
Should either:
1. Error during task definition
2. Have a documented precedence rule
3. Namespace differently (e.g., `$usage_flag_path` vs `$usage_arg_path`)

**Referenced in:** `.mise.edge-cases.toml` → `edge:name-collision`

---

## Low Priority Issues / Unclear Behaviors

### 7. Multi-Run Command Variable Scope

**Issue ID:** MISE-ARG-007
**Severity:** Low
**Status:** Needs Testing

**Description:**
When using `run = [...]` with multiple commands, it's unclear:
- Are usage variables available in all commands?
- Do environment variables set in one command persist to the next?
- Is each command a separate shell invocation?

**Example:**
```toml
[tasks.test]
usage = 'flag "--value <val>" default="test"'
run = [
  "echo First: $usage_value",
  "export MODIFIED=${usage_value}_mod",
  "echo Second: $MODIFIED"
]
```

**Questions:**
- Does `$usage_value` work in all three commands? (Likely yes)
- Does `$MODIFIED` persist to the third command? (Likely no if separate shells)

**Referenced in:** `.mise.edge-cases.toml` → `edge:multi-run-scope`

---

### 8. Choice Validation Timing

**Issue ID:** MISE-ARG-008
**Severity:** Low
**Status:** Needs Testing

**Description:**
When are choice constraints validated?
- Before default substitution?
- After default substitution?
- At parse time vs run time?

**Example:**
```toml
[tasks.test]
usage = '''
flag "--env <env>" default="local" {
  choices "local" "staging" "prod"
}
'''
run = 'echo $usage_env'
```

**Test Case:**
```bash
mise run test --env invalid
```

**Expected:** Should error before running the script
**Need to verify:** Does it error during parsing or during execution?

**Referenced in:** `.mise.edge-cases.toml` → `edge:choice-validation`

---

### 9. Required Flag Validation

**Issue ID:** MISE-ARG-009
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing when required flag validation occurs.

**Example:**
```toml
[tasks.test]
usage = 'flag "--config <path>" required=#true'
run = 'pytest --config=$usage_config'
```

**Test Case:**
```bash
mise run test
```

**Expected:** Should error before running the script
**Need to verify:** Error message quality and timing

**Referenced in:** `.mise.edge-cases.toml` → `edge:required-missing`

---

### 10. Min/Max Validation Edge Cases

**Issue ID:** MISE-ARG-010
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing edge cases for `var_min` and `var_max` validation.

**Example:**
```toml
[tasks.test]
usage = 'arg "<files...>" var=#true var_min=2 var_max=5'
run = 'pytest $usage_files'
```

**Test Cases:**
1. `mise run test file1.py` - Should error (min=2)
2. `mise run test f1 f2 f3 f4 f5 f6` - Should error (max=5)
3. Error message quality?

**Referenced in:** `.mise.edge-cases.toml` → `edge:minmax`

---

### 11. Negate Flag Default Behavior

**Issue ID:** MISE-ARG-011
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing that negatable flags properly flip defaults.

**Example:**
```toml
[tasks.test]
usage = 'flag "--cache" negate="--no-cache" default=#true'
run = 'echo $usage_cache'
```

**Test Cases:**
1. `mise run test` → Should output "true"
2. `mise run test --cache` → Should output "true"
3. `mise run test --no-cache` → Should output "false"

**Referenced in:** `.mise.edge-cases.toml` → `edge:negate-default`

---

### 12. Conflicting Flags (Overrides)

**Issue ID:** MISE-ARG-012
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing `overrides` attribute behavior.

**Example:**
```toml
[tasks.test]
usage = '''
flag "--verbose" default=#false
flag "--quiet" overrides="--verbose" default=#false
'''
run = 'echo "v=$usage_verbose q=$usage_quiet"'
```

**Test Case:**
```bash
mise run test --verbose --quiet
```

**Expected:** `verbose=false quiet=true` (quiet overrides verbose)
**Need to verify:** Order dependency, multiple overrides

**Referenced in:** `.mise.edge-cases.toml` → `edge:conflicts`

---

### 13. Environment Variable Expansion

**Issue ID:** MISE-ARG-013
**Severity:** Low
**Status:** Needs Testing

**Description:**
How are environment variables in `env="VAR"` expanded?

**Example:**
```toml
[tasks.test]
usage = '''
flag "--home <path>" env="HOME"
flag "--custom <val>" env="MY_CUSTOM_VAR" default="fallback"
'''
run = 'echo "home=$usage_home custom=$usage_custom"'
```

**Test Cases:**
1. `mise run test` - Should use $HOME and "fallback"
2. `MY_CUSTOM_VAR=test mise run test` - Should use "test"
3. `mise run test --custom override` - Should use "override"

**Questions:**
- What's the priority: CLI flag > env var > default?
- Is this documented?

**Referenced in:** `.mise.edge-cases.toml` → `edge:env-expansion`

---

### 14. Unicode and Non-ASCII Characters

**Issue ID:** MISE-ARG-014
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing UTF-8 handling in arguments.

**Example:**
```toml
[tasks.test]
usage = '''
flag "--name <name>" default="Test"
arg "[paths...]" var=#true
'''
run = 'echo "Name: $usage_name Paths: $usage_paths"'
```

**Test Case:**
```bash
mise run test --name "José" -- "tests/测试.py"
```

**Expected:** UTF-8 preserved correctly
**Need to verify:** Any encoding issues

**Referenced in:** `.mise.edge-cases.toml` → `edge:unicode`

---

### 15. Double Dash Behavior

**Issue ID:** MISE-ARG-015
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing how `--` separates flags from arguments.

**Example:**
```toml
[tasks.test]
usage = '''
flag "--flag <val>"
arg "[args...]" var=#true
'''
run = 'echo "flag=$usage_flag args=$usage_args"'
```

**Test Cases:**
1. `mise run test --flag value arg1 arg2` - All parsed?
2. `mise run test --flag value -- arg1 arg2` - What's the difference?
3. `mise run test -- --flag value` - Is --flag treated as an arg?

**Referenced in:** `.mise.edge-cases.toml` → `edge:double-dash`

---

### 16. Required Unless/If Combinations

**Issue ID:** MISE-ARG-016
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing conditional requirement logic.

**Example:**
```toml
[tasks.test]
usage = '''
flag "--file <path>" required_unless="--stdin"
flag "--stdin" required_unless="--file" default=#false
'''
run = 'echo "file=$usage_file stdin=$usage_stdin"'
```

**Test Cases:**
1. `mise run test` - Should error (neither provided)
2. `mise run test --file test.py` - Should work
3. `mise run test --stdin` - Should work
4. `mise run test --file test.py --stdin` - Should work (both provided)

**Referenced in:** `.mise.edge-cases.toml` → `edge:required-combo`

---

### 17. Task Dependencies with Arguments

**Issue ID:** MISE-ARG-017
**Severity:** Low
**Status:** Needs Testing

**Description:**
How do arguments interact with task dependencies?

**Example:**
```toml
[tasks.dep]
usage = 'flag "--value <val>" default="dep"'
run = 'echo $usage_value'

[tasks.main]
depends = ["dep"]
usage = 'flag "--value <val>" default="main"'
run = 'echo $usage_value'
```

**Questions:**
- Can you pass arguments to dependencies?
- Do dependencies see the same arguments?
- Is there any argument passing mechanism?

**Referenced in:** `.mise.edge-cases.toml` → `edge:dep-caller`

---

### 18. Whitespace in Default Values

**Issue ID:** MISE-ARG-018
**Severity:** Low
**Status:** Needs Testing

**Description:**
Testing whitespace preservation in defaults.

**Example:**
```toml
[tasks.test]
usage = '''
flag "--value <val>" default="hello world"
arg "[path]" default="  spaced  "
'''
run = 'echo "value=\'$usage_value\' path=\'$usage_path\'"'
```

**Test Case:**
```bash
mise run test
```

**Expected:** Whitespace preserved exactly
**Need to verify:** Any trimming or normalization

**Referenced in:** `.mise.edge-cases.toml` → `edge:whitespace-default`

---

## Feature Requests

### FR-1: Array Support for Variadic Arguments

**Description:**
Instead of space-separated strings, provide variadic arguments as proper bash arrays or a reliable way to iterate over them.

**Current Workaround:**
```bash
# Unreliable with spaces
for file in $usage_files; do
  echo "$file"
done
```

**Desired:**
```bash
# Hypothetical
for file in "${usage_files[@]}"; do
  echo "$file"
done
```

---

### FR-2: Built-in Argument Transformations

**Description:**
Provide a way to declare argument transformations without bash logic.

**Current:**
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

**Desired:**
```toml
usage = 'flag "--verbose" default=#false'
transform = 'if $verbose then "-vvv" else "-v"'
run = 'pytest $transformed_verbose'
```

---

### FR-3: Validation Patterns

**Description:**
Regex or glob patterns for argument validation.

**Desired:**
```toml
usage = '''
flag "--port <port>" pattern="^[0-9]{1,5}$"
flag "--email <email>" pattern="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
'''
```

---

### FR-4: Better Documentation on Precedence

**Description:**
Clear documentation on the priority order:
- CLI flag
- Environment variable (env="VAR")
- Config file (config="key")
- Default value

Is the order documented? Is it configurable?

---

## Testing Recommendations

### Priority 1: Security Testing
- [ ] Test shell injection scenarios (MISE-ARG-002)
- [ ] Test special characters and escaping
- [ ] Test Unicode handling

### Priority 2: Core Functionality
- [ ] Test variadic arguments with spaces (MISE-ARG-001)
- [ ] Test boolean type behavior (MISE-ARG-004)
- [ ] Test required validation (MISE-ARG-009)
- [ ] Test choice validation (MISE-ARG-008)

### Priority 3: Edge Cases
- [ ] Test all examples in `.mise.edge-cases.toml`
- [ ] Test count flag conversion (MISE-ARG-003)
- [ ] Test min/max validation (MISE-ARG-010)
- [ ] Test name collisions (MISE-ARG-006)

### Priority 4: Documentation
- [ ] Test environment variable precedence (MISE-ARG-013)
- [ ] Test multi-run scope (MISE-ARG-007)
- [ ] Test task dependencies (MISE-ARG-017)

## Conclusion

The mise task arguments feature is powerful and well-designed, but has some rough edges:

**Strengths:**
- Clean, declarative syntax
- Integration with usage specification
- Good validation features (choices, required, min/max)
- Better than Tera templates

**Weaknesses:**
- Variadic arguments with special characters (spaces)
- Count flag requires manual conversion
- Boolean handling could be clearer
- Some edge cases need better documentation

**Recommendations:**
1. Add comprehensive tests for edge cases
2. Improve documentation, especially around:
   - Precedence/priority
   - Boolean handling
   - Variadic argument limitations
3. Consider adding built-in support for:
   - Array-like variadic arguments
   - Argument transformations
   - Pattern validation
4. Add security guidance for shell injection prevention

## Next Steps

1. **Create actual tests** - Install mise and run all examples
2. **Document actual behavior** - Update this file with test results
3. **Report bugs** - File issues for confirmed bugs
4. **Contribute fixes** - Submit PRs for documentation improvements
