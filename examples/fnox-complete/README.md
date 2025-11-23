# fnox + mise Complete Integration Example

This directory contains a complete, production-ready example of integrating **fnox** and **mise** for secrets management, demonstrating the replacement of manual `.dev.env` file workflows.

## Quick Start

```bash
# 1. Install tools
curl https://mise.run | sh
mise use -g fnox

# 2. Start LocalStack
docker-compose up -d

# 3. Run development server with secrets
mise run dev
```

That's it! Your application now has access to secrets from LocalStack, with zero manual configuration.

## What's Included

This example demonstrates:

- ✅ **Multiple environment profiles** (local, development-age, staging, production, CI, hybrid)
- ✅ **LocalStack integration** for fully local AWS service emulation
- ✅ **Age encryption** for team secret sharing
- ✅ **AWS Secrets Manager** integration for production
- ✅ **Docker Compose** setup with all necessary services
- ✅ **mise tasks** for easy command execution
- ✅ **GitHub Actions** CI/CD pipeline
- ✅ **Migration guide** from .dev.env
- ✅ **Security best practices**

## File Structure

```
examples/fnox-complete/
├── README.md                    # This file
├── MIGRATION_GUIDE.md           # Step-by-step migration from .dev.env
├── fnox.toml                    # fnox configuration with all profiles
├── .mise.toml                   # mise configuration and tasks
├── docker-compose.yml           # LocalStack and services
├── .gitignore                   # Proper gitignore for secrets
├── scripts/
│   ├── init-localstack.sh       # Initialize LocalStack with secrets
│   ├── init-postgres.sql        # PostgreSQL initialization
│   └── deploy.sh                # Example deployment script
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions workflow
└── docs/
    ├── ARCHITECTURE.md          # Architecture overview
    ├── SECURITY.md              # Security considerations
    └── TROUBLESHOOTING.md       # Common issues and solutions
```

## Environment Profiles

This example includes 6 different environment profiles:

### 1. Default (LocalStack)

**Use case**: Fully local development with AWS service emulation

```bash
mise run dev
# or
fnox exec -- npm start
```

**Secrets source**: LocalStack (local AWS services)
- No cloud dependencies
- Perfect for offline development
- Fast startup

### 2. development-age

**Use case**: Development without Docker/LocalStack

```bash
fnox exec --profile development-age -- npm start
```

**Secrets source**: Age-encrypted (stored in git)
- No Docker required
- Shared across team
- Encrypted with team public keys

### 3. staging

**Use case**: Staging/pre-production environment

```bash
mise run staging
# or
fnox exec --profile staging -- npm start
```

**Secrets source**: AWS Secrets Manager
- Real AWS services
- Separate from production
- Team has access

### 4. production

**Use case**: Production deployment

```bash
mise run prod
# or
fnox exec --profile production -- npm start
```

**Secrets source**: AWS Secrets Manager
- Production secrets only
- Restricted IAM access
- Audit logging via CloudTrail

### 5. ci

**Use case**: CI/CD pipelines (GitHub Actions, GitLab CI)

```bash
fnox exec --profile ci -- npm test
```

**Secrets source**: Age-encrypted + defaults
- Age key from CI secrets
- Test database connections
- No production access

### 6. hybrid-prod-s3

**Use case**: Local development with production S3 (debugging)

```bash
fnox exec --profile hybrid-prod-s3 -- npm start
```

**Secrets source**: Mixed (local DB + prod AWS)
- Local database
- Production S3 (read-only)
- Useful for debugging S3 issues

## Available Tasks

Run tasks using `mise run <task-name>`:

| Task | Description |
|------|-------------|
| `setup` | Initial project setup (start LocalStack, init secrets) |
| `dev` | Start development server with LocalStack secrets |
| `dev-age` | Start development server with age-encrypted secrets |
| `test` | Run tests with CI profile |
| `staging` | Run with staging secrets (AWS) |
| `prod` | Run with production secrets (AWS) |
| `secrets-list` | List all configured secrets |
| `secrets-check` | Verify all secrets are accessible |
| `localstack-init` | Initialize LocalStack with secrets |
| `localstack-status` | Check LocalStack health |
| `localstack-stop` | Stop LocalStack |
| `localstack-clean` | Stop LocalStack and remove all data |
| `fnox-init-age` | Generate age key and display public key |
| `fnox-set-dev-secrets` | Set development secrets with age |

### Example Usage

```bash
# Initial setup
mise run setup

# Development
mise run dev                    # With LocalStack
mise run dev-age                # With age encryption

# Testing
mise run test

# Production operations (careful!)
mise run prod

# Utilities
mise run secrets-list           # See all secrets
mise run localstack-status      # Check LocalStack
mise run fnox-init-age          # Setup age encryption
```

## Secrets Configuration

### Configured Secrets

This example includes these secrets:

