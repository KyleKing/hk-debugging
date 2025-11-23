# Credential Modernization Examples

This directory contains practical examples and guides for modernizing credential management from long-lived tokens to temporary, user-specific credentials.

## Quick Start

```bash
# 1. Set up AWS SSO
aws configure sso

# 2. Sign in to 1Password
op signin

# 3. Run application with secrets
fnox exec -- python app.py
```

## What's Included

### 📘 Guides

- **[../CREDENTIAL_MODERNIZATION.md](../../CREDENTIAL_MODERNIZATION.md)** - Main integration guide
  - AWS SSO/IAM Identity Center setup
  - aioboto3 integration
  - fnox + 1Password integration
  - Automated user lifecycle (SCIM)
  - Cloud IDE comparison
  - Migration strategy

- **[USER_LIFECYCLE_RUNBOOK.md](./USER_LIFECYCLE_RUNBOOK.md)** - Operational runbook
  - Onboarding new developers (15 min)
  - Offboarding departing employees (5 min)
  - Granting/revoking access
  - Troubleshooting common issues

### 🔧 Configuration

- **[fnox.toml](./fnox.toml)** - Complete fnox configuration
  - Pulumi, Slack, GitHub, Stripe, SendGrid, Twilio credentials
  - Development, staging, production, CI profiles
  - 1Password integration for all non-AWS secrets

### 💻 Code Examples

- **[aws_sso_example.py](./aws_sso_example.py)** - aioboto3 + AWS SSO examples
  - S3, DynamoDB, SQS, SNS operations
  - Proper error handling for expired credentials
  - FastAPI integration example
  - Health check endpoints

## Architecture

```
┌──────────────────────────────────────────────────────┐
│              Credential Management Flow               │
├──────────────────────────────────────────────────────┤
│                                                       │
│  Developer → aws sso login                           │
│           → op signin                                │
│           → fnox exec -- app                         │
│                                                       │
│  ┌──────────────┐                                    │
│  │  AWS SSO     │ → Temporary AWS credentials        │
│  │  (IAM IdC)   │   (auto-refresh)                   │
│  └──────────────┘                                    │
│                                                       │
│  ┌──────────────┐                                    │
│  │  1Password   │ → Non-AWS secrets                  │
│  │  (via fnox)  │   (Pulumi, Slack, GitHub)          │
│  └──────────────┘                                    │
│                                                       │
│  ┌──────────────┐                                    │
│  │  aioboto3    │ → Uses SSO credentials             │
│  │              │   automatically                     │
│  └──────────────┘                                    │
│                                                       │
└──────────────────────────────────────────────────────┘
```

## Key Benefits

| Improvement | Before | After |
|-------------|--------|-------|
| **Onboarding time** | 2-4 hours | 15 minutes |
| **Offboarding time** | 1-2 hours | 5 minutes |
| **Credential rotation** | Yearly (manual) | Daily (automatic) |
| **Security risk** | High (long-lived) | Low (temporary) |
| **Admin time/month** | 8-10 hours | 1-2 hours |

## Prerequisites

### Required

- AWS Organization with IAM Identity Center enabled
- 1Password Business or Teams account
- Python 3.8+ (for examples)
- AWS CLI v2

### Optional

- Identity provider with SCIM (Okta, Entra ID, Google Workspace)
- GitHub organization
- Pulumi Cloud account

## Installation

### 1. AWS SSO Setup

```bash
# Configure SSO profile
aws configure sso

# Prompts:
# SSO session name: my-company
# SSO start URL: https://my-company.awsapps.com/start
# SSO region: us-east-1

# Login
aws sso login --profile my-dev

# Test
aws sts get-caller-identity --profile my-dev
```

### 2. 1Password Setup

```bash
# Install 1Password CLI
brew install 1password-cli

# Sign in
op signin

# Verify
op vault list
```

### 3. fnox Setup

```bash
# Install mise
curl https://mise.run | sh

# Install fnox
mise use -g fnox

# Verify
fnox --version
```

### 4. Python Dependencies (for examples)

```bash
pip install aioboto3 fastapi uvicorn
```

## Usage Examples

### Example 1: AWS SSO with aioboto3

```python
import aioboto3
import asyncio

async def list_buckets():
    # Automatically uses AWS SSO credentials from ~/.aws/config
    session = aioboto3.Session(profile_name='my-dev')

    async with session.client('s3') as s3:
        response = await s3.list_buckets()
        for bucket in response['Buckets']:
            print(f"Bucket: {bucket['Name']}")

asyncio.run(list_buckets())
```

