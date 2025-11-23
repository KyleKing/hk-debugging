# Migration Guide: From .dev.env to fnox

This guide walks you through migrating from manual `.dev.env` file management to automated secrets management with **fnox**.

## Overview

**Current State**:
- Developers manually download `.dev.env` file
- File contains mix of KMS-encrypted secrets and plaintext values
- Risk of committing secrets to git
- No easy way to switch between environments
- Manual updates required when secrets change

**Target State**:
- Secrets automatically loaded from secure sources
- Age-encrypted development secrets (safe in git)
- AWS Secrets Manager for production
- Easy environment switching via profiles
- Team shares configuration without exposing secrets

## Prerequisites

Before starting the migration:

- [ ] Install mise: `curl https://mise.run | sh`
- [ ] Install fnox: `mise use -g fnox`
- [ ] Install age (for encryption): `brew install age` or `apt install age`
- [ ] Access to existing `.dev.env` file
- [ ] AWS credentials (for production secrets)

## Migration Steps

### Step 1: Inventory Current Secrets

First, understand what secrets you currently have:

```bash
# Review your current .dev.env
cat .dev.env
```

Example `.dev.env` content:
```bash
# Database
DATABASE_URL=postgresql://localhost:5432/dev
DATABASE_POOL_SIZE=10

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=my-app-uploads

# External Services
STRIPE_SECRET_KEY=sk_test_...
SENDGRID_API_KEY=SG.xxx...
TWILIO_AUTH_TOKEN=...

# Application Secrets
JWT_SECRET=...
SESSION_SECRET=...

# Feature Flags
ENABLE_ANALYTICS=true
DEBUG_MODE=false
```

Create an inventory table:

| Secret Name | Current Source | Sensitivity | Environment | fnox Strategy |
|-------------|----------------|-------------|-------------|---------------|
| DATABASE_URL | Manual | Low | Local/Staging/Prod | LocalStack (local), AWS SM (prod) |
| AWS_ACCESS_KEY_ID | KMS | High | Prod only | AWS Secrets Manager |
| STRIPE_SECRET_KEY | Manual | High | All | Age (dev), AWS SM (prod) |
| JWT_SECRET | Manual | High | All | Age (dev), AWS SM (prod) |
| ENABLE_ANALYTICS | Manual | None | All | Default value in fnox.toml |

### Step 2: Initialize fnox

```bash
# Navigate to your project
cd your-project/

# Initialize fnox (creates fnox.toml)
fnox init

# Create examples directory structure
mkdir -p examples/fnox-complete/scripts
```

### Step 3: Set Up Age Encryption (Development)

Age encryption allows you to store encrypted secrets in git safely.

```bash
# Generate age key pair
age-keygen -o ~/.config/fnox/age.key

# Display public key (share with team)
cat ~/.config/fnox/age.key | grep "public key"
# Output: public key: age1qqpqmq5xz7...xyz

# Set permissions
chmod 600 ~/.config/fnox/age.key
```

**Important**: Keep the private key (`~/.config/fnox/age.key`) secure. Never commit it!

### Step 4: Configure fnox.toml

Create or edit `fnox.toml`:

```toml
# Global settings
if_missing = "warn"

# =============================================================================
# Providers
# =============================================================================

[providers]
# Age for development (encrypted in git)
age = {
    type = "age",
    recipients = [
        "age1qqpqmq5xz7...xyz",  # Your public key
        # Add team members' public keys here
    ]
}

# LocalStack for fully local development
localstack = {
    type = "aws-sm",
    region = "us-east-1",
    prefix = "myapp/local/",
    endpoint = "http://localhost:4566"
}

# =============================================================================
# Secrets - Default (LocalStack)
# =============================================================================

[secrets]
DATABASE_URL = {
    provider = "localstack",
    value = "database-url",
    if_missing = "error"
}

AWS_S3_BUCKET = {
    provider = "localstack",
    value = "s3-bucket-name"
}

# Non-sensitive defaults
AWS_REGION = { default = "us-east-1" }
DATABASE_POOL_SIZE = { default = "10" }

# =============================================================================
# Profile: Production
# =============================================================================

[profiles.production]
[profiles.production.providers]
aws = {
    type = "aws-sm",
    region = "us-east-1",
    prefix = "myapp/prod/"
}

[profiles.production.secrets]
DATABASE_URL = { provider = "aws", value = "database-url", if_missing = "error" }
AWS_S3_BUCKET = { provider = "aws", value = "s3-bucket-name" }
STRIPE_SECRET_KEY = { provider = "aws", value = "stripe-secret-key" }
JWT_SECRET = { provider = "aws", value = "jwt-secret" }
```