**Database**:
- `DATABASE_URL` - PostgreSQL connection string
- `DATABASE_POOL_MIN` - Min connection pool size
- `DATABASE_POOL_MAX` - Max connection pool size

**AWS**:
- `AWS_REGION` - AWS region
- `AWS_S3_BUCKET` - S3 bucket name
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key

**External APIs**:
- `STRIPE_SECRET_KEY` - Stripe API key
- `SENDGRID_API_KEY` - SendGrid API key

**Application**:
- `JWT_SECRET` - JWT signing secret
- `SESSION_SECRET` - Session cookie secret

**Feature Flags**:
- `ENABLE_ANALYTICS` - Enable analytics
- `ENABLE_DEBUG_LOGGING` - Enable debug logs

### Adding New Secrets

```bash
# For development (LocalStack)
# 1. Add to fnox.toml
[secrets]
NEW_SECRET = { provider = "localstack", value = "new-secret-name" }

# 2. Add to LocalStack init script
aws --endpoint-url=$ENDPOINT secretsmanager create-secret \
    --name myapp/local/new-secret-name \
    --secret-string "value"

# 3. Restart LocalStack
mise run localstack-clean
mise run setup

# For production (AWS Secrets Manager)
# 1. Create in AWS
aws secretsmanager create-secret \
    --name myapp/prod/new-secret \
    --secret-string "value"

# 2. Add to fnox.toml
[profiles.production.secrets]
NEW_SECRET = { provider = "aws", value = "new-secret" }
```

## LocalStack Services

The Docker Compose setup includes:

### LocalStack (Port 4566)
Emulates AWS services locally:
- **Secrets Manager** - Store secrets
- **KMS** - Encryption keys
- **S3** - Object storage
- **DynamoDB** - NoSQL database
- **SQS** - Message queues
- **SNS** - Pub/sub messaging

### PostgreSQL (Port 5432)
- Database: `dev`
- User: `postgres`
- Password: `postgres`

### Redis (Port 6379)
- Caching and session storage

### MailHog (Ports 1025, 8025)
- SMTP server for testing emails
- Web UI: http://localhost:8025

## Team Onboarding

### New Developer Setup

```bash
# 1. Install mise
curl https://mise.run | sh
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# 2. Clone repository
git clone <your-repo>
cd <your-repo>/examples/fnox-complete

# 3. Install fnox
mise use -g fnox

# 4. Option A: Use LocalStack (recommended)
mise run setup      # Start LocalStack and initialize
mise run dev        # Start application

# 4. Option B: Use age encryption
mise run fnox-init-age              # Generate age key
# Share public key with team lead
# Wait for team lead to update fnox.toml
git pull                            # Get updated fnox.toml
mise run fnox-set-dev-secrets       # Set secrets
mise run dev-age                    # Start application
```

### Adding Team Member to Age Recipients

Team lead:

```bash
# 1. Collect new member's public key
# (they run: cat ~/.config/fnox/age.key | grep "public key")

# 2. Add to fnox.toml
[providers]
age = {
    type = "age",
    recipients = [
        "age1existing...",
        "age1newmember...",  # ← Add here
    ]
}

# 3. Re-encrypt secrets
mise run fnox-set-dev-secrets

# 4. Commit and push
git add fnox.toml
git commit -m "feat: add new team member to age recipients"
git push
```

## CI/CD Integration

### GitHub Actions

The included workflow (`.github/workflows/ci.yml`) demonstrates:

1. **Test job** - Run tests with CI profile
2. **Build job** - Build application
3. **Deploy staging** - Deploy to staging with AWS secrets
4. **Deploy production** - Deploy to production with AWS secrets
5. **Security scan** - Check for vulnerabilities
6. **Integration tests** - Test against staging

**Setup**:

1. Add `FNOX_AGE_KEY` to GitHub Secrets:
```bash
# Get private key
cat ~/.config/fnox/age.key | grep -v "public key"

# Add to: Settings → Secrets → Actions → New repository secret
# Name: FNOX_AGE_KEY
# Value: <paste key>
```

2. Configure AWS IAM roles for OIDC:
```bash
# Add these secrets:
# - AWS_ROLE_STAGING: arn:aws:iam::123:role/github-staging
# - AWS_ROLE_PRODUCTION: arn:aws:iam::123:role/github-production
```

3. Push to trigger:
```bash
git push origin staging     # Deploys to staging
git push origin main        # Deploys to production
```

### GitLab CI

Similar setup using GitLab CI/CD variables instead of GitHub Secrets.

## Security Best Practices

### ✅ Safe to Commit

- `fnox.toml` - Contains only encrypted values or cloud references
- `.mise.toml` - No secrets
- `docker-compose.yml` - No secrets
- `scripts/init-localstack.sh` - Uses default LocalStack credentials

### ❌ Never Commit

