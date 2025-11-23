# Mise + fnox Secrets Management Integration Guide

## Executive Summary

This guide demonstrates how to replace manual `.dev.env` file management with an automated, secure secrets management solution using **mise** and **fnox**.

### Key Benefits

- **No manual secret downloads**: Secrets automatically loaded from secure sources
- **Environment switching**: Seamlessly switch between local, staging, and production
- **Version controlled configuration**: Share setup across team (without exposing secrets)
- **Multiple backends**: Mix encrypted git storage, AWS Secrets Manager, KMS, and LocalStack
- **Developer experience**: Automatic secret loading when entering project directory

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Developer Workflow                    │
├─────────────────────────────────────────────────────────┤
│  cd project/ → mise automatically loads fnox → secrets  │
│  available as environment variables                      │
└─────────────────────────────────────────────────────────┘

┌─────────────┐     ┌──────────┐     ┌─────────────────┐
│    mise     │────▶│   fnox   │────▶│  Secret Sources │
│ (env mgmt)  │     │(sec mgmt)│     ├─────────────────┤
└─────────────┘     └──────────┘     │ • Age encrypted │
                                     │ • AWS Secrets   │
                                     │ • AWS KMS       │
                                     │ • LocalStack    │
                                     │ • 1Password     │
                                     └─────────────────┘
```

## Current State vs Proposed Solution

### Current Workflow (Problems)
```
1. Developer manually downloads .dev.env from secure location
2. File contains mix of KMS-encrypted secrets and plaintext
3. Manual updates required when secrets change
4. Risk of committing secrets to git
5. No easy environment switching
6. Inconsistent setup across team members
```

### Proposed Workflow (Benefits)
```
1. Developer runs: fnox init (one-time setup)
2. Secrets automatically pulled from appropriate source
3. Environment switching: fnox exec --profile {local|staging|prod}
4. Secrets never in plaintext in git
5. Team shares encrypted secrets OR cloud references
6. Consistent setup via version-controlled fnox.toml
```

## Installation

### 1. Install mise

```bash
# Install mise (package manager for dev tools)
curl https://mise.run | sh

# Or use package manager
# brew install mise  # macOS
# apt install mise   # Ubuntu/Debian

# Add to shell (bash example)
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Install fnox via mise

```bash
# Install fnox globally
mise use -g fnox

# Verify installation
fnox --version
```

### 3. Initialize fnox in your project

```bash
cd your-project/
fnox init

# This creates fnox.toml in your project root
```

## Configuration Structure

fnox uses a `fnox.toml` file with three main sections:

```toml
# Global settings
if_missing = "error"  # or "warn" or "ignore"

# Provider definitions (where secrets are stored)
[providers]
age = { type = "age", recipients = ["age1..."] }
aws-prod = { type = "aws-sm", region = "us-east-1", prefix = "myapp/" }

# Secret definitions (what secrets you need)
[secrets]
DATABASE_URL = { provider = "age", value = "..." }

# Profile overrides (environment-specific)
[profiles.production]
[profiles.production.secrets]
DATABASE_URL = { provider = "aws-prod", value = "db-url" }
```

## Profile-Based Environment Switching

fnox supports multiple approaches for environment management:

### Approach 1: Inline Profiles (Recommended)

Single `fnox.toml` with environment-specific overrides:

```toml
# Default/development configuration
[providers]
age = { type = "age", recipients = ["age1abc..."] }

[secrets]
DATABASE_URL = { provider = "age", value = "age1encrypted..." }
API_KEY = { provider = "age", value = "age1encrypted..." }

# Production profile overrides
[profiles.production]
[profiles.production.providers]
aws = { type = "aws-sm", region = "us-east-1", prefix = "prod/" }

[profiles.production.secrets]
DATABASE_URL = { provider = "aws", value = "database-url" }
API_KEY = { provider = "aws", value = "api-key" }

# Staging profile overrides
[profiles.staging]
[profiles.staging.providers]
aws = { type = "aws-sm", region = "us-east-1", prefix = "staging/" }

[profiles.staging.secrets]
DATABASE_URL = { provider = "aws", value = "database-url" }
```

Usage:
```bash
# Default (development)
fnox exec -- npm start

# Staging
fnox exec --profile staging -- npm start

# Production
fnox exec --profile production -- npm start
```

### Approach 2: Separate Profile Files

