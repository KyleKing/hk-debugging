# Mise Task Arguments Exploration - Quick Reference Index

**Quick Links:** [Summary](SUMMARY.md) | [User Guide](README.md) | [Findings](FINDINGS.md) | [Examples](.mise.toml) | [Edge Cases](.mise.edge-cases.toml) | [Claude Skill](../.claude/skills/mise/mise-expert.md)

---

## 📁 Project Files

| File | Purpose | Lines | Description |
|------|---------|-------|-------------|
| `.mise.toml` | Main examples | ~600 | 15 practical task examples |
| `.mise.edge-cases.toml` | Edge cases | ~500 | 20 edge case scenarios |
| `README.md` | User guide | ~400 | Complete usage documentation |
| `FINDINGS.md` | Analysis | ~700 | Detailed technical findings |
| `SUMMARY.md` | Overview | ~500 | High-level summary |
| `INDEX.md` | This file | ~200 | Quick reference guide |
| `test-runner.sh` | Testing | ~200 | Automated test script |
| `.claude/skills/mise/mise-expert.md` | Claude Skill | ~600 | Expert knowledge base |

---

## 🎯 Quick Start

### If you have mise installed:
```bash
cd mise-task-args-exploration
mise tasks                    # List all tasks
mise run test:full --help     # Get help
mise run test:coverage --html # Run an example
./test-runner.sh              # Run automated tests
```

### If you don't have mise:
```bash
# Read the examples and documentation
cat README.md        # Start here
cat .mise.toml       # Browse examples
cat FINDINGS.md      # Learn about edge cases
```

---

## 📚 Main Examples (.mise.toml)

### Pytest Basic Examples
| Task | Command | Description |
|------|---------|-------------|
| `test:basic` | `mise run test:basic -- tests/` | Basic pass-through |
| `test:debug` | `mise run test:debug --verbose --fail-fast` | Flag transformation |
| `test:mixed` | `mise run test:mixed --verbose -- tests/` | Hybrid approach |

### Pytest with Coverage
| Task | Command | Description |
|------|---------|-------------|
| `test:coverage` | `mise run test:coverage --html` | Coverage with formats |
| `test:full` | `mise run test:full --verbose --coverage --marker unit` | Complete workflow |

### Multi-Command Examples
| Task | Command | Description |
|------|---------|-------------|
| `test:multi` | `mise run test:multi --verbose` | Sequential commands |
| `test:pipeline` | `mise run test:pipeline --stage all` | Full CI pipeline |

### Advanced Features
| Task | Command | Description |
|------|---------|-------------|
| `test:env` | `mise run test:env --env staging` | Choice constraints |
| `test:count` | `mise run test:count -vvv` | Counting flags |
| `test:negate` | `mise run test:negate --no-cache` | Negatable flags |
| `test:conditional` | `mise run test:conditional --format html --output-dir /tmp` | Conditional required |
| `test:variadic` | `mise run test:variadic file1.py file2.py` | Min/max constraints |

---

## 🔍 Edge Cases (.mise.edge-cases.toml)

### Critical Security
| Task | Issue | Severity |
|------|-------|----------|
| `edge:injection` | Shell injection risk | 🔴 Critical |
| `edge:special-chars` | Spaces in paths | 🟡 High |

### Type & Validation
| Task | Issue | Severity |
|------|-------|----------|
| `edge:boolean-types` | Boolean string confusion | 🟡 Medium |
| `edge:empty-vs-undefined` | Empty string handling | 🟡 Medium |
| `edge:choice-validation` | Choice validation timing | 🟢 Low |
| `edge:required-missing` | Required flag validation | 🟢 Low |
| `edge:minmax` | Min/max edge cases | 🟢 Low |

### Advanced Behavior
| Task | Issue | Severity |
|------|-------|----------|
| `edge:count-edge` | Count flag conversion | 🟡 Medium |
| `edge:negate-default` | Negate flag behavior | 🟢 Low |
| `edge:conflicts` | Overrides attribute | 🟢 Low |
| `edge:multi-run-scope` | Variable scope | 🟢 Low |
| `edge:name-collision` | Arg/flag collision | 🟡 Medium |

### Special Characters
| Task | Issue | Severity |
|------|-------|----------|
| `edge:unicode` | UTF-8 handling | 🟢 Low |
| `edge:whitespace-default` | Whitespace preservation | 🟢 Low |
| `edge:double-dash` | Double-dash separation | 🟢 Low |

### Other
| Task | Issue | Severity |
|------|-------|----------|
| `edge:env-expansion` | Environment variables | 🟢 Low |
| `edge:required-combo` | Required unless/if | 🟢 Low |
| `edge:dep-caller` | Task dependencies | 🟢 Low |
| `edge:variadic-empty` | Empty variadic args | 🟢 Low |
| `edge:long-help` | Help text rendering | 🟢 Low |

---

## 📖 Documentation Guide

### For Beginners
1. Start with [SUMMARY.md](SUMMARY.md) - High-level overview
2. Read [README.md](README.md) - Complete user guide
3. Browse [.mise.toml](.mise.toml) - Real examples