- `fnox.local.toml` - Personal overrides
- `.env`, `.dev.env` - Old environment files
- `age.key` - Private encryption keys
- `localstack-data/` - LocalStack persistence directory

### Access Control Strategy

| Environment | Secret Store | Who Has Access | How They Authenticate |
|-------------|--------------|----------------|----------------------|
| Development | Age encryption | All developers | Age private key |
| LocalStack | LocalStack | Anyone | Default creds (test/test) |
| Staging | AWS Secrets Manager | Dev team | AWS IAM |
| Production | AWS Secrets Manager | Ops team only | AWS IAM + MFA |
| CI | Age encryption | CI system only | GitHub/GitLab secrets |

### IAM Policy (Minimum Permissions)

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
      "Resource": "arn:aws:secretsmanager:us-east-1:*:secret:myapp/prod/*"
    },
    {
      "Effect": "Allow",
      "Action": "secretsmanager:ListSecrets",
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### LocalStack not starting

```bash
# Check Docker is running
docker ps

# Check ports are available
lsof -i :4566

# View logs
docker-compose logs localstack

# Restart
docker-compose down
docker-compose up -d
```

### Secrets not found

```bash
# Verify LocalStack health
curl http://localhost:4566/_localstack/health

# List secrets
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets

# Re-initialize
mise run localstack-init
```

### Age decryption failed

```bash
# Check age key exists
ls -la ~/.config/fnox/age.key

# Check permissions
chmod 600 ~/.config/fnox/age.key

# Verify you're in recipients
cat fnox.toml | grep -A 10 recipients
```

### AWS authentication failed

```bash
# Check credentials
aws sts get-caller-identity

# Test Secrets Manager access
aws secretsmanager list-secrets

# Check IAM permissions
aws iam get-user
```

For more issues, see `docs/TROUBLESHOOTING.md`

## Cost Analysis

### Running Costs

| Component | Cost |
|-----------|------|
| LocalStack (local) | Free |
| mise (open source) | Free |
| fnox (open source) | Free |
| Age encryption (local) | Free |
| AWS Secrets Manager (20 secrets) | $8/month |
| AWS KMS (1 key) | $1/month |
| **Total AWS costs** | **~$9/month** |

### Developer Time Savings

| Activity | Before | After | Savings |
|----------|--------|-------|---------|
| Initial setup | 2 hours | 15 minutes | 1.75 hours |
| Adding new developer | 1 hour | 10 minutes | 50 minutes |
| Secret updates | 30 min/month | 5 min/month | 25 min/month |
| Environment switching | Manual, error-prone | One command | Significant |

**ROI**: At $50/hr developer rate, saves ~$500/month for a 5-person team.

## Advanced Usage

### Custom Profiles

Create custom profiles for specific scenarios:

```toml
# Local development with staging database
[profiles.local-staging-db]
[profiles.local-staging-db.secrets]
DATABASE_URL = { provider = "aws-staging", value = "database-url" }
# All other secrets from local/default
```

Use with:
```bash
fnox exec --profile local-staging-db -- npm start
```

### Secret Rotation

```bash
# 1. Create new secret version in AWS
aws secretsmanager put-secret-value \
    --secret-id myapp/prod/api-key \
    --secret-string "new-value"

# 2. Deploy new application version
# (fnox automatically gets latest version)

# 3. Verify rotation
fnox get API_KEY --profile production
```

### Multi-Region Setup

```toml
[profiles.production-us-east]
[profiles.production-us-east.providers]
aws = { type = "aws-sm", region = "us-east-1", prefix = "myapp/prod/" }

[profiles.production-eu-west]
[profiles.production-eu-west.providers]
aws = { type = "aws-sm", region = "eu-west-1", prefix = "myapp/prod/" }
```

## Related Documentation

- **Main Integration Guide**: `../../MISE_FNOX_INTEGRATION.md`
- **Migration Guide**: `MIGRATION_GUIDE.md`
- **fnox Documentation**: https://fnox.jdx.dev
- **mise Documentation**: https://mise.jdx.dev
- **LocalStack Documentation**: https://docs.localstack.cloud
- **Age Encryption**: https://age-encryption.org

## Support

For issues or questions:

1. Check `docs/TROUBLESHOOTING.md`
2. Review GitHub issues: https://github.com/jdx/fnox/issues
3. Ask in mise Discord: https://discord.gg/mise

## Contributing

Improvements welcome! Please:

1. Test changes with all profiles
2. Update documentation
3. Ensure no secrets in commits
4. Follow existing patterns

## License

This example is provided as-is for demonstration purposes. Adapt to your needs.

## Acknowledgments

- **fnox** by @jdx - https://github.com/jdx/fnox
- **mise** by @jdx - https://github.com/jdx/mise
- **LocalStack** - https://localstack.cloud
- **Age encryption** - https://age-encryption.org