Create environment-specific files:
- `fnox.toml` (default/development)
- `fnox.production.toml` (production)
- `fnox.staging.toml` (staging)
- `fnox.local.toml` (personal overrides, add to .gitignore)

Usage:
```bash
# Set profile via environment variable
export FNOX_PROFILE=production
fnox exec -- npm start

# Or use mise to auto-set based on directory
```

## Secret Source Options

### Option 1: Age Encryption (Development/Staging)

**Best for**: Development and staging environments where team needs shared access

**Setup**:
```bash
# Generate age key (one-time per developer)
age-keygen -o ~/.config/fnox/age.key

# Share public key with team
cat ~/.config/fnox/age.key | grep "public key"
# Output: public key: age1qqq...xyz

# Add to fnox.toml (team shares this)
[providers]
age = { type = "age", recipients = [
    "age1qqq...xyz",  # Developer 1
    "age1aaa...bbb",  # Developer 2
] }

# Set secrets (encrypted for all recipients)
fnox set DATABASE_URL "postgresql://localhost:5432/dev" --provider age
fnox set API_KEY "dev-key-123" --provider age
```

**Advantages**:
- Secrets encrypted in git (safe to commit)
- No cloud dependencies
- Fast access
- Offline access

**Disadvantages**:
- Requires rotating encrypted values when team members change
- All team members have access to all secrets

### Option 2: AWS Secrets Manager (Production)

**Best for**: Production environments with strict access control

**Setup**:
```bash
# 1. Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
    --name myapp/prod/database-url \
    --secret-string "postgresql://prod.example.com:5432/prod"

aws secretsmanager create-secret \
    --name myapp/prod/api-key \
    --secret-string "prod-key-xyz"

# 2. Configure fnox.toml
[profiles.production]
[profiles.production.providers]
aws = { type = "aws-sm", region = "us-east-1", prefix = "myapp/prod/" }

[profiles.production.secrets]
DATABASE_URL = { provider = "aws", value = "database-url" }
API_KEY = { provider = "aws", value = "api-key" }

# 3. Authenticate (use IAM roles in production)
export AWS_PROFILE=production
# Or AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY

# 4. Run with production secrets
fnox exec --profile production -- npm start
```

**Advantages**:
- Centralized secret management
- IAM-based access control
- Audit logging via CloudTrail
- Secret rotation support
- No secrets in git

**Disadvantages**:
- Requires AWS account
- $0.40/month per secret
- Requires network access
- AWS vendor lock-in

### Option 3: AWS KMS (Encrypted in Git)

**Best for**: Teams wanting AWS-managed encryption keys with git storage

**Setup**:
```bash
# 1. Create KMS key
aws kms create-key --description "fnox encryption key"
# Note the KeyId from output

# 2. Configure provider
[providers]
kms = { type = "aws-kms", key_id = "arn:aws:kms:us-east-1:123456789:key/abc-123" }

# 3. Set secrets (encrypted with KMS, stored in git)
fnox set DATABASE_URL "postgresql://..." --provider kms
```

**Advantages**:
- AWS-managed encryption
- IAM-based key access control
- Secrets encrypted in git (fast access)
- Audit logging

**Disadvantages**:
- Requires AWS access to decrypt
- $1/month for KMS key
- More complex than age

### Option 4: LocalStack (Local Development)

**Best for**: Fully local development environment mimicking AWS

See "LocalStack Integration" section below for complete setup.

## LocalStack Integration

LocalStack allows you to run AWS services locally for testing, including Secrets Manager.

### Docker Compose Setup

Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"            # LocalStack Gateway
      - "4510-4559:4510-4559"  # External services
    environment:
      - SERVICES=secretsmanager,kms,s3
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - AWS_DEFAULT_REGION=us-east-1
    volumes:
      - "./localstack-data:/tmp/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
```

### Initialize LocalStack Secrets

Create `scripts/init-localstack-secrets.sh`:
```bash
#!/bin/bash
set -e

# Wait for LocalStack to be ready
echo "Waiting for LocalStack..."
until curl -s http://localhost:4566/_localstack/health | grep -q '"secretsmanager": "available"'; do
    sleep 1
done
echo "LocalStack is ready!"

# Configure AWS CLI for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT="http://localhost:4566"

# Create secrets
aws --endpoint-url=$AWS_ENDPOINT secretsmanager create-secret \
    --name myapp/local/database-url \
    --secret-string "postgresql://postgres:postgres@localhost:5432/dev"