### For Advanced Users
1. Review [FINDINGS.md](FINDINGS.md) - Technical deep dive
2. Study [.mise.edge-cases.toml](.mise.edge-cases.toml) - Edge cases
3. Check [test-runner.sh](test-runner.sh) - Automated testing

### For Claude Code Users
1. Use the [Claude Skill](../.claude/skills/mise/mise-expert.md)
2. Ask Claude about mise configuration
3. Get instant pattern recommendations

---

## 🔑 Key Patterns

### Pattern 1: Simple Transformation
```toml
usage = 'flag "--debug" default=#false'
run = '''
[ "$usage_debug" = "true" ] && pytest -vvv -x -s || pytest -v
'''
```

### Pattern 2: Multiple Flags
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

### Pattern 3: Pass-Through
```toml
usage = 'arg "[paths...]" var=#true'
run = 'pytest $usage_paths'
```

### Pattern 4: Validation
```toml
usage = '''
flag "--env <env>" default="local" {
  choices "local" "staging" "prod"
}
'''
run = 'deploy.sh $usage_env'
```

---

## ⚠️ Common Pitfalls

### 1. Unquoted Variables
```bash
# ❌ Bad - breaks with spaces
pytest $usage_path

# ✅ Good - safe
pytest "$usage_path"
```

### 2. Boolean Checks
```bash
# ❌ Risky - relies on true/false commands
if $usage_verbose; then

# ✅ Good - explicit string comparison
if [ "$usage_verbose" = "true" ]; then
```

### 3. Variadic Args with Spaces
```bash
# ⚠️ Issue - may split incorrectly
mise run test -- "file with spaces.py"

# ✅ Workaround - quote in run script
pytest "$usage_files"
```

---

## 🎓 Usage Syntax Cheat Sheet

### Flags
```toml
flag "-f --force" help="Force operation" default=#false
flag "-u --user <user>" help="Username" env="USER"
flag "-v --verbose" count=#true
flag "--cache" negate="--no-cache" default=#true
```

### Arguments
```toml
arg "<file>" help="Required file"
arg "[file]" help="Optional file"
arg "[files...]" var=#true help="Multiple files"
arg "<files...>" var=#true var_min=1 var_max=10
```

### Validation
```toml
required=#true
required_if="--other-flag"
required_unless="--other-flag"
choices "opt1" "opt2" "opt3"
```

---

## 🧪 Testing Checklist

- [ ] Install mise (`curl https://mise.run | sh`)
- [ ] List tasks (`mise tasks`)
- [ ] Run automated tests (`./test-runner.sh`)
- [ ] Test basic examples (`mise run test:basic --help`)
- [ ] Test edge cases (`mise run edge:* --help`)
- [ ] Test with special characters
- [ ] Test on your platform (Linux/macOS/Windows)

---

## 🐛 Known Issues Summary

| ID | Issue | Severity | Workaround |
|----|-------|----------|------------|
| MISE-ARG-001 | Variadic args with spaces | 🔴 High | Quote expansions |
| MISE-ARG-002 | Shell injection risk | 🔴 Critical | Validate input, quote vars |
| MISE-ARG-003 | Count flag conversion | 🟡 Medium | Use bash loop |
| MISE-ARG-004 | Boolean type confusion | 🟡 Medium | Use string comparison |
| MISE-ARG-005 | Empty vs undefined | 🟡 Medium | Needs testing |
| MISE-ARG-006 | Name collision | 🟡 Medium | Avoid duplicates |

See [FINDINGS.md](FINDINGS.md) for complete details.

---

## 📦 What's New in This Exploration

### Contributions to Mise Community
- ✅ 15 practical pytest examples
- ✅ 20 edge case test scenarios
- ✅ Comprehensive documentation
- ✅ Automated test runner
- ✅ Claude integration (skill)
- ✅ Security considerations
- ✅ Best practices guide

### Unique Insights
- Detailed analysis of variadic argument limitations
- Shell injection security considerations
- Boolean type handling clarification
- Count flag conversion patterns
- Multi-stage pipeline examples
- Coverage integration patterns

---

## 🚀 Next Steps

### For Users
1. Copy patterns you need
2. Adapt to your tools
3. Test thoroughly
4. Share improvements

### For Contributors
1. Test all edge cases with mise installed
2. Report confirmed bugs to [mise issues](https://github.com/jdx/mise/issues)
3. Submit documentation improvements
4. Share new patterns

### For the Mise Project
1. Consider built-in array support for variadic args
2. Improve documentation on boolean types
3. Add security guidelines
4. Consider argument transformation helpers

---

## 📞 Resources

### Official
- [Mise Docs](https://mise.jdx.dev)
- [Task Arguments](https://mise.jdx.dev/tasks/task-arguments.html)
- [Usage Spec](https://usage.jdx.dev)

### Community
- [Mise GitHub](https://github.com/jdx/mise)
- [Usage GitHub](https://github.com/jdx/usage)
- [Discussion #6766](https://github.com/jdx/mise/discussions/6766)

### This Project
- All files are in `mise-task-args-exploration/`
- Claude Skill is in `.claude/skills/mise/`
- Everything is self-contained and documented

---

**Last Updated:** 2025-11-23
**Status:** Complete and ready to use
**License:** Educational use, provided as-is

Happy mise task building! 🎉
