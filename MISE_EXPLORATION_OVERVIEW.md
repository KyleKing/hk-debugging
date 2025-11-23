# Mise Task Arguments Exploration - Complete

## Project Location

All exploration materials are in: `mise-task-args-exploration/`

## What's Been Created

### 📄 Configuration Files (Executable Examples)
1. **`.mise.toml`** - 15 practical task examples
   - Focus on pytest with coverage
   - Argument transformation patterns
   - Pass-through patterns
   - Multiple run commands
   - All usage features demonstrated

2. **`.mise.edge-cases.toml`** - 20 edge case scenarios
   - Security testing (shell injection)
   - Type handling (booleans, empty strings)
   - Validation timing
   - Unicode and special characters
   - Potential bugs to investigate

### 📚 Documentation Files
3. **`README.md`** - Complete user guide (~400 lines)
   - Quick start
   - All examples explained
   - Best practices
   - Common patterns
   - Troubleshooting

4. **`FINDINGS.md`** - Technical analysis (~700 lines)
   - 18 documented issues with IDs
   - Severity classifications
   - Workarounds
   - Feature requests
   - Testing recommendations

5. **`SUMMARY.md`** - High-level overview (~500 lines)
   - Project overview
   - Key takeaways
   - Usage patterns
   - Migration guide

6. **`INDEX.md`** - Quick reference index (~200 lines)
   - File listing
   - Task catalog
   - Issue summary
   - Quick links

7. **`QUICK-REFERENCE.md`** - Cheat sheet (~300 lines)
   - Syntax reference
   - Common patterns
   - Code snippets
   - Quick tips

### 🧪 Testing & Tools
8. **`test-runner.sh`** - Automated test script
   - Tests all examples
   - Colored output
   - Pass/fail/skip tracking
   - Categorized test suites

### 🤖 Claude Integration
9. **`.claude/skills/mise/mise-expert.md`** - Claude Skill (~600 lines)
   - Expert knowledge base
   - Common patterns library
   - Best practices
   - Interactive examples
   - Security guidelines

## Key Contributions

### For Pytest Users
- ✅ Direct examples for pytest with mise
- ✅ Coverage integration patterns
- ✅ Argument transformation (--debug → -vvv -x -s)
- ✅ Pass-through arguments
- ✅ Multi-stage pipelines (lint → test → coverage)

### For Mise Community
- ✅ Comprehensive edge case testing
- ✅ Security considerations documented
- ✅ Potential bugs identified with IDs
- ✅ Best practices established
- ✅ Migration guide from Tera templates

### For Developers
- ✅ Reusable patterns catalog
- ✅ Copy-paste ready examples
- ✅ Automated testing framework
- ✅ Complete documentation

### For Claude Code Users
- ✅ Expert mise skill
- ✅ Context-aware assistance
- ✅ Pattern recommendations
- ✅ Best practice enforcement

## Quick Start

### View the Examples
```bash
cd mise-task-args-exploration
cat INDEX.md              # Start here for quick overview
cat QUICK-REFERENCE.md    # Cheat sheet
cat README.md             # Full guide
```

### Test with Mise (if installed)
```bash
cd mise-task-args-exploration
mise tasks                # List all tasks
mise run test:full --help
./test-runner.sh          # Run automated tests
```

### Use in Your Project
```bash
# Copy the patterns you need
cp mise-task-args-exploration/.mise.toml my-project/
# Edit and customize for your needs
```

## File Structure

```
mise-task-args-exploration/
├── .mise.toml                    # Main examples (15 tasks)
├── .mise.edge-cases.toml         # Edge cases (20 tasks)
├── README.md                     # User guide
├── FINDINGS.md                   # Technical analysis
├── SUMMARY.md                    # Overview
├── INDEX.md                      # Quick reference
├── QUICK-REFERENCE.md            # Cheat sheet
└── test-runner.sh                # Automated tests

.claude/skills/mise/
└── mise-expert.md                # Claude Skill
```

## Example Task Categories

### Basic Patterns
- `test:basic` - Pass-through arguments
- `test:debug` - Flag transformation
- `test:mixed` - Hybrid approach

### Coverage Integration
- `test:coverage` - With format options
- `test:full` - Complete workflow

### Advanced Features
- `test:count` - Counting flags (-vvv)
- `test:negate` - Negatable flags (--cache/--no-cache)
- `test:env` - Choice constraints
- `test:conditional` - Conditional requirements
- `test:variadic` - Min/max constraints