Run:
```bash
# Login first
aws sso login --profile my-dev

# Run script
export AWS_PROFILE=my-dev
python aws_sso_example.py
```

### Example 2: fnox + 1Password

```bash
# List configured secrets
fnox list

# Get specific secret
fnox get PULUMI_ACCESS_TOKEN

# Run Pulumi with secrets from 1Password
fnox exec -- pulumi up

# Run with different profile
fnox exec --profile production -- pulumi up
```

### Example 3: Combined (AWS SSO + fnox + aioboto3)

```python
# app.py
import aioboto3
import os

# AWS credentials from SSO (automatic via AWS_PROFILE)
# Pulumi token from fnox + 1Password (in environment)

async def deploy_infra():
    # AWS SSO credentials
    session = aioboto3.Session(profile_name=os.getenv('AWS_PROFILE'))

    # Pulumi token (from fnox)
    pulumi_token = os.getenv('PULUMI_ACCESS_TOKEN')

    async with session.client('s3') as s3:
        # Create bucket
        await s3.create_bucket(Bucket='my-app-data')

    # Deploy with Pulumi (token already in env)
    os.system('pulumi up --yes')
```

Run:
```bash
# Login to both
aws sso login --profile my-dev
op signin

# Run via fnox (sets PULUMI_ACCESS_TOKEN)
export AWS_PROFILE=my-dev
fnox exec -- python app.py
```

## Configuration Files

### ~/.aws/config (AWS SSO)

```ini
[profile my-dev]
sso_session = my-company
sso_account_id = 123456789012
sso_role_name = DeveloperAccess
region = us-east-1
output = json

[sso-session my-company]
sso_start_url = https://my-company.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
```

### fnox.toml (Secrets Management)

```toml
[providers]
onepassword = { type = "1password" }

[secrets]
PULUMI_ACCESS_TOKEN = {
    provider = "onepassword",
    ref = "op://Development/Pulumi/access-token"
}

SLACK_WEBHOOK_URL = {
    provider = "onepassword",
    ref = "op://Development/Slack/webhook-url"
}

GITHUB_TOKEN = {
    provider = "onepassword",
    ref = "op://Development/GitHub/personal-access-token"
}
```

## Common Workflows

### Daily Development

```bash
# Morning: Login once
aws sso login --profile my-dev

# Work all day - credentials auto-refresh
fnox exec -- npm start
fnox exec -- pytest
fnox exec -- pulumi preview

# Evening: Credentials expire (no action needed)
```

### CI/CD Deployment

```yaml
# .github/workflows/deploy.yml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # OIDC, no keys!

- name: Deploy with Pulumi
  env:
    OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
  run: |
    fnox exec --profile ci -- pulumi up --yes
```

### Onboarding New Developer

```bash
# Admin (5 minutes):
# 1. Add to Okta/Entra ID → SCIM auto-syncs to AWS
# 2. Add to 1Password → Grant vault access

# New hire (10 minutes):
# 1. aws configure sso
# 2. op signin
# 3. mise use -g fnox
# 4. git clone && fnox exec -- npm start
```

### Offboarding Employee

```bash
# Admin (5 minutes):
# 1. Deactivate in Okta → SCIM auto-revokes AWS access
# 2. Remove from 1Password → Loses secret access
# 3. Remove from GitHub → Loses repo access

# Effect: Access revoked within minutes (vs hours manually)
```

## Security Features

### ✅ Temporary Credentials
- AWS SSO credentials expire after 1-12 hours
- Auto-refresh while session active
- No long-lived tokens to steal

### ✅ Per-User Audit Trail
- CloudTrail logs show individual user actions
- No shared credentials (each user has unique identity)
- Easy to track who accessed what

### ✅ Automated Revocation
- SCIM deactivates users automatically
- Offboarding removes all access in minutes
- No orphaned credentials

### ✅ MFA Enforcement
- AWS SSO supports MFA
- 1Password requires authentication
- Defense in depth

### ✅ No Credentials in Git
- No .env files with secrets
- fnox.toml contains only references
- Age-encrypted values (if used) are safe to commit

## Migration Path

### Phase 1: Pilot (Week 1-2)
- Set up AWS SSO for 2-3 developers
- Configure fnox + 1Password
- Test with non-production workloads

