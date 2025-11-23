# Polyglot Monorepo Example: Python + TypeScript

A complete, production-ready example of a polyglot monorepo using mise for task management, tooling, and environment setup.

## Project Structure

```
polyglot-monorepo/
├── .mise.toml                    # Root configuration
├── README.md                     # This file
│
├── frontend/                     # TypeScript React app
│   ├── .mise.toml               # Frontend-specific config
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   └── tests/
│
├── backend/                      # Python FastAPI service
│   ├── .mise.toml               # Backend-specific config
│   ├── pyproject.toml
│   ├── src/
│   └── tests/
│
├── shared/                       # Shared resources
│   ├── proto/                   # Protocol buffers
│   │   ├── .mise.toml
│   │   └── api.proto
│   └── docs/                    # Documentation
│
└── tools/                        # Development tools
    └── .mise.toml               # Tool configurations
```

## Features Demonstrated

### ✅ Core Capabilities

- **Multi-language support**: Python (backend) + TypeScript (frontend)
- **Shared tooling**: Consistent task interface across projects
- **Dependency management**: Automatic installation with caching
- **Cross-project tasks**: Run tasks across the entire monorepo
- **Environment isolation**: Per-project tool and dependency isolation

### ✅ Advanced Patterns

- **Task caching**: Source/output tracking for intelligent rebuilds
- **Hook automation**: Auto-setup on directory entry
- **Template variables**: Dynamic configuration
- **Cross-project dependencies**: Frontend depends on backend types
- **CI/CD optimization**: Parallel execution, caching

## Quick Start

### Prerequisites

```bash
# Install mise
curl https://mise.run | sh

# Clone and enter the monorepo
cd polyglot-monorepo
```

### First-Time Setup

Mise will automatically:
1. Install required tools (Node, Python, etc.)
2. Create virtual environments
3. Install dependencies
4. Generate shared code

```bash
# Mise auto-activates when you cd into the directory
cd polyglot-monorepo

# List all available tasks
mise tasks --all

# Install all dependencies
mise run install-all
```

### Common Workflows

```bash
# Development
mise run //frontend:dev          # Start frontend dev server
mise run //backend:dev            # Start backend dev server
mise run dev-all                  # Start all services (parallel)

# Testing
mise run //frontend:test          # Test frontend only
mise run //backend:test           # Test backend only
mise //...:test                   # Test everything

# Linting & Type Checking
mise run lint-all                 # Lint all projects
mise run typecheck-all            # Type check all projects

# Building
mise run //frontend:build         # Build frontend
mise run //backend:build          # Build backend
mise run build-all                # Build everything

# CI Pipeline
mise run ci                       # Run full CI pipeline
```

## Task Organization

### Standard Tasks (Available in All Projects)

Every project implements these standard tasks:

| Task | Description | Example |
|------|-------------|---------|
| `install` | Install dependencies | `mise run //frontend:install` |
| `dev` | Start development server | `mise run //backend:dev` |
| `build` | Build for production | `mise run //frontend:build` |
| `test` | Run tests | `mise //...:test` |
| `lint` | Lint code | `mise run //backend:lint` |
| `format` | Format code | `mise run //frontend:format` |
| `typecheck` | Type checking | `mise run typecheck-all` |
| `clean` | Clean build artifacts | `mise run //frontend:clean` |

### Root-Level Tasks

Orchestrate across the entire monorepo:

| Task | Description |
|------|-------------|
| `install-all` | Install dependencies for all projects |
| `dev-all` | Start all development servers (parallel) |
| `test-all` | Run all tests |
| `lint-all` | Lint all projects |
| `typecheck-all` | Type check all TypeScript projects |
| `build-all` | Build all projects |
| `ci` | Full CI pipeline |
| `clean-all` | Clean all build artifacts |

### Hidden Helper Tasks

Internal tasks (prefixed with `:`) used by public tasks:

- `:install` - Dependency installation
- `:typecheck` - Type checking
- `:lint-python` - Python linting
- `:lint-typescript` - TypeScript linting
- `:generate-proto` - Protocol buffer code generation

## Configuration Details

### Root Configuration (.mise.toml)

```toml
[settings]
experimental_monorepo_root = true
task.monorepo_respect_gitignore = true

[tools]
# Shared tools across all projects
node = "20.11.0"
python = "3.12.0"
```

See [.mise.toml](./.mise.toml) for complete configuration.

### Frontend Configuration (frontend/.mise.toml)

```toml
[tools]
"npm:pnpm" = "latest"
"npm:typescript" = "5.3"

[env]
NODE_ENV = "development"
```

See [frontend/.mise.toml](./frontend/.mise.toml) for complete configuration.

### Backend Configuration (backend/.mise.toml)

```toml
[tools]
"pipx:uv" = "latest"
"pipx:ruff" = "latest"

[env]
VIRTUAL_ENV = "{{config_root}}/.venv"
```

See [backend/.mise.toml](./backend/.mise.toml) for complete configuration.

## Development Workflows

### Working on Frontend

```bash
cd frontend

# Development server (auto-installs deps if needed)
mise run dev

# Run tests in watch mode
mise run test-watch

# Type check
mise run typecheck

# Lint and format
mise run lint
mise run format

# Build for production
mise run build
```