### Step 5: Migrate Secrets to fnox

#### Option A: Migrate to LocalStack (Recommended for Local Development)

1. **Set up LocalStack**:

```bash
# Use provided docker-compose.yml from examples
docker-compose up -d

# Run initialization script
bash scripts/init-localstack.sh
```

2. **Verify secrets**:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets
```

3. **Test application**:

```bash
# Run app with LocalStack secrets
fnox exec -- npm start
```

#### Option B: Migrate to Age Encryption

1. **Set secrets with age**:

```bash
# Extract values from .dev.env and encrypt them
fnox set DATABASE_URL "$(grep DATABASE_URL .dev.env | cut -d= -f2)" --provider age
fnox set STRIPE_SECRET_KEY "$(grep STRIPE_SECRET_KEY .dev.env | cut -d= -f2)" --provider age
fnox set JWT_SECRET "$(grep JWT_SECRET .dev.env | cut -d= -f2)" --provider age
fnox set SESSION_SECRET "$(grep SESSION_SECRET .dev.env | cut -d= -f2)" --provider age
```

2. **Verify fnox.toml was updated**:

```bash
cat fnox.toml
# You should see age-encrypted values like:
# value = "age1encrypted..."
```

3. **Test access**:

```bash
# List all secrets
fnox list

# Get specific secret
fnox get DATABASE_URL

# Run app with secrets
fnox exec -- npm start
```

### Step 6: Migrate Production Secrets to AWS Secrets Manager

1. **Create secrets in AWS**:

```bash
# Set your AWS profile
export AWS_PROFILE=production

# Create each secret
aws secretsmanager create-secret \
    --name myapp/prod/database-url \
    --description "Production database connection string" \
    --secret-string "$(grep DATABASE_URL .dev.env | cut -d= -f2)"

aws secretsmanager create-secret \
    --name myapp/prod/stripe-secret-key \
    --description "Stripe production secret key" \
    --secret-string "$(grep STRIPE_SECRET_KEY .dev.env | cut -d= -f2)"

aws secretsmanager create-secret \
    --name myapp/prod/jwt-secret \
    --description "JWT signing secret" \
    --secret-string "$(grep JWT_SECRET .dev.env | cut -d= -f2)"

# Continue for all production secrets...
```

2. **Verify secrets were created**:

```bash
aws secretsmanager list-secrets --query 'SecretList[?starts_with(Name, `myapp/prod/`)]'
```

3. **Test production profile**:

```bash
# Get a secret via fnox
fnox get DATABASE_URL --profile production

# Run app with production secrets (careful!)
fnox exec --profile production -- npm start
```

### Step 7: Update Application Code

**Good news**: If you're already using environment variables, you don't need to change your application code!

**Before** (using dotenv):
```javascript
// Load .env file
require('dotenv').config({ path: '.dev.env' });

const dbUrl = process.env.DATABASE_URL;
const stripeKey = process.env.STRIPE_SECRET_KEY;
```

**After** (using fnox):
```javascript
// No changes needed! fnox sets environment variables
const dbUrl = process.env.DATABASE_URL;
const stripeKey = process.env.STRIPE_SECRET_KEY;
```

**Only change**: How you run your application:

```bash
# Before
npm start  # (relied on .env loading)