aws --endpoint-url=$AWS_ENDPOINT secretsmanager create-secret \
    --name myapp/local/api-key \
    --secret-string "local-dev-key-123"

aws --endpoint-url=$AWS_ENDPOINT secretsmanager create-secret \
    --name myapp/local/stripe-key \
    --secret-string "sk_test_local123"

echo "LocalStack secrets initialized!"
```

### fnox Configuration for LocalStack

```toml
# fnox.toml

# Default: LocalStack for fully local development
[providers]
localstack = {
    type = "aws-sm",
    region = "us-east-1",
    prefix = "myapp/local/",
    endpoint = "http://localhost:4566"  # LocalStack endpoint
}

[secrets]
DATABASE_URL = { provider = "localstack", value = "database-url" }
API_KEY = { provider = "localstack", value = "api-key" }
STRIPE_KEY = { provider = "localstack", value = "stripe-key" }

# Staging: Age encrypted secrets
[profiles.staging]
[profiles.staging.providers]
age = { type = "age", recipients = ["age1..."] }

[profiles.staging.secrets]
DATABASE_URL = { provider = "age", value = "age1encrypted..." }

# Production: Real AWS Secrets Manager
[profiles.production]
[profiles.production.providers]
aws = { type = "aws-sm", region = "us-east-1", prefix = "myapp/prod/" }

[profiles.production.secrets]
DATABASE_URL = { provider = "aws", value = "database-url" }
API_KEY = { provider = "aws", value = "api-key" }
```

### Usage Workflow

```bash
# 1. Start LocalStack
docker-compose up -d

# 2. Initialize secrets
chmod +x scripts/init-localstack-secrets.sh
./scripts/init-localstack-secrets.sh

# 3. Use secrets (default profile = localstack)
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
fnox exec -- npm start

# 4. Switch to staging
fnox exec --profile staging -- npm start

# 5. Switch to production
fnox exec --profile production -- npm start
```

## mise Integration for Automatic Secret Loading

### Method 1: Using mise Tasks

Create `.mise.toml`:
```toml
[tools]
fnox = "latest"
node = "20"

[tasks.dev]
description = "Run development server with secrets"
run = "fnox exec -- npm run dev"

[tasks.test]
description = "Run tests with test secrets"
run = "fnox exec -- npm test"

[tasks.staging]
description = "Run with staging secrets"
run = "fnox exec --profile staging -- npm start"

[tasks.prod]
description = "Run with production secrets"
run = "fnox exec --profile production -- npm start"
```

Usage:
```bash
mise run dev      # Development with local secrets
mise run staging  # Staging environment
mise run prod     # Production environment
```

### Method 2: Auto-loading via mise env

Create `.mise.toml`:
```toml
[env]
_.source = "fnox exec -- env"  # Load all fnox secrets as env vars
```

This automatically exports all fnox secrets when you `cd` into the project directory.

**Note**: This requires mise 2024.3.0+ and experimental features.

### Method 3: Environment-Specific mise configs

```bash
# Development (default)
.mise.toml

# Staging
.mise.staging.toml

# Production
.mise.production.toml
```

Each file can specify different fnox profiles:
```toml
# .mise.staging.toml
[env]
FNOX_PROFILE = "staging"
```

Switch via:
```bash
mise use --env staging
```

## Migration from .dev.env

### Step 1: Inventory Current Secrets

```bash
# Review your current .dev.env
cat .dev.env

# Example content:
# DATABASE_URL=postgresql://...
# AWS_ACCESS_KEY_ID=AKIA...
# AWS_SECRET_ACCESS_KEY=...
# STRIPE_KEY=sk_test_...
# SENDGRID_API_KEY=SG...
```

### Step 2: Categorize Secrets

Organize by source and sensitivity:

| Secret | Source | Environment | fnox Strategy |
|--------|--------|-------------|---------------|
| DATABASE_URL | Manual | Local/Staging/Prod | Age (local), AWS SM (prod) |
| AWS_ACCESS_KEY_ID | KMS | Prod only | AWS Secrets Manager |
| STRIPE_KEY | Manual | All | Age (dev), AWS SM (prod) |
| SENDGRID_API_KEY | KMS JSON | All | Age (dev), AWS SM (prod) |

### Step 3: Initialize fnox

```bash
# Install
mise use -g fnox

# Initialize in project
cd your-project/
fnox init