### Phase 2: Team Rollout (Week 3-4)
- Migrate entire engineering team
- Train on new workflow
- Revoke old long-lived tokens

### Phase 3: Automation (Week 5-6)
- Enable SCIM provisioning
- Automate onboarding/offboarding
- Document processes

### Phase 4: Optimization (Ongoing)
- Monitor usage and issues
- Refine permission sets
- Quarterly access reviews

## Troubleshooting

### "SSO session expired"

```bash
# Solution: Re-login
aws sso login --profile my-dev
```

### "fnox can't access secrets"

```bash
# Solution: Sign in to 1Password
op signin

# Verify
op vault list
```

### "User can't access AWS"

```bash
# Check user exists
aws sso-admin list-users --instance-arn arn:aws:sso:::instance/...

# Check group membership
aws sso-admin list-group-memberships --instance-arn ... --user-id ...

# Check account assignments
aws sso-admin list-account-assignments --instance-arn ... --account-id ...
```

See [USER_LIFECYCLE_RUNBOOK.md](./USER_LIFECYCLE_RUNBOOK.md) for detailed troubleshooting.

## Performance Considerations

### Session Duration
- **Default**: 8 hours
- **Recommended**: 8-12 hours for development
- **Production**: 1-4 hours for higher security

### Credential Refresh
- **Automatic**: aioboto3 refreshes seamlessly
- **Manual**: Run `aws sso login` when expired
- **CI/CD**: Use OIDC (no manual refresh needed)

### 1Password Performance
- **Local cache**: Secrets cached for offline access
- **API calls**: fnox minimizes calls to 1Password
- **Concurrent access**: No rate limiting for team accounts

## Best Practices

### ✅ Use Groups, Not Individual Assignments
```bash
# Good: Assign permission set to group
aws sso-admin create-account-assignment --principal-type GROUP

# Bad: Assign to each user individually
aws sso-admin create-account-assignment --principal-type USER
```

### ✅ Principle of Least Privilege
```toml
# Good: Separate vaults by environment
ref = "op://Development/..."  # Dev secrets
ref = "op://Production/..."   # Prod secrets

# Bad: Everyone has access to everything
```

### ✅ Regular Access Reviews
```bash
# Quarterly: Review who has access
aws sso-admin list-account-assignments ...

# Remove stale access
```

### ✅ Monitor CloudTrail
```bash
# Alert on suspicious activity
# - Failed authentication attempts
# - Access from unusual IPs
# - Privilege escalation attempts
```

## Cost Analysis

### Monthly Costs

| Item | Cost |
|------|------|
| AWS IAM Identity Center | Free |
| 1Password Teams (5 users) | $20/month ($4/user) |
| CloudTrail (basic) | Free |
| **Total** | **~$20/month** |

### Time Savings

| Task | Before | After | Savings/year |
|------|--------|-------|--------------|
| Onboarding (12 devs/year) | 48 hours | 3 hours | 45 hours |
| Offboarding (4 devs/year) | 8 hours | 0.5 hours | 7.5 hours |
| Access changes (24/year) | 24 hours | 1 hour | 23 hours |
| **Total** | **80 hours** | **4.5 hours** | **75.5 hours** |

**ROI**: At $100/hr admin rate = **$7,550/year savings** for **$240/year cost**.

## Additional Resources

### Documentation
- [AWS IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [fnox Documentation](https://fnox.jdx.dev/)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [aioboto3](https://github.com/terrycain/aioboto3)

### Community
- [AWS SSO + boto3 on Stack Overflow](https://stackoverflow.com/questions/tagged/aws-sso)
- [fnox Discussion](https://github.com/jdx/mise/discussions/6779)

## Support

For issues or questions:
1. Check [USER_LIFECYCLE_RUNBOOK.md](./USER_LIFECYCLE_RUNBOOK.md) troubleshooting section
2. Review [CREDENTIAL_MODERNIZATION.md](../../CREDENTIAL_MODERNIZATION.md)
3. Consult official documentation links above

## Summary

This credential modernization approach provides:

✅ **Security**: Temporary credentials, MFA, per-user audit
✅ **Automation**: SCIM provisioning, auto-refresh, instant revocation
✅ **Developer Experience**: One-time setup, seamless workflow
✅ **Cost Effective**: $20/month vs $500/month in admin time
✅ **aioboto3 Compatible**: Zero code changes needed

**Result**: 90% reduction in credential management overhead with significantly improved security posture.