# After
fnox exec -- npm start  # fnox loads secrets
```

**Optional**: Remove dotenv dependency:

```bash
npm uninstall dotenv
```

Then remove from your code:
```javascript
// Remove this line:
// require('dotenv').config();
```

### Step 8: Update .gitignore

Ensure sensitive files are not committed:

```bash
# Add to .gitignore
cat >> .gitignore <<EOF

# Old environment files (deprecated)
.dev.env
.env
.env.local
.env.*.local

# fnox local overrides (developer-specific)
fnox.local.toml

# Age private keys (NEVER commit)
age.key
*.age.key
EOF
```

**Commit the safe files**:

```bash
# These are SAFE to commit:
git add fnox.toml          # Contains only encrypted values or references
git add .mise.toml         # mise configuration
git add docker-compose.yml # LocalStack setup
git add scripts/           # Initialization scripts

# Verify no secrets are in the files
git diff --cached

# Commit
git commit -m "feat: migrate from .dev.env to fnox secrets management"
```

### Step 9: Set Up mise Integration

Create `.mise.toml` for easy task running:

```toml
[tools]
fnox = "latest"
node = "20"

[tasks.dev]
description = "Start development server"
run = "fnox exec -- npm run dev"

[tasks.test]
description = "Run tests"
run = "fnox exec --profile ci -- npm test"

[tasks.staging]
description = "Run with staging secrets"
run = "fnox exec --profile staging -- npm start"
```

Now you can run:

```bash
mise run dev      # Development
mise run test     # Tests
mise run staging  # Staging
```

### Step 10: Team Migration

Each team member needs to:

1. **Install tools**:
```bash
# Install mise
curl https://mise.run | sh

# Activate mise (add to shell)
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Install fnox
mise use -g fnox
```

2. **Generate age key**:
```bash
# Generate key
age-keygen -o ~/.config/fnox/age.key

# Share public key with team
cat ~/.config/fnox/age.key | grep "public key"
```

3. **Team lead updates fnox.toml**:
```toml
[providers]
age = {
    type = "age",
    recipients = [
        "age1qqpqmq5xz7...xyz",  # Team member 1
        "age1aabbccdd...abc",    # Team member 2  ← NEW
    ]
}
```

4. **Re-encrypt secrets for new team member**:
```bash
# Team lead re-sets secrets (now encrypted for all recipients)
fnox set DATABASE_URL "value" --provider age
fnox set STRIPE_SECRET_KEY "value" --provider age
# ... repeat for all secrets

# Commit updated fnox.toml
git add fnox.toml
git commit -m "feat: add team member to age recipients"
git push
```

5. **New team member pulls and tests**:
```bash
git pull
fnox get DATABASE_URL  # Should work!
mise run dev           # Should start app
```

### Step 11: Update CI/CD

#### GitHub Actions

Add age key to GitHub Secrets:

```bash
# Get your private key (WITHOUT the public key line)
cat ~/.config/fnox/age.key | grep -v "public key"
```

Add to GitHub:
1. Go to Settings → Secrets → Actions
2. New repository secret
3. Name: `FNOX_AGE_KEY`
4. Value: `<paste private key>`

Update workflow (`.github/workflows/ci.yml`):

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install mise
        uses: jdx/mise-action@v2

      - name: Install fnox
        run: mise use -g fnox

      - name: Setup fnox key
        env:
          FNOX_AGE_KEY: ${{ secrets.FNOX_AGE_KEY }}
        run: |
          mkdir -p ~/.config/fnox
          echo "$FNOX_AGE_KEY" > ~/.config/fnox/age.key
          chmod 600 ~/.config/fnox/age.key

      - name: Run tests
        run: fnox exec --profile ci -- npm test
```

### Step 12: Verify Migration

Create a checklist to verify everything works:

- [ ] LocalStack running: `docker ps | grep localstack`
- [ ] Secrets accessible: `fnox list`
- [ ] Development works: `mise run dev`
- [ ] Tests work: `mise run test`
- [ ] Team members can access secrets
- [ ] CI/CD pipeline passing
- [ ] No secrets in git: `git log -p | grep -i "secret"` (should show only fnox.toml changes)