# Generate age key for development
age-keygen -o ~/.config/fnox/age.key
```

### Step 4: Migrate Secrets

```bash
# Set development secrets (encrypted with age)
fnox set DATABASE_URL "$(grep DATABASE_URL .dev.env | cut -d= -f2)" --provider age
fnox set STRIPE_KEY "$(grep STRIPE_KEY .dev.env | cut -d= -f2)" --provider age

# For AWS secrets in production, create in Secrets Manager
aws secretsmanager create-secret \
    --name myapp/prod/database-url \
    --secret-string "$(grep DATABASE_URL .dev.env | cut -d= -f2)"

# Configure production profile in fnox.toml to reference AWS SM
```

### Step 5: Update Application Code

**Before** (.env loading):
```javascript
// Load .env file
require('dotenv').config({ path: '.dev.env' });

const dbUrl = process.env.DATABASE_URL;
```

**After** (fnox):
```javascript
// No changes needed! fnox exec sets environment variables
const dbUrl = process.env.DATABASE_URL;
```

Run with:
```bash
# Before
npm start  # (loaded .dev.env via dotenv)

# After
fnox exec -- npm start  # fnox sets env vars
```

### Step 6: Update .gitignore

```bash
# Add to .gitignore
echo ".dev.env" >> .gitignore
echo "fnox.local.toml" >> .gitignore
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore

# Commit fnox.toml (safe - contains only encrypted values or references)
git add fnox.toml
git commit -m "feat: migrate to fnox for secrets management"
```

### Step 7: Team Migration

```bash
# 1. Each team member installs mise + fnox
mise use -g fnox

# 2. Each member generates age key
age-keygen -o ~/.config/fnox/age.key

# 3. Collect public keys
cat ~/.config/fnox/age.key | grep "public key"

# 4. Update fnox.toml recipients
[providers]
age = { type = "age", recipients = [
    "age1user1...",
    "age1user2...",
    "age1user3...",
] }

# 5. Re-encrypt secrets for new recipients
fnox set DATABASE_URL "value" --provider age

# 6. Push updated fnox.toml
git add fnox.toml
git commit -m "feat: add team member to age recipients"
git push
```

## CI/CD Integration

### GitHub Actions

```yaml
name: CI

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # Install mise
      - uses: jdx/mise-action@v2

      # Install fnox via mise
      - run: mise use -g fnox

      # Provide age key for decryption
      - name: Setup fnox age key
        env:
          FNOX_AGE_KEY: ${{ secrets.FNOX_AGE_KEY }}
        run: |
          mkdir -p ~/.config/fnox
          echo "$FNOX_AGE_KEY" > ~/.config/fnox/age.key
          chmod 600 ~/.config/fnox/age.key

      # Run tests with secrets
      - name: Run tests
        run: fnox exec -- npm test

  deploy-staging:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/staging'
    steps:
      - uses: actions/checkout@v3
      - uses: jdx/mise-action@v2

      # AWS credentials for Secrets Manager
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_STAGING }}
          aws-region: us-east-1

      # Deploy with staging secrets
      - run: fnox exec --profile staging -- ./deploy.sh

  deploy-production:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      - uses: jdx/mise-action@v2

      # AWS credentials for production
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_PRODUCTION }}
          aws-region: us-east-1

      # Deploy with production secrets
      - run: fnox exec --profile production -- ./deploy.sh
```

**Setup GitHub Secrets**:
```bash
# Get your age private key
cat ~/.config/fnox/age.key | grep -v "public key"

# Add to GitHub:
# Settings → Secrets → Actions → New repository secret
# Name: FNOX_AGE_KEY
# Value: <paste private key>
```

### GitLab CI

```yaml
stages:
  - test
  - deploy

variables:
  MISE_VERSION: "latest"

before_script:
  - curl https://mise.run | sh
  - export PATH="$HOME/.local/bin:$PATH"
  - mise use -g fnox

test:
  stage: test
  script:
    - mkdir -p ~/.config/fnox
    - echo "$FNOX_AGE_KEY" > ~/.config/fnox/age.key
    - chmod 600 ~/.config/fnox/age.key
    - fnox exec -- npm test
  variables:
    FNOX_AGE_KEY: $FNOX_AGE_KEY  # CI/CD variable

deploy:staging:
  stage: deploy
  only:
    - staging
  before_script:
    - curl https://mise.run | sh
    - export PATH="$HOME/.local/bin:$PATH"
    - mise use -g fnox
  script:
    - fnox exec --profile staging -- ./deploy.sh
  environment:
    name: staging

