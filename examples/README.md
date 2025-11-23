# mise CI Examples

Sample configurations demonstrating different approaches for partial tool installation with mise in CI environments.

## Files

### Configuration

- **[mise.toml](mise.toml)** - Sample mise configuration with multiple tools

### Workflows

- **[mise-enable-tools.yaml](workflows/mise-enable-tools.yaml)** - ✅ **Recommended** approach using `MISE_ENABLE_TOOLS`
- **[mise-disable-tools.yaml](workflows/mise-disable-tools.yaml)** - Alternative using `MISE_DISABLE_TOOLS` for exclusions
- **[mise-install-args.yaml](workflows/mise-install-args.yaml)** - Alternative using `install_args` for explicit control
- **[mise-comparison.yaml](workflows/mise-comparison.yaml)** - Side-by-side comparison of old vs new approaches

## Quick Start

### 1. Using MISE_ENABLE_TOOLS (Recommended)

Copy `workflows/mise-enable-tools.yaml` to `.github/workflows/ci.yaml`:

```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python,node"  # Only install these tools
  with:
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

**Why this approach?**
- ✅ Single source of truth (versions in mise.toml)
- ✅ No duplication
- ✅ Simple and declarative

### 2. Using MISE_DISABLE_TOOLS

For excluding a few heavy tools:

```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_DISABLE_TOOLS: "docker,terraform"  # Skip these tools
  with:
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

### 3. Using install_args

For explicit version control in workflow:

```yaml
- uses: jdx/mise-action@v3
  with:
    install_args: "python@3.12 node@20"  # Explicit versions
    cache: true
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

## Scenarios

### Scenario 1: Different Tools per Job

**Use:** `MISE_ENABLE_TOOLS`

```yaml
jobs:
  lint:
    steps:
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "node"  # Only node

  test:
    steps:
      - uses: jdx/mise-action@v3
        env:
          MISE_ENABLE_TOOLS: "python,node"  # Multiple tools
```

See: [mise-enable-tools.yaml](workflows/mise-enable-tools.yaml)

### Scenario 2: Fast PR Checks (Skip Heavy Tools)

**Use:** `MISE_DISABLE_TOOLS`

```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_DISABLE_TOOLS: "docker,terraform,kubectl"
```

See: [mise-disable-tools.yaml](workflows/mise-disable-tools.yaml)

### Scenario 3: Matrix Testing with Different Versions

**Use:** `install_args`

```yaml
strategy:
  matrix:
    python: ["3.11", "3.12"]

steps:
  - uses: jdx/mise-action@v3
    with:
      install_args: "python@${{ matrix.python }}"
```

See: [mise-install-args.yaml](workflows/mise-install-args.yaml)

### Scenario 4: Override mise.toml Versions

**Use:** `install_args`

```yaml
# mise.toml has python = "3.12"
# But we want to test with 3.11
- uses: jdx/mise-action@v3
  with:
    install_args: "python@3.11"
```

## Migration Examples

### From MISE_ENV Approach

**Before:**
```yaml
- uses: jdx/mise-action@v2
  with:
    mise_toml: |
      [env]
      MISE_ENV = "ci"
```

**After:**
```yaml
- uses: jdx/mise-action@v3
  env:
    MISE_ENABLE_TOOLS: "python,node"
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

### From Multi-File Config

**Before:**
- `mise.toml` (dev config)
- `mise.ci.toml` (CI config)
- `mise.prod.toml` (prod config)

**After:**

Single `mise.toml` + `MISE_ENABLE_TOOLS`:

```yaml
# Different tools per environment
env:
  MISE_ENABLE_TOOLS: "python,node"  # CI
  # vs
  MISE_ENABLE_TOOLS: "python,node,docker,kubectl"  # Dev
```

## Best Practices

### 1. Always Provide GitHub Token

```yaml
with:
  github_token: ${{ secrets.GITHUB_TOKEN }}
```

**Why?** Avoid GitHub API rate limits (60/hour without auth).

### 2. Enable Caching

```yaml
with:
  cache: true
  cache_key: "mise-{{platform}}-{{file_hash}}"
```

**Why?** Faster CI runs.

### 3. Use Custom Cache Keys per Job

```yaml
# Lint job
cache_key: "mise-{{platform}}-node-{{file_hash}}"

# Test job
cache_key: "mise-{{platform}}-python-{{file_hash}}"
```

**Why?** Independent caching per job.

### 4. Install Only What You Need

```yaml
# ❌ Don't install everything for every job
MISE_ENABLE_TOOLS: "python,node,docker,terraform,kubectl,helm"

# ✅ Install only what the job needs
MISE_ENABLE_TOOLS: "python"  # For pytest job
```

**Why?** Faster installation, lower resource usage.

### 5. Pin mise-action Version

```yaml
uses: jdx/mise-action@v3  # ✅ Pin major version
# or
uses: jdx/mise-action@v3.0.0  # ✅ Pin exact version
```

## Testing Locally

Test your configuration locally:

```bash
# Test MISE_ENABLE_TOOLS
MISE_ENABLE_TOOLS=python,node mise install

# Test MISE_DISABLE_TOOLS
MISE_DISABLE_TOOLS=docker,terraform mise install

# Verify active tools
mise ls

# Run tasks
mise run test
mise run lint
```

## Troubleshooting

### Tools Not Installing

**Check:**
1. Tool names are correct (case-sensitive)
2. Tools are defined in mise.toml
3. Enable debug logging: `log_level: debug`

### Cache Issues

**Solution:**
```yaml
cache_key: "mise-v2-{{platform}}-{{file_hash}}"  # Bump cache version
```

### Rate Limit Errors

**Solution:**
```yaml
github_token: ${{ secrets.GITHUB_TOKEN }}  # Always provide token
```

## Resources

- [Main Documentation](../MISE-CI-PARTIAL-INSTALL.md)
- [mise Documentation](https://mise.jdx.dev)
- [mise-action Repository](https://github.com/jdx/mise-action)
- [mise Settings](https://mise.jdx.dev/configuration/settings.html)

## Quick Reference

| Approach | Use When | Pros | Cons |
|----------|----------|------|------|
| `MISE_ENABLE_TOOLS` | Default choice | ✅ Simple<br>✅ No duplication | ⚠️ Less explicit |
| `MISE_DISABLE_TOOLS` | Excluding few tools | ✅ Easy to blacklist | ⚠️ Less clear what IS installed |
| `install_args` | Need explicit control | ✅ Self-documenting<br>✅ Version override | ⚠️ Duplication |
| `MISE_ENV` (old) | Don't use | ❌ Complex | ❌ Hard to maintain |

**Recommendation:** Start with `MISE_ENABLE_TOOLS`. Switch to `install_args` only if you need different versions than mise.toml.