### Step 13: Deprecate .dev.env

Once fnox is working for everyone:

1. **Archive the old file**:
```bash
# Move to secure location (not in git!)
mv .dev.env ~/.secure-archive/.dev.env.backup-$(date +%Y%m%d)
```

2. **Update documentation**:
- Update README with fnox setup instructions
- Remove references to `.dev.env`
- Document new onboarding process

3. **Add warning if .dev.env exists**:

Create `scripts/check-env.sh`:
```bash
#!/bin/bash
if [ -f .dev.env ]; then
    echo "⚠️  WARNING: .dev.env file found!"
    echo "   This project now uses fnox for secrets management."
    echo "   Please run: mise run dev"
    echo ""
    echo "   To migrate, see MIGRATION_GUIDE.md"
    exit 1
fi
```

Add to package.json:
```json
{
  "scripts": {
    "prestart": "bash scripts/check-env.sh",
    "start": "node src/index.js"
  }
}
```

## Rollback Plan

If you need to rollback to `.dev.env`:

1. **Restore backup**:
```bash
cp ~/.secure-archive/.dev.env.backup-* .dev.env
```

2. **Reinstall dotenv**:
```bash
npm install dotenv
```

3. **Revert code changes**:
```bash
git revert <migration-commit-hash>
```

## Common Issues

### "Secret not found" error

```bash
# Check secret is configured
fnox list

# Check provider is accessible
fnox provider list

# Verify your age key is set up
ls -la ~/.config/fnox/age.key
```

### "Permission denied" on age key

```bash
chmod 600 ~/.config/fnox/age.key
```

### LocalStack secrets not accessible

```bash
# Check LocalStack is running
docker ps | grep localstack

# Check health
curl http://localhost:4566/_localstack/health

# Re-initialize
bash scripts/init-localstack.sh
```

### Team member can't decrypt secrets

```bash
# Verify they're in the recipients list
cat fnox.toml | grep -A 10 recipients

# Re-encrypt for all recipients
fnox set SECRET_NAME "value" --provider age
```

## Cost Comparison

### Before (Manual .dev.env)

| Item | Monthly Cost |
|------|-------------|
| Developer time (manual downloads, 5 devs × 2hr/month) | ~$500 |
| Security incidents (variable) | $0-$10,000+ |
| **Total** | **$500-$10,500** |

### After (fnox)

| Item | Monthly Cost |
|------|-------------|
| AWS Secrets Manager (20 secrets × $0.40) | $8 |
| KMS key (optional) | $1 |
| mise/fnox (open source) | $0 |
| Developer time saved | -$500 |
| **Total** | **$9 (saves $491/month)** |

## Next Steps

After successful migration:

1. **Document new process** in README
2. **Train team** on fnox usage
3. **Set up secret rotation** for production
4. **Review IAM permissions** for AWS Secrets Manager
5. **Monitor costs** in AWS console
6. **Schedule quarterly** secret audit

## Support Resources

- fnox Documentation: https://fnox.jdx.dev
- mise Documentation: https://mise.jdx.dev
- Age Encryption: https://age-encryption.org
- AWS Secrets Manager: https://aws.amazon.com/secrets-manager/
- This project's examples: `examples/fnox-complete/`

## Success Metrics

Track these metrics to measure migration success:

- ✅ Time to onboard new developer (should decrease from hours to minutes)
- ✅ Number of secret-related incidents (should approach zero)
- ✅ Developer satisfaction with secrets management (survey team)
- ✅ Time spent on secret management per month (should decrease significantly)

## Conclusion

You've successfully migrated from manual `.dev.env` management to automated fnox secrets management! 🎉

**Benefits achieved**:
- ✅ No more manual secret downloads
- ✅ Secrets never in plaintext in git
- ✅ Easy environment switching
- ✅ Consistent team setup
- ✅ Cost savings (~$491/month)
- ✅ Better security posture