deploy:production:
  stage: deploy
  only:
    - main
  before_script:
    - curl https://mise.run | sh
    - export PATH="$HOME/.local/bin:$PATH"
    - mise use -g fnox
  script:
    - fnox exec --profile production -- ./deploy.sh
  environment:
    name: production
```

## Hybrid Secret Sets: Mixing Local and Production Services

One of fnox's strengths is the ability to mix secret sources. Example use case: **local development with production S3 but local database**.

```toml
# fnox.toml

[providers]
age = { type = "age", recipients = ["age1..."] }
aws = { type = "aws-sm", region = "us-east-1", prefix = "myapp/prod/" }

[secrets]
# Local database
DATABASE_URL = {
    provider = "age",
    value = "age1encrypted...",
    description = "Local PostgreSQL"
}

# Production S3 (real AWS)
AWS_S3_BUCKET = {
    provider = "aws",
    value = "s3-bucket-name",
    description = "Production S3 bucket"
}

AWS_ACCESS_KEY_ID = {
    provider = "aws",
    value = "s3-access-key",
    description = "S3-only IAM credentials"
}

# Local SendGrid (fake SMTP)
SENDGRID_API_KEY = {
    provider = "age",
    value = "age1encrypted...",
    description = "Fake SendGrid for local testing"
}

# Profile for fully local (with LocalStack S3)
[profiles.local]
[profiles.local.providers]
localstack = { type = "aws-sm", region = "us-east-1", endpoint = "http://localhost:4566" }

[profiles.local.secrets]
AWS_S3_BUCKET = { provider = "localstack", value = "local-bucket" }
AWS_ACCESS_KEY_ID = { default = "test" }  # LocalStack default

# Profile for fully production
[profiles.production]
[profiles.production.providers]
aws = { type = "aws-sm", region = "us-east-1", prefix = "myapp/prod/" }

[profiles.production.secrets]
DATABASE_URL = { provider = "aws", value = "database-url" }
AWS_S3_BUCKET = { provider = "aws", value = "s3-bucket-name" }
SENDGRID_API_KEY = { provider = "aws", value = "sendgrid-key" }
```

Usage:
```bash
# Default: Local DB + Prod S3 + Fake SendGrid
fnox exec -- npm start

# Fully local (LocalStack S3)
fnox exec --profile local -- npm start

# Fully production
fnox exec --profile production -- npm start
```

## Best Practices

### 1. Secret Organization

```toml
[secrets]
# Group related secrets with comments
# Database
DATABASE_URL = { ... }
DATABASE_POOL_SIZE = { default = "10" }

# AWS Resources
AWS_S3_BUCKET = { ... }
AWS_REGION = { default = "us-east-1" }

# External APIs
STRIPE_KEY = { ... }
SENDGRID_API_KEY = { ... }
```

### 2. Use Descriptions

```toml
[secrets]
DATABASE_URL = {
    provider = "age",
    value = "...",
    description = "PostgreSQL connection string for primary DB"
}
```

### 3. Appropriate Defaults

```toml
[secrets]
LOG_LEVEL = { default = "info" }  # Non-sensitive, good default
AWS_REGION = { default = "us-east-1" }  # Safe default

# BUT NOT:
API_KEY = { default = "dev-key" }  # Security risk!
```

### 4. Fail Fast for Critical Secrets

```toml
[secrets]
DATABASE_URL = {
    provider = "aws",
    value = "...",
    if_missing = "error"  # Prevent app start without DB
}

OPTIONAL_FEATURE_KEY = {
    provider = "aws",
    value = "...",
    if_missing = "warn"  # App can run without this
}
```

### 5. .gitignore Strategy

```gitignore
# Commit these (safe)
fnox.toml
fnox.production.toml
fnox.staging.toml
.mise.toml

# DO NOT commit these
fnox.local.toml
.env
.env.local
.dev.env
age.key
```

### 6. Secret Rotation

```bash
# 1. Create new secret in AWS
aws secretsmanager create-secret --name myapp/prod/api-key-v2 --secret-string "new-key"

# 2. Update fnox.toml
[profiles.production.secrets]
API_KEY = { provider = "aws", value = "api-key-v2" }

# 3. Deploy new version

