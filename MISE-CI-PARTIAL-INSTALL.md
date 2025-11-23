# mise Partial Tool Installation in CI Environments

Comprehensive guide on configuring mise to selectively install tools in CI pipelines.

## Executive Summary

**Yes, mise provides built-in capabilities for installing only specific tools.** You do **not** need complex multi-file configurations with environment variable workarounds. The recommended approach is using `MISE_ENABLE_TOOLS` environment variable for clean, maintainable CI configurations.

## Table of Contents

- [Key Findings](#key-findings)
- [Available Approaches](#available-approaches)
- [Comparison](#comparison)
- [Best Practices](#best-practices)
- [Complete Examples](#complete-examples)
- [Migration Guide](#migration-guide)
- [References](#references)

---

## Key Findings

### 1. Built-in Single Tool Installation

mise supports installing specific tools directly via CLI:

```bash
# Install specific tool with version
mise install python@3.12

# Install multiple specific tools
mise install python@3.12 node@20

# Install tool using version from mise.toml
mise install python

# Install all tools from mise.toml
mise install
```

### 2. Official Settings for Tool Control

mise provides two complementary settings:

- **`MISE_ENABLE_TOOLS`** - Whitelist (only specified tools are used, all others ignored)
- **`MISE_DISABLE_TOOLS`** - Blacklist (all tools except specified ones are used)

These are **official settings**, not experimental features or workarounds.

### 3. No Complex Configurations Required

Unlike older approaches requiring environment-based config files or MISE_ENV overrides, the modern approach is simple and declarative.

---

## Available Approaches

### Approach 1: MISE_ENABLE_TOOLS (Recommended ✨)

**When to use:** You have a single mise.toml and want different tool subsets per CI job.

```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python,node"
  with:
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

**Pros:**
- ✅ Single source of truth (versions in mise.toml)
- ✅ No duplication of tool names
- ✅ Simple and declarative
- ✅ Tools are completely ignored (not just skipped)

**Cons:**
- ⚠️ Requires tools to be defined in mise.toml
- ⚠️ Less explicit (must check mise.toml to see versions)

### Approach 2: MISE_DISABLE_TOOLS

**When to use:** You want most tools but need to exclude a few heavy ones.

```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_DISABLE_TOOLS: "terraform,docker"
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

**Pros:**
- ✅ Easy when exclusions are fewer than inclusions
- ✅ Reads naturally ("install everything except...")

**Cons:**
- ⚠️ Less explicit about what IS installed

### Approach 3: install_args

**When to use:** You want explicit visibility in the workflow file or need different versions than mise.toml.

```yaml
- uses: jdx/mise-action@v3
  with:
    install_args: "python@3.12 node@20"
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

**Pros:**
- ✅ Explicit about what's installed
- ✅ Can specify versions inline
- ✅ Self-documenting workflows

**Cons:**
- ⚠️ Duplicates tool names (possibly versions)
- ⚠️ Must keep workflow and mise.toml in sync

### Approach 4: Environment-Based Configs (Avoid)

**When to use:** Complex multi-environment setups (generally not recommended).

```yaml
- uses: jdx/mise-action@v2
  with:
    mise_toml: |
      [env]
      MISE_ENV = "ci"
```

**Cons:**
- ❌ Most complex approach
- ❌ Requires understanding config merging
- ❌ Indirection through MISE_ENV
- ❌ More files to maintain

**Verdict:** Use MISE_ENABLE_TOOLS instead.

---

## Comparison

| Feature | MISE_ENABLE_TOOLS | install_args | MISE_ENV |
|---------|-------------------|--------------|----------|
| Complexity | Low | Low | High |
| Explicitness | Medium | High | Low |
| Duplication | None | Tool names/versions | Config files |
| Version management | Centralized | Distributed | Centralized |
| Official support | ✅ Yes | ✅ Yes | ✅ Yes |
| Recommended | ✅ **Best** | ✅ Good | ❌ Avoid |

---

## Best Practices

### 1. Use MISE_ENABLE_TOOLS for Job-Specific Tools

```yaml
jobs:
  lint:
    steps:
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "node"  # Only node for linting

  test:
    steps:
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "python,node"  # Both for tests
```

### 2. Enable Caching with Custom Keys

```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python"
  with:
    cache: true
    cache_key: "mise-{{platform}}-python-{{file_hash}}"
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

### 3. Always Provide GitHub Token

Avoid rate limiting (60 requests/hour without auth):

```yaml
with:
  github_token: ${{ secrets.GITHUB_TOKEN }}
```

### 4. Pin Versions for Reproducibility

In CI, be explicit:

```yaml
- uses: jdx/mise-action@v3
  with:
    version: 2024.10.0  # Pin mise-action version
```

### 5. Use Verbose Output for Debugging

When troubleshooting:

```yaml
- uses: jdx/mise-action@v3
  with:
    log_level: debug
```

---

## Complete Examples

### Example 1: Multi-Job Workflow with Selective Tools

```yaml
name: CI
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "node"
        with:
          cache: true
          cache_key: "mise-{{platform}}-node-{{file_hash}}"
          github_token: ${{ secrets.GITHUB_TOKEN }}
      - run: npm run lint

  test-python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "python"
        with:
          cache: true
          cache_key: "mise-{{platform}}-python-{{file_hash}}"
          github_token: ${{ secrets.GITHUB_TOKEN }}
      - run: |
          python -m pip install -e .[dev]
          pytest

  test-integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "python,node,terraform"
        with:
          cache: true
          github_token: ${{ secrets.GITHUB_TOKEN }}
      - run: ./integration-tests.sh

  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "python"
        with:
          cache: true
          github_token: ${{ secrets.GITHUB_TOKEN }}
      - run: mkdocs build
```

### Example 2: Matrix Build with Selective Tools

```yaml
name: Test Matrix
on: [push]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        python-version: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4

      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "python"
        with:
          cache: true
          cache_key: "mise-{{platform}}-py${{ matrix.python-version }}-{{file_hash}}"
          github_token: ${{ secrets.GITHUB_TOKEN }}

      - run: pytest
```

### Example 3: Exclude Heavy Tools

```yaml
name: Quick Checks
on: [pull_request]

jobs:
  quick-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Install all tools EXCEPT docker and terraform (slow to install)
      - uses: jdx/mise-action@v3
        env:
          MISE_DISABLE_TOOLS: "docker,terraform"
        with:
          cache: true
          github_token: ${{ secrets.GITHUB_TOKEN }}

      - run: npm run test
```

### Example 4: Comparison with install_args

```yaml
# Using MISE_ENABLE_TOOLS (recommended)
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python,node"  # Versions from mise.toml
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}

# Using install_args (alternative)
- uses: jdx/mise-action@v3
  with:
    install_args: "python@3.12 node@20"  # Explicit versions
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

### Sample mise.toml

```toml
# .mise.toml or mise.toml

[tools]
python = "3.12"
node = "20"
terraform = "1.5"
docker = "latest"
kubectl = "1.28"

[tasks.test]
run = "pytest"

[tasks.lint]
run = "npm run lint"

[tasks.integration]
run = "./integration-tests.sh"
depends = ["test"]
```

---

## Migration Guide

### From Environment-Based Config (MISE_ENV approach)

**Before:**
```yaml
- uses: jdx/mise-action@v2
  with:
    mise_toml: |
      [env]
      MISE_ENV = "ci"
```

With separate mise.toml sections:
```toml
[env]
MISE_ENV = "dev"

[tools]
python = "3.12"
node = "20"
terraform = "1.5"
```

**After:**
```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python,node"  # Only what CI needs
  with:
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

With single mise.toml:
```toml
[tools]
python = "3.12"
node = "20"
terraform = "1.5"  # Not installed in CI (not enabled)
```

**Benefits:**
- Simpler configuration
- No environment variable complexity
- Single mise.toml file
- Explicit tool control

### From install_args

**Before:**
```yaml
- uses: jdx/mise-action@v3
  with:
    install_args: "python@3.12 node@20"
    cache: true
```

**After:**
```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python,node"
  with:
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

With mise.toml:
```toml
[tools]
python = "3.12"
node = "20"
```

**Benefits:**
- No version duplication
- Single source of truth
- Easier to maintain

**When NOT to migrate:**
- If you need different versions in CI vs local
- If you want workflow to be completely self-documenting

---

## FAQ

### Q: Can I use both MISE_ENABLE_TOOLS and MISE_DISABLE_TOOLS?

**A:** No, use one or the other. `MISE_ENABLE_TOOLS` takes precedence if both are set.

### Q: Does MISE_ENABLE_TOOLS skip installation or prevent tool loading?

**A:** It prevents tools from being loaded/used at all. Tools not in the list are completely ignored.

### Q: Can I use wildcards or patterns?

**A:** No, you must specify exact tool names as comma-separated values.

### Q: How do I know what tools are defined in mise.toml?

**A:** Run `mise ls` locally or check your mise.toml `[tools]` section.

### Q: What if a tool in MISE_ENABLE_TOOLS isn't in mise.toml?

**A:** mise will ignore it (no error). Only tools defined in mise.toml can be enabled.

### Q: Does caching work with MISE_ENABLE_TOOLS?

**A:** Yes. Use `cache_key: "mise-{{platform}}-{{file_hash}}"` to cache based on mise.toml changes.

### Q: Can I still use mise exec with selective tools?

**A:** Yes. `MISE_ENABLE_TOOLS` is respected by all mise commands.

---

## Troubleshooting

### Tools Not Installing

**Problem:** Tools specified in MISE_ENABLE_TOOLS aren't installing.

**Solution:**
1. Verify tools are defined in mise.toml
2. Check spelling of tool names (case-sensitive)
3. Enable debug logging: `log_level: debug`

### Cache Not Working

**Problem:** Tools reinstall every time.

**Solution:**
```yaml
with:
  cache: true
  cache_key: "mise-{{platform}}-{{file_hash}}"
  github_token: ${{ secrets.GITHUB_TOKEN }}
```

### GitHub API Rate Limits

**Problem:** Installation fails with rate limit errors.

**Solution:**
Always provide GitHub token:
```yaml
with:
  github_token: ${{ secrets.GITHUB_TOKEN }}
```

---

## References

### Documentation
- [mise Settings - disable_tools](https://mise.jdx.dev/configuration/settings.html#disable_tools)
- [mise Settings - enable_tools](https://mise.jdx.dev/configuration/settings.html)
- [mise Continuous Integration](https://mise.jdx.dev/continuous-integration.html)
- [mise CLI - install](https://mise.jdx.dev/cli/install.html)
- [mise-action README](https://github.com/jdx/mise-action)

### Source Code
- [mise Settings Definition](https://github.com/jdx/mise/blob/main/settings.toml)
- [mise-action Repository](https://github.com/jdx/mise-action)

### Related
- [PR #4784 - enable_tools feature](https://github.com/jdx/mise/pull/4784)
- [Discussion #4173 - Running tasks without installing](https://github.com/jdx/mise/discussions/4173)

---

## Conclusion

**Key Takeaways:**

1. ✅ Use `MISE_ENABLE_TOOLS` for clean, maintainable CI configurations
2. ✅ Avoid complex multi-file environment-based setups
3. ✅ Centralize version management in mise.toml
4. ✅ Always provide GitHub token to avoid rate limits
5. ✅ Enable caching for faster CI runs

The mise team has designed `MISE_ENABLE_TOOLS` and `MISE_DISABLE_TOOLS` specifically for selective tool installation. Use them for the simplest and most maintainable CI configuration.