### Working on Backend

```bash
cd backend

# Development server with hot reload
mise run dev

# Run tests with coverage
mise run test

# Lint and format
mise run lint
mise run format

# Type check with mypy
mise run typecheck

# Build wheel
mise run build
```

### Working on Shared Code

```bash
cd shared/proto

# Generate code for all languages
mise run generate

# This updates:
# - backend/src/generated/ (Python)
# - frontend/src/generated/ (TypeScript)
```

### Full Stack Development

```bash
# From root directory

# Start everything
mise run dev-all
# This starts:
# - Frontend dev server (http://localhost:5173)
# - Backend API server (http://localhost:8000)

# In another terminal, run tests
mise run test-all

# Run full CI pipeline locally
mise run ci
```

## Environment Variables

### Global Environment

Configured in root `.mise.toml`:

```toml
[env]
REPO_ROOT = "{{config_root}}"
CI = "${CI:-false}"
LOG_LEVEL = "info"
```

### Frontend Environment

```toml
[env]
NODE_ENV = "development"
VITE_API_URL = "http://localhost:8000"
PATH = ["{{config_root}}/node_modules/.bin", "$PATH"]
```

### Backend Environment

```toml
[env]
VIRTUAL_ENV = "{{config_root}}/.venv"
PYTHONPATH = "{{config_root}}/src"
PATH = ["{{config_root}}/.venv/bin", "$PATH"]
DATABASE_URL = "postgresql://localhost/dev"
```

### Environment-Specific Configuration

```bash
# Development (default)
mise run dev

# Staging
MISE_ENV=staging mise run deploy

# Production
MISE_ENV=production mise run deploy
```

## Caching & Performance

### Task Caching

Mise automatically caches tasks based on source/output tracking:

```toml
[tasks.build]
sources = ["src/**/*.ts", "package.json", "tsconfig.json"]
outputs = ["dist/**/*"]
run = "tsc"
```

If sources haven't changed, task is skipped.

### Dependency Caching

Dependencies are only reinstalled when lockfiles change:

```toml
[tasks.install]
sources = ["package.json", "pnpm-lock.yaml"]
outputs = ["node_modules/.pnpm"]
run = "pnpm install --frozen-lockfile"
```

### Build Artifact Caching

Build outputs are cached and reused:

```toml
[tasks.test]
depends = [":build"]  # Only rebuilds if sources changed
run = "jest"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install mise
        uses: jdx/mise-action@v2

      - name: Run CI
        run: mise run ci
```

### GitLab CI Example

```yaml
stages:
  - test

test:
  stage: test
  image: ubuntu:latest
  before_script:
    - curl https://mise.run | sh
    - export PATH="$HOME/.local/bin:$PATH"
  script:
    - mise run ci
```

## Hooks & Automation

### Directory Entry Hook

Automatically sets up environment:

```toml
[hooks]
enter = '''
echo "🚀 Entering polyglot-monorepo"
echo "Environment: ${NODE_ENV:-development}"
echo ""
echo "Quick commands:"
echo "  mise run dev-all    - Start all services"
echo "  mise run test-all   - Run all tests"
echo "  mise tasks --all    - Show all tasks"
'''
```

### Shell Aliases

```toml
[hooks]
enter = '''
alias mt="mise run test-all"
alias mb="mise run build-all"
alias ml="mise run lint-all"
alias md="mise run dev-all"
alias mci="mise run ci"
'''
```

## Best Practices Implemented

### ✅ Consistent Interface

- Every project has same task names
- `mise //...:test` works everywhere
- Predictable for developers

### ✅ Dependency Management

- Automatic installation with caching
- Per-project isolation
- Lockfile-based reproducibility

### ✅ Documentation

- Every task has a description
- Usage specs for complex tasks
- Self-documenting configuration

### ✅ Performance

- Source/output tracking
- Intelligent caching
- Parallel execution

### ✅ Developer Experience

- Auto-setup on directory entry
- Shell aliases for common tasks
- Clear error messages

## Troubleshooting

### Tasks Not Found

```bash
# Verify mise is activated
mise doctor

# List all tasks
mise tasks --all

# Check specific project
mise tasks //frontend:
```

### Dependencies Not Installing

```bash
# Force reinstall
mise run //frontend:clean
rm -rf frontend/node_modules
mise run //frontend:install

# Check tool versions
mise list
```

### Caching Issues

```bash
# Clear mise cache
rm -rf ~/.cache/mise

# Clean all build artifacts
mise run clean-all

# Force rebuild
mise run build-all --force
```

## Additional Resources

- [Mise Documentation](https://mise.jdx.dev)
- [Task Arguments Guide](https://mise.jdx.dev/tasks/task-arguments.html)
- [Monorepo Best Practices](../BEST-PRACTICES.md)
- [Mise Task Cookbook](https://github.com/jdx/mise/discussions/3645)

## Contributing

1. Follow the task naming conventions
2. Add descriptions to all tasks
3. Use source/output tracking for caching
4. Test changes with `mise run ci`

## License

MIT