# 4. Delete old secret after verification
aws secretsmanager delete-secret --name myapp/prod/api-key
```

### 7. Team Onboarding Checklist

- [ ] Install mise: `curl https://mise.run | sh`
- [ ] Install fnox: `mise use -g fnox`
- [ ] Generate age key: `age-keygen -o ~/.config/fnox/age.key`
- [ ] Share public key with team
- [ ] Pull updated `fnox.toml` with your public key
- [ ] Test: `fnox exec -- npm start`
- [ ] Configure AWS credentials for production access (if needed)

## Troubleshooting

### Secret not found

```bash
# Check secret is configured
fnox list

# Check which profile is active
fnox exec -- env | grep FNOX

# Verify provider configuration
fnox provider list

# Test specific profile
fnox get DATABASE_URL --profile production
```

### AWS authentication failed

```bash
# Check AWS credentials
aws sts get-caller-identity

# Test AWS Secrets Manager access
aws secretsmanager get-secret-value --secret-id myapp/prod/database-url

# Check IAM permissions (minimum required):
# - secretsmanager:GetSecretValue
# - secretsmanager:DescribeSecret
```

### Age decryption failed

```bash
# Check age key exists
ls -la ~/.config/fnox/age.key

# Verify permissions
chmod 600 ~/.config/fnox/age.key

# Check you're in recipients list
cat fnox.toml | grep -A 10 "\\[providers\\]"
```

### LocalStack connection failed

```bash
# Check LocalStack is running
curl http://localhost:4566/_localstack/health

# Check secrets exist
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets

# Restart LocalStack
docker-compose down && docker-compose up -d
```

## Security Considerations

### What Goes in Git

✅ **Safe to commit**:
- `fnox.toml` (encrypted secrets or references)
- Age-encrypted secret values
- AWS Secrets Manager references (just names)
- Provider configurations
- Secret descriptions

❌ **NEVER commit**:
- `fnox.local.toml`
- `.env` or `.env.local`
- Age private keys
- AWS credentials
- Plaintext secrets

### Access Control Strategy

| Environment | Secret Store | Access Control |
|-------------|--------------|----------------|
| Development | Age encryption | All developers have recipients |
| Staging | Age or AWS SM | Limited to staging team |
| Production | AWS SM | IAM roles, MFA required |
| CI | Age (from secrets) | GitHub/GitLab secrets |

### Least Privilege IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789:secret:myapp/prod/*"
    },
    {
      "Effect": "Allow",
      "Action": "secretsmanager:ListSecrets",
      "Resource": "*"
    }
  ]
}
```

## Cost Analysis

### Current Approach (Manual .dev.env)

| Item | Cost |
|------|------|
| Developer time (manual downloads) | ~$500/month (5 devs × 2hr/month × $50/hr) |
| Security incidents (leaked secrets) | Variable, potentially high |
| **Total** | **~$500+/month** |

### fnox Approach

| Item | Cost |
|------|------|
| mise/fnox | Free (open source) |
| AWS Secrets Manager (20 secrets) | $8/month ($0.40/secret) |
| KMS key (optional) | $1/month |
| Developer time savings | -$500/month |
| **Total** | **~$9/month** (saves $491/month) |

## Complete Example Repository

See `examples/fnox-complete/` for a fully working example with:
- Local development with LocalStack
- Staging with age encryption
- Production with AWS Secrets Manager
- CI/CD with GitHub Actions
- Docker Compose setup
- mise integration

## Additional Resources

- **fnox documentation**: https://fnox.jdx.dev
- **mise documentation**: https://mise.jdx.dev
- **Age encryption**: https://age-encryption.org
- **AWS Secrets Manager**: https://aws.amazon.com/secrets-manager/
- **LocalStack**: https://localstack.cloud

## Summary

mise + fnox provides a modern, secure, and developer-friendly solution for secrets management:

1. ✅ **Replaces manual .dev.env downloads** with automated secret loading
2. ✅ **Supports multiple secret sources** (age, AWS SM, KMS, LocalStack)
3. ✅ **Easy environment switching** via profiles
4. ✅ **Version-controlled configuration** (without exposing secrets)
5. ✅ **Team collaboration** through shared encrypted secrets
6. ✅ **Cost-effective** (~$9/month vs $500+/month in developer time)

**Next Steps**:
1. Review the example configurations in this guide
2. Set up LocalStack for local development
3. Create fnox.toml with your secrets
4. Migrate one application as proof-of-concept
5. Roll out to entire team