### Multi-Command
- `test:multi` - Sequential execution
- `test:pipeline` - Full CI pipeline

### Edge Cases (20 total)
- Shell injection protection
- Special characters in paths
- Boolean type handling
- Empty vs undefined
- Unicode support
- And more...

## Key Findings Summary

### Critical Issues
1. **MISE-ARG-001**: Variadic arguments with spaces (Workaround: quote variables)
2. **MISE-ARG-002**: Shell injection risk (Mitigation: validate, quote, avoid eval)

### Medium Issues
3. **MISE-ARG-003**: Count flag conversion requires loops
4. **MISE-ARG-004**: Boolean values are strings, not booleans
5. **MISE-ARG-005**: Empty string vs undefined behavior
6. **MISE-ARG-006**: Potential arg/flag name collision

### Low Priority (12 more)
See `FINDINGS.md` for complete details.

## Usage Patterns Demonstrated

1. **Simple Transformation**: --debug → -vvv -x -s
2. **Accumulation**: Multiple flags → complex command
3. **Pass-Through**: Direct argument forwarding
4. **Hybrid**: Transform + pass-through
5. **Multi-Stage**: Lint → test → coverage
6. **Validation**: Choices, required, min/max
7. **Counting**: -vvv pattern handling
8. **Negation**: --cache / --no-cache

## Best Practices Established

1. ✅ Always quote variable expansions: `"$usage_var"`
2. ✅ Use string comparison for booleans: `[ "$var" = "true" ]`
3. ✅ Provide sensible defaults
4. ✅ Use choices for validation
5. ✅ Document with help text
6. ✅ Use `set -e` for error handling
7. ✅ Test with special characters
8. ✅ Validate security implications

## Resources Included

- All official mise documentation links
- Usage specification references
- GitHub discussions and issues
- Community resources
- Testing frameworks
- Migration guides

## Next Steps

### For Users
1. Browse examples in `mise-task-args-exploration/`
2. Copy patterns to your project
3. Test thoroughly
4. Customize for your tools

### For Contributors
1. Test examples with mise installed
2. Report confirmed bugs to mise project
3. Share new patterns
4. Improve documentation

### For Mise Project
1. Review findings for potential bugs
2. Consider feature requests
3. Enhance security documentation
4. Improve edge case handling

## Statistics

- **Total Examples**: 35 tasks (15 main + 20 edge cases)
- **Documentation**: ~2500 lines
- **Code Samples**: 100+ patterns
- **Issues Documented**: 18 with IDs
- **Files Created**: 9 total
- **Test Coverage**: Automated test suite included

## Pytest-Specific Highlights

### Common Transformations
- `--verbose` → `-vvv`
- `--fail-fast` → `-x`
- `--debug` → `-vvv -x -s`
- `--coverage` → `--cov=. --cov-report=term`
- `--html` → `--cov-report=html`
- `--marker <m>` → `-m <m>`

### Coverage Patterns
- Optional coverage flag
- Always-on coverage with format options
- Conditional HTML/XML reports
- Multi-stage with separate coverage step

### Multi-Command Pipelines
- Lint before test
- Test before coverage
- Full CI workflow examples

## Security Considerations

- ✅ Shell injection risks documented
- ✅ Input validation patterns shown
- ✅ Quoting best practices
- ✅ Security testing examples
- ✅ Malicious input scenarios
- ✅ Mitigation strategies

## Claude Skill Features

The mise-expert skill provides:
- Syntax help
- Pattern recommendations
- Best practice enforcement
- Security guidance
- Example generation
- Troubleshooting assistance

Activate with: Ask Claude about mise tasks or configuration

## Conclusion

This exploration provides:
- ✅ Comprehensive example library
- ✅ Thorough documentation
- ✅ Edge case analysis
- ✅ Security considerations
- ✅ Testing framework
- ✅ Claude integration
- ✅ Best practices
- ✅ Migration guidance

**Everything needed to effectively use mise task arguments with pytest and other tools.**

## License

Educational use - provided as-is for learning and reference.

---

**Location**: `mise-task-args-exploration/`
**Start Here**: `mise-task-args-exploration/INDEX.md`
**Quick Help**: `mise-task-args-exploration/QUICK-REFERENCE.md`
**Complete Guide**: `mise-task-args-exploration/README.md`

**Happy mise task building!** 🚀
