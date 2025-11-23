# Mise Best Practices: Monorepo Task Management

A comprehensive knowledge base for organizing and managing tasks, tools, and environments in monorepo projects using mise.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Task Organization](#task-organization)
3. [Dependency Management](#dependency-management)
4. [Environment Variables](#environment-variables)
5. [Hooks and Automation](#hooks-and-automation)
6. [Caching Strategies](#caching-strategies)
7. [Multi-Language Projects](#multi-language-projects)
8. [Real-World Patterns](#real-world-patterns)

---

## Core Principles

### 1. **Hierarchical Task Organization**

Organize tasks into logical hierarchies with clear dependencies.

**Pattern: Parent-Child Tasks**
```toml
# Internal/helper tasks (hidden)
[tasks.":install"]
description = "Install dependencies (internal)"
hide = true
run = "pnpm install"

[tasks.":typecheck"]
description = "Type check TypeScript (internal)"
hide = true
run = "tsc --noEmit"

# Public tasks that compose helpers
[tasks.dev]
description = "Start development server"
depends = [":install"]
run = "pnpm dev"

[tasks.check]
description = "Run all checks"
depends = [":typecheck", "lint", "test"]
run = "echo 'All checks passed!'"
```

**Why:**
- Internal tasks (`:prefix`) are hidden from `mise tasks` output
- Reduces clutter in task listings
- Reusable components across multiple public tasks
- Clear separation of concerns

### 2. **Consistent Naming Conventions**

Use consistent task names across all projects in a monorepo.

**Standard Task Names:**
```toml
# Every project should have these (if applicable)
[tasks.dev]        # Start development server
[tasks.build]      # Build for production
[tasks.test]       # Run tests
[tasks.lint]       # Lint code
[tasks.format]     # Format code
[tasks.clean]      # Clean build artifacts
[tasks.typecheck]  # Type checking
[tasks.ci]         # Full CI pipeline
```

**Why:**
- Enables `mise //...:test` to work across all projects
- Predictable interface for developers
- Easy to document and teach
- Simplifies CI/CD configuration

### 3. **Descriptive Documentation**

Always document task purposes and usage.

```toml
[tasks.deploy]
description = "Deploy application to cloud (requires AWS credentials)"
usage = '''
flag "--env <env>" help="Target environment (dev/staging/prod)" {
  choices "dev" "staging" "prod"
}
flag "--dry-run" help="Preview deployment without applying" default=#false
'''
run = "./scripts/deploy.sh $usage_env $usage_dry_run"
```

**Why:**
- Self-documenting configuration
- Easier onboarding for new developers
- Reduces questions in team communications
- `mise run task --help` provides useful information

---

## Task Organization

### Pattern 1: Task Categories with Aliases

Group related tasks and provide short aliases.

```toml
# Testing tasks
[tasks.test]
description = "Run all tests"
alias = "t"
run = "pytest"

[tasks.test-unit]
description = "Run unit tests only"
alias = "tu"
run = "pytest tests/unit"

[tasks.test-integration]
description = "Run integration tests only"
alias = "ti"
run = "pytest tests/integration"

[tasks.test-watch]
description = "Run tests in watch mode"
alias = "tw"
run = "pytest-watch"

# Linting tasks
[tasks.lint]
description = "Run all linters"
alias = "l"
depends = [":lint-python", ":lint-typescript"]
run = "echo 'Linting complete'"

[tasks.":lint-python"]
hide = true
run = "ruff check ."

[tasks.":lint-typescript"]
hide = true
run = "eslint ."
```

**Best Practices:**
- Use single-letter aliases for frequently-used commands
- Group related tasks with common prefix
- Create aggregator tasks for running multiple checks

### Pattern 2: Source and Output Tracking

Leverage mise's caching with source/output specifications.

```toml
[tasks.build]
description = "Build application"
sources = ["src/**/*.ts", "package.json", "tsconfig.json"]
outputs = ["dist/**/*"]
run = "tsc"

[tasks.test]
description = "Run tests"
sources = ["src/**/*.ts", "tests/**/*.ts"]
outputs = [".coverage"]
run = "pytest --cov"
```

**Why:**
- Mise skips tasks if sources haven't changed
- Faster development cycles
- Intelligent caching reduces redundant work
- Clear documentation of task inputs/outputs

### Pattern 3: Parallel vs Sequential Execution

Control task execution order explicitly.

```toml
# Sequential - each depends on previous
[tasks.ci]
description = "Full CI pipeline (sequential)"
depends = ["clean", "install", "lint", "typecheck", "test", "build"]
run = "echo 'CI complete'"

# Parallel - independent tasks can run together
[tasks.check-parallel]
description = "Run checks in parallel"
run = '''
# Run these in background
mise run lint &
mise run typecheck &
mise run test &

# Wait for all
wait
echo "All checks complete"
'''
```

**When to use:**
- **Sequential (depends)**: When tasks have dependencies
- **Parallel**: When tasks are independent and can benefit from concurrency

---

## Dependency Management

### Pattern 1: Lazy Installation

Install dependencies only when needed.

```toml
[tasks.":ensure-deps"]
description = "Ensure dependencies are installed"
hide = true
sources = ["package.json", "pnpm-lock.yaml"]
outputs = ["node_modules/.pnpm"]
run = "pnpm install --frozen-lockfile"

[tasks.dev]
depends = [":ensure-deps"]
run = "pnpm dev"

[tasks.build]
depends = [":ensure-deps"]
run = "pnpm build"
```

**Why:**
- Don't run `pnpm install` on every command
- Source/output tracking prevents unnecessary installs
- Faster task execution

### Pattern 2: Multi-Language Dependencies

Handle dependencies for different languages.

```toml
# Root .mise.toml
[tasks.":install-all"]
description = "Install all dependencies"
hide = true
run = [
  "mise run //frontend:install",
  "mise run //backend:install",
  "mise run //shared:install"
]

# frontend/.mise.toml (TypeScript)
[tasks.install]
sources = ["package.json", "pnpm-lock.yaml"]
outputs = ["node_modules/.pnpm"]
run = "pnpm install"

# backend/.mise.toml (Python)
[tasks.install]
sources = ["pyproject.toml", "uv.lock"]
outputs = [".venv"]
run = "uv sync"

# shared/.mise.toml (Shared tools)
[tasks.install]
run = [
  "cargo install cargo-nextest",
  "go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
]
```

### Pattern 3: Conditional Dependencies

Use environment variables to control dependencies.

```toml
[tasks.test]
description = "Run tests (install deps if needed)"
run = '''
if [ ! -d "node_modules" ] || [ package.json -nt node_modules ]; then
  echo "Installing dependencies..."
  pnpm install
fi
pytest
'''
```

---

## Environment Variables

### Pattern 1: Template Variables

Use mise's template system for dynamic configuration.

```toml
[env]
# Project paths
PROJECT_ROOT = "{{config_root}}"
BUILD_DIR = "{{config_root}}/dist"
CACHE_DIR = "{{config_root}}/.cache"

# Language-specific
NODE_ENV = "development"
PYTHON_PATH = "{{config_root}}/src"
GOPATH = "{{config_root}}/.go"

# Custom gem directory (Ruby)
GEM_HOME = "{{config_root}}/.gem"
GEM_PATH = "{{config_root}}/.gem"

# Dynamic execution
GIT_BRANCH = "{{exec(command='git branch --show-current')}}"
VERSION = "{{exec(command='git describe --tags --always')}}"
```

**Template Functions:**
- `{{config_root}}` - Current mise config directory
- `{{env.VAR}}` - Access environment variables
- `{{exec(command='...')}}` - Execute shell commands

### Pattern 2: Environment-Specific Configuration

Support multiple environments.

```toml
# .mise.toml
[env]
NODE_ENV = "development"
API_URL = "http://localhost:3000"

# .mise.production.toml
[env]
NODE_ENV = "production"
API_URL = "https://api.example.com"

# .mise.staging.toml
[env]
NODE_ENV = "staging"
API_URL = "https://staging-api.example.com"
```

**Usage:**
```bash
# Development (default)
mise run dev

# Staging
MISE_ENV=staging mise run deploy

# Production
MISE_ENV=production mise run deploy
```

### Pattern 3: Per-Project Isolation

Isolate dependencies per project.

```toml
# Python project
[env]
VIRTUAL_ENV = "{{config_root}}/.venv"
PATH = ["{{config_root}}/.venv/bin", "$PATH"]
PYTHONPATH = "{{config_root}}/src"

# Node.js project
[env]
NODE_PATH = "{{config_root}}/node_modules"
PATH = ["{{config_root}}/node_modules/.bin", "$PATH"]

# Ruby project
[env]
GEM_HOME = "{{config_root}}/.gem"
GEM_PATH = "{{config_root}}/.gem"
PATH = ["{{config_root}}/.gem/bin", "$PATH"]

# Go project
[env]
GOPATH = "{{config_root}}/.go"
GOCACHE = "{{config_root}}/.cache/go-build"
PATH = ["{{config_root}}/.go/bin", "$PATH"]
```

**Why:**
- No global pollution
- Project-specific versions
- Easy cleanup (delete project directory)
- Reproducible environments

---

## Hooks and Automation

### Pattern 1: Enter Hooks for Setup

Automatically setup environment when entering directory.

```toml
[hooks]
enter = '''
# Create necessary directories
mkdir -p .cache .tmp logs

# Install dependencies if needed
if [ ! -f .setup-complete ]; then
  echo "First-time setup..."
  mise run install
  touch .setup-complete
fi

# Show current environment
echo "Environment: ${NODE_ENV:-development}"
echo "Project: $(basename $PWD)"
'''
```

### Pattern 2: Shell-Specific Hooks

Provide shell-specific configurations.

```toml
[hooks]
# Bash-specific
enter.bash = '''
# Enable bash completion
source <(mise completion bash)

# Custom PS1 prompt
export PS1="[mise: $(basename $PWD)] $PS1"
'''

# Zsh-specific
enter.zsh = '''
# Enable zsh completion
source <(mise completion zsh)

# Custom prompt
PROMPT="[mise: $(basename $PWD)] $PROMPT"
'''

# Fish-specific
enter.fish = '''
# Enable fish completion
mise completion fish | source

# Custom prompt
function fish_prompt
    echo "[mise: $(basename $PWD)] ❯ "
end
'''
```

### Pattern 3: Automatic Alias Generation

Create shell aliases from tasks.

```toml
[hooks]
enter = '''
# Generate aliases for common tasks
alias mt="mise run test"
alias mb="mise run build"
alias ml="mise run lint"
alias md="mise run dev"

# Show available aliases
echo "Aliases: mt (test), mb (build), ml (lint), md (dev)"
'''
```

---

## Caching Strategies

### Pattern 1: Build Artifact Caching

Cache build outputs intelligently.

```toml
[tasks.build]
description = "Build with caching"
sources = [
  "src/**/*.ts",
  "package.json",
  "tsconfig.json"
]
outputs = [
  "dist/**/*.js",
  "dist/**/*.d.ts"
]
run = '''
# Check if rebuild needed
if mise task needs-rebuild build; then
  echo "Building..."
  tsc
else
  echo "Using cached build"
fi
'''
```

### Pattern 2: Test Result Caching

Cache test results based on source changes.

```toml
[tasks.test]
description = "Run tests with caching"
sources = [
  "src/**/*.ts",
  "tests/**/*.ts",
  "pytest.ini"
]
outputs = [
  ".pytest_cache",
  ".coverage"
]
run = "pytest --cache-show"
```

### Pattern 3: Cross-Project Caching

Share cache across related projects.

```toml
# Root .mise.toml
[env]
SHARED_CACHE = "{{config_root}}/.cache/shared"

# Project A
[tasks.build]
env = { CACHE_DIR = "${SHARED_CACHE}/project-a" }
run = "build-tool --cache $CACHE_DIR"

# Project B (can reuse shared artifacts)
[tasks.build]
env = { CACHE_DIR = "${SHARED_CACHE}/project-b" }
run = "build-tool --cache $CACHE_DIR --shared-cache ${SHARED_CACHE}/project-a"
```

---

## Multi-Language Projects

### Pattern 1: Python + TypeScript Monorepo

Organize polyglot monorepo with mise.

```toml
# Root .mise.toml
[settings]
experimental_monorepo_root = true

[tools]
# Shared tools
node = "20.11.0"
python = "3.12"
"cargo:cargo-nextest" = "latest"

[env]
# Shared environment
REPO_ROOT = "{{config_root}}"
CI = "${CI:-false}"

[tasks.install-all]
description = "Install all project dependencies"
run = [
  "mise run //frontend:install",
  "mise run //backend:install",
  "mise run //services/...:install"
]

[tasks.test-all]
description = "Test all projects"
run = "mise //...:test"

[tasks.lint-all]
description = "Lint all projects"
run = "mise //...:lint"

[tasks.ci]
description = "Full CI pipeline"
depends = ["install-all", "lint-all", "test-all", "build-all"]
run = "echo 'CI complete!'"
```

**Frontend (TypeScript):**
```toml
# frontend/.mise.toml
[tools]
"npm:pnpm" = "latest"
"npm:typescript" = "5.3"

[env]
NODE_ENV = "development"
PATH = ["{{config_root}}/node_modules/.bin", "$PATH"]

[tasks.install]
sources = ["package.json", "pnpm-lock.yaml"]
outputs = ["node_modules/.pnpm"]
run = "pnpm install"

[tasks.dev]
depends = [":install"]
run = "pnpm dev"

[tasks.build]
depends = [":install"]
sources = ["src/**/*", "tsconfig.json"]
outputs = ["dist/**/*"]
run = "pnpm build"

[tasks.test]
depends = [":install"]
run = "pnpm test"

[tasks.lint]
run = "eslint . --ext .ts,.tsx"

[tasks.typecheck]
run = "tsc --noEmit"
```

**Backend (Python):**
```toml
# backend/.mise.toml
[tools]
python = "3.12"
"pipx:uv" = "latest"
"pipx:ruff" = "latest"

[env]
VIRTUAL_ENV = "{{config_root}}/.venv"
PATH = ["{{config_root}}/.venv/bin", "$PATH"]
PYTHONPATH = "{{config_root}}/src"

[tasks.install]
sources = ["pyproject.toml", "uv.lock"]
outputs = [".venv"]
run = "uv sync"

[tasks.dev]
depends = [":install"]
run = "uvicorn main:app --reload"

[tasks.build]
depends = [":install"]
run = "uv build"

[tasks.test]
depends = [":install"]
sources = ["src/**/*.py", "tests/**/*.py"]
outputs = [".coverage"]
run = "pytest --cov"

[tasks.lint]
run = "ruff check ."

[tasks.format]
run = "ruff format ."

[tasks.typecheck]
run = "mypy src"
```

### Pattern 2: Shared Code Generation

Generate shared code across projects.

```toml
# common/proto/.mise.toml
[tasks.generate]
description = "Generate code from protobuf definitions"
sources = ["*.proto"]
outputs = [
  "generated/python/**/*.py",
  "generated/typescript/**/*.ts"
]
run = '''
# Generate Python bindings
protoc --python_out=generated/python *.proto

# Generate TypeScript bindings
protoc --ts_out=generated/typescript *.proto

echo "Generated code updated"
'''

# frontend/.mise.toml (TypeScript)
[tasks.proto]
description = "Update protobuf definitions"
run = "mise run //common/proto:generate"

[tasks.dev]
depends = [":proto", ":install"]
run = "pnpm dev"

# backend/.mise.toml (Python)
[tasks.proto]
description = "Update protobuf definitions"
run = "mise run //common/proto:generate"

[tasks.dev]
depends = [":proto", ":install"]
run = "uvicorn main:app --reload"
```

### Pattern 3: Cross-Language Testing

Test integrations across language boundaries.

```toml
# Root .mise.toml
[tasks.test-integration]
description = "Run cross-language integration tests"
run = '''
# Start backend
mise run //backend:dev &
BACKEND_PID=$!

# Wait for backend to be ready
sleep 5

# Run frontend integration tests
mise run //frontend:test-integration

# Cleanup
kill $BACKEND_PID
'''

[tasks.test-e2e]
description = "Run end-to-end tests"
depends = [
  "//backend:build",
  "//frontend:build"
]
run = '''
# Start full stack
docker-compose up -d

# Run E2E tests
mise run //e2e:test

# Cleanup
docker-compose down
'''
```

---

## Real-World Patterns

### Pattern 1: Docker Integration

Run tasks in Docker for consistency.

```toml
[tasks.test-docker]
description = "Run tests in Docker (clean environment)"
run = '''
docker run --rm \
  -v $(pwd):/app \
  -w /app \
  node:20-alpine \
  sh -c "npm install && npm test"
'''

[tasks.":docker-build"]
hide = true
sources = ["Dockerfile", "src/**/*"]
outputs = [".docker-built"]
run = '''
docker build -t myapp:latest .
touch .docker-built
'''

[tasks.deploy]
depends = [":docker-build"]
run = "docker push myapp:latest"
```

### Pattern 2: Git Integration

Integrate with git workflows.

```toml
[env]
GIT_BRANCH = "{{exec(command='git branch --show-current')}}"
GIT_COMMIT = "{{exec(command='git rev-parse --short HEAD')}}"
GIT_DIRTY = "{{exec(command='git diff --quiet || echo \"-dirty\"')}}"
VERSION = "{{exec(command='git describe --tags --always')}}"

[tasks.pre-commit]
description = "Pre-commit checks"
run = [
  "mise run lint",
  "mise run typecheck",
  "mise run test"
]

[tasks.tag-version]
description = "Tag current version"
usage = '''
arg "<version>" help="Version to tag (e.g., v1.2.3)"
'''
run = '''
git tag -a "$usage_version" -m "Release $usage_version"
git push origin "$usage_version"
'''
```

### Pattern 3: CI/CD Optimization

Optimize CI/CD pipelines.

```toml
[tasks.ci-test]
description = "CI-optimized test run"
env = { CI = "true" }
run = '''
# Use CI-specific optimizations
pytest \
  --maxfail=1 \
  --tb=short \
  --cov \
  --cov-report=xml \
  --junitxml=test-results.xml
'''

[tasks.ci-build]
description = "CI-optimized build"
env = { NODE_ENV = "production" }
run = '''
# Skip sourcemaps in CI
pnpm build --no-sourcemap

# Verify build
du -sh dist/
ls -lh dist/
'''

[tasks.ci]
description = "Full CI pipeline"
env = { CI = "true" }
run = [
  "mise run install-all",
  "mise run lint-all",
  "mise run typecheck-all",
  "mise run test-all",
  "mise run build-all"
]
```

### Pattern 4: Watch Mode

Implement watch mode for development.

```toml
[tasks.watch-test]
description = "Run tests in watch mode"
run = "pytest-watch"

[tasks.watch-build]
description = "Build in watch mode"
run = "tsc --watch"

[tasks.watch-all]
description = "Watch all (parallel)"
run = '''
mise run watch-test &
mise run watch-build &
mise run dev &

# Wait for all
wait
'''
```

### Pattern 5: Debugging Support

Add debugging helpers.

```toml
[tasks.debug]
description = "Start with debugger attached"
usage = '''
arg "[file]" help="File to debug" default="src/main.py"
'''
run = 'python -m pdb "$usage_file"'

[tasks.debug-node]
description = "Start Node with debugger"
run = "node --inspect-brk src/index.ts"

[tasks.debug-test]
description = "Debug specific test"
usage = '''
arg "<test>" help="Test file or pattern"
'''
run = 'pytest --pdb "$usage_test"'

[tasks.":debug-info"]
description = "Show debug information"
hide = true
run = '''
echo "=== Environment ==="
env | sort

echo -e "\n=== Tools ==="
mise list

echo -e "\n=== Tasks ==="
mise tasks

echo -e "\n=== Git Status ==="
git status --short
'''
```

---

## Summary

### Key Takeaways

1. **Organization Matters**
   - Use hierarchical tasks with `:prefix` for internal helpers
   - Consistent naming across projects
   - Document everything

2. **Leverage Mise Features**
   - Source/output tracking for caching
   - Template variables for dynamic config
   - Hooks for automation

3. **Multi-Language Support**
   - Per-project tool isolation
   - Cross-project dependencies
   - Shared code generation

4. **Optimize for Teams**
   - Self-documenting tasks
   - Aliases for common operations
   - Clear dependency chains

5. **CI/CD Integration**
   - Environment-specific configs
   - Parallel execution where possible
   - Intelligent caching

### Common Anti-Patterns to Avoid

❌ **Don't**: Global installation of language-specific tools
✅ **Do**: Use mise to manage per-project tool versions

❌ **Don't**: Repeat dependency installation in every task
✅ **Do**: Use hidden helper tasks with source/output tracking

❌ **Don't**: Hard-code paths and environment values
✅ **Do**: Use template variables and env configs

❌ **Don't**: Create monolithic tasks that do everything
✅ **Do**: Compose small, focused tasks with dependencies

❌ **Don't**: Ignore task documentation
✅ **Do**: Add descriptions and usage specs

### Additional Resources

- [Mise Documentation](https://mise.jdx.dev)
- [Mise Task Cookbook](https://github.com/jdx/mise/discussions/3645)
- [Monorepo Tools Comparison](https://www.aviator.co/blog/monorepo-tools/)
- [TypeScript Monorepo Setup](https://earthly.dev/blog/setup-typescript-monorepo/)

---

**Last Updated**: 2025-11-23
**Version**: 1.0
**Maintainer**: Claude Code / Mise Expert Skill
