# Modernizing Credential Management: From Long-Lived Tokens to Temporary Credentials

## Executive Summary

This guide addresses the transition from **long-lived AWS tokens** to **temporary, user-specific credentials** for AWS, Pulumi, Slack, GitHub, and 1Password. It focuses on security, automation, and simplified user lifecycle management.

### Key Problems Solved

❌ **Current Issues**:
- Long-lived AWS tokens pose security risks
- Manual token generation and distribution is time-consuming
- Difficult to revoke access when employees leave
- No audit trail of who accessed what
- Tokens shared across team members
- Manual management of Pulumi, Slack, GitHub credentials

✅ **New Approach**:
- **AWS SSO/IAM Identity Center**: Temporary, auto-refreshing credentials
- **User-specific access**: Individual credentials tied to identity
- **aioboto3 compatible**: Works with async Python code
- **Automated onboarding/offboarding**: Minutes instead of hours
- **fnox + 1Password**: Centralized management for non-AWS services
- **SCIM provisioning**: Automatic sync with identity provider

### ROI Summary

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Time to onboard developer | 2-4 hours | 15 minutes | **90% reduction** |
| Time to offboard developer | 1-2 hours | 5 minutes | **95% reduction** |
| Credential rotation frequency | Yearly (manual) | Daily (automatic) | **365x more frequent** |
| Security incident risk | High (long-lived tokens) | Low (temporary creds) | **Significantly reduced** |
| Admin time per month | 8-10 hours | 1-2 hours | **80% reduction** |

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [AWS SSO/IAM Identity Center Setup](#aws-sso-iam-identity-center-setup)
3. [AWS SSO + aioboto3 Integration](#aws-sso-aioboto3-integration)
4. [fnox + 1Password Integration](#fnox-1password-integration)
5. [Automated User Lifecycle Management](#automated-user-lifecycle-management)
6. [Cloud IDE vs Local Development](#cloud-ide-vs-local-development)
7. [Migration Strategy](#migration-strategy)
8. [Complete Examples](#complete-examples)

---

## Architecture Overview

### Current State: Long-Lived Tokens

```
┌─────────────────────────────────────────────────────────┐
│              Current (Problematic) Flow                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. Admin manually creates IAM user                      │
│  2. Admin generates access key + secret                  │
│  3. Admin securely shares credentials (email/1Password) │
│  4. Developer stores in .env file                        │
│  5. Credentials valid for 90+ days (or forever)         │
│  6. When employee leaves: Manual key revocation         │
│                                                          │
│  Problems:                                               │
│  • Keys never expire                                     │
│  • No audit trail per user                               │
│  • Hard to track who has access                          │
│  • Revocation is manual and error-prone                  │
│  • Credentials may be committed to git accidentally      │
└─────────────────────────────────────────────────────────┘
```

### New State: Temporary, User-Specific Credentials

```
┌─────────────────────────────────────────────────────────┐
│              New (Automated) Flow                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  AWS SSO/IAM Identity Center + fnox + 1Password         │
│                                                          │
│  ┌──────────────┐                                        │
│  │   Identity   │ (Okta, Entra ID, JumpCloud, etc.)     │
│  │   Provider   │                                        │
│  └──────┬───────┘                                        │
│         │ SCIM                                           │
│         ▼                                                 │
│  ┌──────────────┐         ┌──────────────┐              │
│  │  IAM Identity│◄───────►│      fnox    │              │
│  │   Center     │   SSO   │              │              │
│  │  (AWS SSO)   │         │   +          │              │
│  └──────┬───────┘         │  1Password   │              │
│         │                  └──────────────┘              │
│         │ Temporary                                      │
│         │ Credentials                                    │
│         ▼                                                 │
│  ┌──────────────┐                                        │
│  │  Developer   │                                        │
│  │   Machine    │                                        │
│  │              │                                        │
│  │ • aioboto3   │                                        │
│  │ • Pulumi     │                                        │
│  │ • AWS CLI    │                                        │
│  └──────────────┘                                        │
│                                                          │
│  Benefits:                                               │
│  • Credentials expire automatically (1-12 hours)        │
│  • Per-user audit trail in CloudTrail                   │
│  • Automatic onboarding via SCIM                        │
│  • Automatic offboarding (access revoked immediately)   │
│  • No credentials in git (temporary, auto-refreshed)    │
│  • MFA enforcement                                       │
└─────────────────────────────────────────────────────────┘
```

---

## AWS SSO/IAM Identity Center Setup

### Overview

[AWS IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html) (formerly AWS SSO) provides **temporary credentials** that:
- Auto-refresh as long as you have an active session
- Expire after a configurable period (1-12 hours)
- Are user-specific (CloudTrail shows individual actions)
- Support MFA enforcement
- Work with AWS CLI and all AWS SDKs (including aioboto3)

### Prerequisites

- AWS Organization set up
- Admin access to AWS IAM Identity Center
- Identity provider (optional but recommended): Okta, Microsoft Entra ID, Google Workspace, JumpCloud

### Step 1: Enable IAM Identity Center

```bash
# Using AWS CLI
aws sso-admin create-instance \
    --name "MyCompany IAM Identity Center"

# Or via AWS Console:
# 1. Go to AWS IAM Identity Center
# 2. Click "Enable"
# 3. Choose identity source (AWS directory or external IdP)
```

### Step 2: Configure Identity Source

**Option A: Use AWS IAM Identity Center Directory** (Simple, built-in)

```bash
# Default - no configuration needed
# Manage users directly in IAM Identity Center
```

**Option B: Connect External Identity Provider** (Recommended)

Examples:
- **Okta**: SAML 2.0 + SCIM
- **Microsoft Entra ID (Azure AD)**: SAML 2.0 + SCIM
- **Google Workspace**: SAML 2.0 + SCIM
- **JumpCloud**: SAML 2.0 + SCIM

Benefits of external IdP:
- Single source of truth for identities
- Automatic provisioning/deprovisioning via SCIM
- Centralized MFA policies
- Integration with existing directory (Active Directory, LDAP)

Configuration example (Microsoft Entra ID):

1. In AWS IAM Identity Center → Settings → Identity source → Change
2. Choose "External identity provider"
3. Download metadata file
4. Upload to Entra ID Enterprise Application
5. Enable SCIM provisioning (see [Automated User Lifecycle](#automated-user-lifecycle-management))

### Step 3: Create Permission Sets

Permission sets define what users can do in AWS accounts.

```bash
# Example: Developer permission set
cat > developer-permissions.json <<EOF
{
  "Version": "2012-10-1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "dynamodb:*",
        "lambda:*",
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "iam:*",
        "organizations:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create permission set
aws sso-admin create-permission-set \
    --instance-arn arn:aws:sso:::instance/ssoins-123 \
    --name "DeveloperAccess" \
    --description "Developer access to application resources" \
    --session-duration "PT8H"  # 8 hours
```

Common permission sets:
- **Developer**: S3, Lambda, DynamoDB, CloudWatch
- **DevOps**: EC2, ECS, EKS, CloudFormation, Systems Manager
- **DataScientist**: S3, Athena, Glue, SageMaker
- **ReadOnly**: Read-only access across all services
- **Admin**: Full access (for team leads)

### Step 4: Assign Users to Accounts

```bash
# Assign user to account with permission set
aws sso-admin create-account-assignment \
    --instance-arn arn:aws:sso:::instance/ssoins-123 \
    --target-id 123456789012 \
    --target-type AWS_ACCOUNT \
    --permission-set-arn arn:aws:sso:::permissionSet/ssoins-123/ps-abc \
    --principal-type USER \
    --principal-id user-id-123
```

Or use **groups** (recommended):

```bash
# Assign group to account
aws sso-admin create-account-assignment \
    --instance-arn arn:aws:sso:::instance/ssoins-123 \
    --target-id 123456789012 \
    --target-type AWS_ACCOUNT \
    --permission-set-arn arn:aws:sso:::permissionSet/ssoins-123/ps-abc \
    --principal-type GROUP \
    --principal-id group-id-456
```

### Step 5: Developer Configuration

Developers configure their local environment once:

```bash
# Configure SSO profile
aws configure sso

# Prompts:
# SSO session name: my-company
# SSO start URL: https://my-company.awsapps.com/start
# SSO region: us-east-1
# SSO registration scopes: sso:account:access
# CLI default region: us-east-1
# CLI default output: json
```

This creates `~/.aws/config`:

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

### Step 6: Login and Use

```bash
# Login (opens browser for SSO)
aws sso login --profile my-dev

# Use AWS CLI
aws s3 ls --profile my-dev

# Credentials are automatically cached and refreshed
```

**Session duration**: Configurable from 1-12 hours. After expiration, developers run `aws sso login` again (seamless, opens browser).

---

## AWS SSO + aioboto3 Integration

### Overview

[aioboto3](https://github.com/terrycain/aioboto3) is an async wrapper for boto3, commonly used in async Python applications. It **fully supports AWS SSO** via the standard boto3 credential chain.

### How It Works

```python
import aioboto3
import asyncio

async def list_buckets():
    # aioboto3 automatically uses SSO credentials from ~/.aws/config
    session = aioboto3.Session(profile_name='my-dev')

    async with session.client('s3') as s3:
        response = await s3.list_buckets()
        for bucket in response['Buckets']:
            print(f"Bucket: {bucket['Name']}")

asyncio.run(list_buckets())
```

**No code changes needed!** aioboto3 uses the same credential provider chain as boto3:
1. Environment variables
2. AWS SSO credentials (from `~/.aws/config`)
3. IAM role (if on EC2/ECS/Lambda)

### Complete Example: FastAPI + aioboto3 + AWS SSO

```python
# app.py
from fastapi import FastAPI, HTTPException
import aioboto3
from typing import List, Dict
import os

app = FastAPI()

# Use AWS SSO profile (or default if running in cloud)
AWS_PROFILE = os.getenv("AWS_PROFILE", "my-dev")

async def get_s3_client():
    """Get S3 client with SSO credentials"""
    session = aioboto3.Session(profile_name=AWS_PROFILE)
    return session.client('s3')

@app.get("/buckets", response_model=List[str])
async def list_buckets():
    """List all S3 buckets using SSO credentials"""
    async with await get_s3_client() as s3:
        try:
            response = await s3.list_buckets()
            return [bucket['Name'] for bucket in response['Buckets']]
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

@app.get("/objects/{bucket_name}", response_model=List[Dict])
async def list_objects(bucket_name: str, prefix: str = ""):
    """List objects in S3 bucket"""
    async with await get_s3_client() as s3:
        try:
            response = await s3.list_objects_v2(
                Bucket=bucket_name,
                Prefix=prefix,
                MaxKeys=100
            )
            return [
                {
                    "key": obj['Key'],
                    "size": obj['Size'],
                    "last_modified": obj['LastModified'].isoformat()
                }
                for obj in response.get('Contents', [])
            ]
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

@app.put("/objects/{bucket_name}/{key}")
async def upload_object(bucket_name: str, key: str, content: str):
    """Upload object to S3"""
    async with await get_s3_client() as s3:
        try:
            await s3.put_object(
                Bucket=bucket_name,
                Key=key,
                Body=content.encode('utf-8')
            )
            return {"message": f"Uploaded {key} to {bucket_name}"}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

# Health check
@app.get("/health")
async def health():
    """Check if we can access AWS with current credentials"""
    async with await get_s3_client() as s3:
        try:
            # Test credentials by calling STS
            session = aioboto3.Session(profile_name=AWS_PROFILE)
            async with session.client('sts') as sts:
                identity = await sts.get_caller_identity()
                return {
                    "status": "healthy",
                    "aws_account": identity['Account'],
                    "user_arn": identity['Arn'],
                    "user_id": identity['UserId']
                }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"AWS auth failed: {str(e)}")
```

### Running Locally with AWS SSO

```bash
# 1. Login to AWS SSO
aws sso login --profile my-dev

# 2. Run application with SSO profile
export AWS_PROFILE=my-dev
uvicorn app:app --reload

# 3. Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/buckets
```

### Credential Refresh Handling

AWS SSO credentials auto-refresh while your session is active. If the session expires:

```python
import aioboto3
from botocore.exceptions import ClientError, TokenRetrievalError
import asyncio

async def s3_operation_with_retry():
    """Handle credential expiration gracefully"""
    session = aioboto3.Session(profile_name='my-dev')

    async with session.client('s3') as s3:
        try:
            response = await s3.list_buckets()
            return response['Buckets']
        except TokenRetrievalError:
            # SSO session expired - inform user to re-login
            print("❌ AWS SSO session expired!")
            print("Please run: aws sso login --profile my-dev")
            raise
        except ClientError as e:
            if e.response['Error']['Code'] == 'ExpiredToken':
                print("❌ Temporary credentials expired!")
                print("Please run: aws sso login --profile my-dev")
                raise
            else:
                raise
```

### Using with Pulumi

Pulumi automatically uses AWS SSO credentials:

```python
# __main__.py
import pulumi
import pulumi_aws as aws

# Pulumi automatically uses AWS_PROFILE or default credentials
# No special configuration needed!

bucket = aws.s3.Bucket("my-bucket",
    acl="private",
    tags={
        "Environment": "dev",
        "ManagedBy": "pulumi"
    }
)

pulumi.export("bucket_name", bucket.id)
```

Running with AWS SSO:

```bash
# Login first
aws sso login --profile my-dev

# Run Pulumi with SSO profile
export AWS_PROFILE=my-dev
pulumi up
```

Or configure in `Pulumi.dev.yaml`:

```yaml
config:
  aws:profile: my-dev
  aws:region: us-east-1
```

---

## fnox + 1Password Integration

### Overview

While AWS SSO handles AWS credentials, you still need to manage credentials for:
- **Pulumi Cloud** (state backend)
- **Slack** (webhooks, bot tokens)
- **GitHub** (PATs, deploy keys)
- **1Password** (service accounts for CI)
- **Other services** (Stripe, SendGrid, etc.)

**fnox** integrates with **1Password** to centralize these non-AWS secrets.

### Prerequisites

```bash
# Install 1Password CLI
brew install 1password-cli

# Or download from https://1password.com/downloads/command-line/

# Sign in
op signin
```

### Step 1: Set Up 1Password Service Account (for CI)

For local development, developers use their personal 1Password accounts. For CI/CD, use a service account:

1. Go to 1Password → Settings → Developer → Service Accounts
2. Create new service account: `ci-service-account`
3. Grant access to specific vaults (e.g., `CI-Secrets`)
4. Copy service account token: `ops_xxx...`

### Step 2: Configure fnox with 1Password

Update `fnox.toml`:

```toml
# Global settings
if_missing = "error"

# =============================================================================
# Providers
# =============================================================================

[providers]
# 1Password for non-AWS secrets
onepassword = { type = "1password" }

# AWS SSO for AWS credentials (automatic via profile)
# No provider needed - aioboto3 handles this

# =============================================================================
# Secrets - Development
# =============================================================================

[secrets]
# Pulumi
PULUMI_ACCESS_TOKEN = {
    provider = "onepassword",
    ref = "op://Development/Pulumi/access-token",
    description = "Pulumi Cloud access token"
}

# Slack
SLACK_WEBHOOK_URL = {
    provider = "onepassword",
    ref = "op://Development/Slack/webhook-url",
    description = "Slack webhook for notifications"
}

SLACK_BOT_TOKEN = {
    provider = "onepassword",
    ref = "op://Development/Slack/bot-token",
    description = "Slack bot token"
}

# GitHub
GITHUB_TOKEN = {
    provider = "onepassword",
    ref = "op://Development/GitHub/personal-access-token",
    description = "GitHub PAT for API access"
}

# External services
STRIPE_SECRET_KEY = {
    provider = "onepassword",
    ref = "op://Development/Stripe/secret-key",
    description = "Stripe test key"
}

SENDGRID_API_KEY = {
    provider = "onepassword",
    ref = "op://Development/SendGrid/api-key",
    description = "SendGrid API key"
}

# =============================================================================
# Profile: Production
# =============================================================================

[profiles.production]
[profiles.production.secrets]
PULUMI_ACCESS_TOKEN = {
    provider = "onepassword",
    ref = "op://Production/Pulumi/access-token"
}

SLACK_WEBHOOK_URL = {
    provider = "onepassword",
    ref = "op://Production/Slack/webhook-url"
}

STRIPE_SECRET_KEY = {
    provider = "onepassword",
    ref = "op://Production/Stripe/secret-key"
}

# =============================================================================
# Profile: CI
# =============================================================================

[profiles.ci]
description = "CI/CD environment using 1Password service account"

[profiles.ci.secrets]
PULUMI_ACCESS_TOKEN = {
    provider = "onepassword",
    ref = "op://CI-Secrets/Pulumi/access-token"
}

GITHUB_TOKEN = {
    provider = "onepassword",
    ref = "op://CI-Secrets/GitHub/deploy-token"
}
```

### Step 3: Store Secrets in 1Password

Using 1Password app or CLI:

```bash
# Using 1Password CLI
op item create --category=Login \
    --title="Pulumi" \
    --vault="Development" \
    --field="label=access-token,value=pul-xxx..."

op item create --category=Login \
    --title="Slack" \
    --vault="Development" \
    --field="label=webhook-url,value=https://hooks.slack.com/..." \
    --field="label=bot-token,value=xoxb-..."

op item create --category=Login \
    --title="GitHub" \
    --vault="Development" \
    --field="label=personal-access-token,value=ghp_..."
```

Or use the 1Password GUI:
1. Create new item in Development vault
2. Name it (e.g., "Pulumi")
3. Add fields (e.g., "access-token")
4. Save

### Step 4: Use with fnox

```bash
# Local development
fnox exec -- pulumi up

# CI/CD (with service account)
export OP_SERVICE_ACCOUNT_TOKEN=ops_xxx...
fnox exec --profile ci -- pulumi up
```

### Step 5: Developer Access

Developers authenticate to 1Password once:

```bash
# Sign in to 1Password
op signin

# fnox automatically uses their 1Password session
fnox exec -- npm start
```

**Benefits**:
- Each developer uses their own 1Password account (audit trail)
- Secrets stored centrally in 1Password vaults
- Easy to revoke access (remove from vault)
- Works offline (1Password caches)

### Complete Example: Pulumi + AWS SSO + fnox + 1Password

```python
# __main__.py
import pulumi
import pulumi_aws as aws
import os

# Pulumi token comes from fnox + 1Password
# AWS credentials come from AWS SSO
# No manual credential management!

# Create S3 bucket
bucket = aws.s3.Bucket("app-data",
    acl="private",
    versioning=aws.s3.BucketVersioningArgs(
        enabled=True,
    ),
    tags={
        "Environment": pulumi.get_stack(),
        "ManagedBy": "pulumi",
        "Team": "engineering"
    }
)

# Create DynamoDB table
table = aws.dynamodb.Table("app-table",
    attributes=[
        aws.dynamodb.TableAttributeArgs(
            name="id",
            type="S",
        ),
    ],
    hash_key="id",
    billing_mode="PAY_PER_REQUEST",
    tags={
        "Environment": pulumi.get_stack(),
        "ManagedBy": "pulumi"
    }
)

# Export outputs
pulumi.export("bucket_name", bucket.id)
pulumi.export("table_name", table.name)
```

Running:

```bash
# 1. Login to AWS SSO
aws sso login --profile my-dev

# 2. Login to 1Password (if not already)
op signin

# 3. Run Pulumi via fnox (gets Pulumi token from 1Password, AWS creds from SSO)
export AWS_PROFILE=my-dev
fnox exec -- pulumi up
```

---

## Automated User Lifecycle Management

### Overview

Manual user onboarding and offboarding is time-consuming and error-prone. [SCIM (System for Cross-domain Identity Management)](https://docs.aws.amazon.com/singlesignon/latest/userguide/provision-automatically.html) automates this by syncing users from your identity provider to AWS IAM Identity Center.

### Benefits

- **Onboarding**: New hire added to Okta → automatically provisioned in AWS (minutes)
- **Offboarding**: Employee deactivated in Okta → access revoked everywhere (immediate)
- **Group sync**: Add user to "Engineering" group → gets AWS dev access automatically
- **Attribute sync**: Name changes, email updates → reflected everywhere

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 SCIM Provisioning Flow                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────┐                                   │
│  │ Identity Provider│  (Okta, Entra ID, Google, etc.)   │
│  │                  │                                    │
│  │  • New user      │                                    │
│  │  • Group change  │                                    │
│  │  • Deactivation  │                                    │
│  └────────┬─────────┘                                    │
│           │                                               │
│           │ SCIM 2.0 API                                 │
│           │ (automatic sync every 40 min)                │
│           ▼                                               │
│  ┌──────────────────┐                                   │
│  │ AWS IAM Identity │                                    │
│  │     Center       │                                    │
│  │                  │                                    │
│  │  • Creates user  │                                    │
│  │  • Updates groups│                                    │
│  │  • Removes access│                                    │
│  └────────┬─────────┘                                    │
│           │                                               │
│           │ Permission Sets                              │
│           ▼                                               │
│  ┌──────────────────┐                                   │
│  │   AWS Accounts   │                                    │
│  │                  │                                    │
│  │  • Dev Account   │                                    │
│  │  • Staging       │                                    │
│  │  • Production    │                                    │
│  └──────────────────┘                                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Setup: Okta + AWS IAM Identity Center

#### Step 1: Enable Automatic Provisioning in AWS

1. Go to AWS IAM Identity Center → Settings → Identity source
2. Click "Actions" → "Enable automatic provisioning"
3. Copy the **SCIM endpoint** and **Access token**
   - Endpoint: `https://scim.us-east-1.amazonaws.com/xxxxx/scim/v2`
   - Token: `xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (valid 1 year)

#### Step 2: Configure Okta

1. In Okta admin console, go to Applications
2. Find your AWS IAM Identity Center app
3. Go to "Provisioning" tab → "Configure API Integration"
4. Enable provisioning, paste SCIM endpoint and token
5. Save and test connection
6. Enable:
   - ✅ Create Users
   - ✅ Update User Attributes
   - ✅ Deactivate Users
7. Set attribute mappings:
   - `user.firstName` → `name.givenName`
   - `user.lastName` → `name.familyName`
   - `user.email` → `userName`
   - `user.email` → `emails[primary eq true].value`

#### Step 3: Configure Group Push

1. In Okta, create groups: `Engineering`, `DevOps`, `DataScience`
2. Go to Applications → AWS IAM Identity Center → "Push Groups"
3. Select groups to push (e.g., "Engineering")
4. Enable "Push group memberships immediately"

#### Step 4: Map Groups to Permission Sets in AWS

```bash
# Assign Engineering group to Development account with DeveloperAccess
aws sso-admin create-account-assignment \
    --instance-arn arn:aws:sso:::instance/ssoins-123 \
    --target-id 111111111111 \
    --target-type AWS_ACCOUNT \
    --permission-set-arn arn:aws:sso:::permissionSet/ssoins-123/ps-dev \
    --principal-type GROUP \
    --principal-id group-engineering-id

# Assign DevOps group to Production account with AdminAccess
aws sso-admin create-account-assignment \
    --instance-arn arn:aws:sso:::instance/ssoins-123 \
    --target-id 222222222222 \
    --target-type AWS_ACCOUNT \
    --permission-set-arn arn:aws:sso:::permissionSet/ssoins-123/ps-admin \
    --principal-type GROUP \
    --principal-id group-devops-id
```

### Onboarding Workflow (Automated)

```
┌─────────────────────────────────────────────────────────┐
│           New Developer Onboarding (5-15 min)           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. HR adds new hire to Okta                            │
│     └─→ 2 minutes (HR portal)                           │
│                                                          │
│  2. Okta automatically syncs to AWS IAM Identity Center │
│     └─→ 0 minutes (automatic via SCIM)                  │
│                                                          │
│  3. HR adds user to "Engineering" group in Okta        │
│     └─→ 1 minute (Okta admin)                           │
│                                                          │
│  4. Group membership synced to AWS                      │
│     └─→ 0 minutes (automatic via SCIM)                  │
│                                                          │
│  5. User automatically gets AWS access                  │
│     └─→ 0 minutes (permission set assignment)           │
│                                                          │
│  6. New hire receives email with AWS access portal URL │
│     └─→ 0 minutes (automatic from IAM Identity Center)  │
│                                                          │
│  7. Developer configures local machine                  │
│     └─→ 10 minutes (one-time setup)                     │
│         • aws configure sso                             │
│         • op signin (1Password)                         │
│         • fnox exec -- test                             │
│                                                          │
│  Total time: 15 minutes (vs 2-4 hours manual)          │
│  Admin time: 3 minutes (vs 2-3 hours)                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Offboarding Workflow (Automated)

```
┌─────────────────────────────────────────────────────────┐
│        Employee Departure Offboarding (5 min)           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. HR deactivates user in Okta                         │
│     └─→ 2 minutes (Okta admin)                          │
│                                                          │
│  2. SCIM automatically syncs deactivation to AWS        │
│     └─→ 0-40 minutes (next SCIM sync cycle)             │
│                                                          │
│  3. AWS SSO sessions terminated                         │
│     └─→ Immediate (next credential refresh fails)       │
│                                                          │
│  4. Temporary credentials expire                        │
│     └─→ Max 12 hours (based on session duration)        │
│                                                          │
│  5. Remove from 1Password vaults                        │
│     └─→ 3 minutes (1Password admin)                     │
│         • Engineering vault                             │
│         • Shared secrets vault                          │
│                                                          │
│  Total time: 5 minutes (vs 1-2 hours manual)           │
│  Admin time: 5 minutes (vs 1-2 hours)                   │
│                                                          │
│  Bonus: Complete audit trail in:                        │
│  • Okta (who deactivated, when)                         │
│  • AWS CloudTrail (last access time)                    │
│  • 1Password (vault access logs)                        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Additional Identity Providers

#### Microsoft Entra ID (Azure AD)

[Configure automatic provisioning](https://learn.microsoft.com/en-us/entra/identity/saas-apps/aws-single-sign-on-provisioning-tutorial):

1. In Entra ID, go to Enterprise Applications → AWS IAM Identity Center
2. Go to Provisioning → Get started
3. Set Provisioning Mode to "Automatic"
4. Enter SCIM endpoint and token from AWS
5. Test connection and save
6. Enable:
   - Create users
   - Update users
   - Deactivate users
   - Sync groups

#### Google Workspace

1. In Google Admin console → Apps → SAML apps
2. Add AWS IAM Identity Center
3. Configure automatic provisioning
4. Map attributes
5. Enable group sync

---

## Cloud IDE vs Local Development

### Overview

An alternative to managing local credentials is to provide cloud-based development environments. This section compares [GitHub Codespaces](https://github.com/features/codespaces), [AWS Cloud9](https://aws.amazon.com/cloud9/), and local development.

### Comparison Matrix

| Feature | Local Development + AWS SSO | GitHub Codespaces | AWS Cloud9 |
|---------|----------------------------|-------------------|------------|
| **Cost** | $0 (use existing hardware) | ~$23/month (100hrs) | ~$2/month (80hrs) |
| **Setup time** | 15-30 min (one-time) | < 5 min (automatic) | 10-15 min |
| **AWS SSO support** | ✅ Native | ⚠️ Requires config | ✅ Native |
| **Offline work** | ✅ Full capability | ❌ Requires internet | ❌ Requires internet |
| **Performance** | ✅ Local hardware | ⚠️ VM-based | ⚠️ VM-based |
| **Credential security** | ✅ Temporary (SSO) | ✅ Temporary (IAM role) | ✅ IAM role |
| **Onboarding time** | 15 min | 5 min | 10 min |
| **Offboarding** | 5 min (revoke SSO) | Instant (remove access) | Instant (revoke IAM) |
| **IDE choice** | ✅ Any | ⚠️ VS Code only | ⚠️ Cloud9 only |
| **Customization** | ✅ Full control | ⚠️ Limited | ⚠️ Limited |
| **Team consistency** | ⚠️ Manual sync | ✅ Automated (devcontainer) | ✅ Automated |
| **Status** | ✅ Active | ✅ Active | ⚠️ Discontinued (July 2024) |

### Decision Framework

**Choose Local Development + AWS SSO if:**
- ✅ Team is comfortable with command-line tools
- ✅ Developers have reliable internet but work offline sometimes
- ✅ Want maximum flexibility and IDE choice
- ✅ Cost is a concern (free for local development)
- ✅ Performance matters (local is faster than cloud VMs)

**Choose GitHub Codespaces if:**
- ✅ Team is GitHub-centric
- ✅ Want zero local setup (onboard in minutes)
- ✅ Developers have always-on internet
- ✅ Willing to pay ~$23/month per developer
- ✅ Want consistent dev environments via devcontainers

**Choose AWS Cloud9 if:**
- ⚠️ **Not recommended** (discontinued July 2024)
- ✅ Legacy projects already using it (continue for now)
- ✅ Need deep AWS integration
- ⚠️ Plan migration to Codespaces or local

### Hybrid Approach (Recommended)

Combine local development with cloud environments for specific use cases:

```
┌─────────────────────────────────────────────────────────┐
│              Hybrid Development Strategy                 │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Primary: Local Development + AWS SSO                   │
│  ├─ Daily development work                              │
│  ├─ Fast iteration                                       │
│  ├─ Offline capability                                   │
│  └─ Full IDE customization                               │
│                                                          │
│  Secondary: GitHub Codespaces                           │
│  ├─ Quick bug fixes on the go                           │
│  ├─ Onboarding new developers                           │
│  ├─ Pair programming sessions                           │
│  └─ Testing clean environment                            │
│                                                          │
│  Emergency: EC2 with IAM Role                           │
│  ├─ High-bandwidth operations (large data transfers)    │
│  ├─ Debugging production issues                         │
│  └─ Cost-effective for long-running tasks               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### GitHub Codespaces + AWS SSO Setup

Create `.devcontainer/devcontainer.json`:

```json
{
  "name": "Development Container",
  "image": "mcr.microsoft.com/devcontainers/python:3.11",

  "features": {
    "ghcr.io/devcontainers/features/aws-cli:1": {
      "version": "latest"
    },
    "ghcr.io/devcontainers/features/node:1": {
      "version": "20"
    }
  },

  "postCreateCommand": "pip install -r requirements.txt && mise use -g fnox",

  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "dbaeumer.vscode-eslint"
      ]
    }
  },

  "remoteEnv": {
    "AWS_PROFILE": "codespace"
  }
}
```

Configure AWS SSO in Codespace:

```bash
# In Codespace terminal
aws configure sso --profile codespace

# Store as secret in GitHub
# Settings → Secrets → Codespaces → New secret
# Name: AWS_SSO_CONFIG
# Value: <contents of ~/.aws/config>
```

---

## Migration Strategy

### Phase 1: Pilot (Weeks 1-2)

**Goal**: Prove AWS SSO + fnox + 1Password works for 2-3 developers

```
Week 1:
  Day 1-2: Set up AWS IAM Identity Center
  Day 3:   Create permission sets
  Day 4:   Configure 2 pilot users
  Day 5:   Test AWS SSO with aioboto3

Week 2:
  Day 1:   Set up fnox + 1Password integration
  Day 2:   Migrate Pulumi, Slack, GitHub tokens
  Day 3-4: Test full workflow (dev → staging → prod)
  Day 5:   Document learnings and blockers
```

**Success criteria**:
- ✅ Pilot users can develop without long-lived tokens
- ✅ aioboto3 works with AWS SSO
- ✅ Pulumi works with fnox + 1Password
- ✅ No production incidents

### Phase 2: Team Rollout (Weeks 3-4)

**Goal**: Migrate entire engineering team

```
Week 3:
  Day 1:   Team training session (1 hour)
  Day 2-3: Individual migration (15 min per dev)
  Day 4:   Support and troubleshooting
  Day 5:   Verify everyone onboarded

Week 4:
  Day 1-2: Monitor for issues
  Day 3:   Revoke old long-lived tokens
  Day 4:   Update documentation
  Day 5:   Retrospective
```

**Migration checklist per developer**:
- [ ] Install AWS CLI v2
- [ ] Configure AWS SSO: `aws configure sso`
- [ ] Test AWS access: `aws sso login && aws s3 ls`
- [ ] Install 1Password CLI
- [ ] Sign in to 1Password: `op signin`
- [ ] Test fnox: `fnox exec -- pulumi preview`
- [ ] Update .gitignore (remove credential files)
- [ ] Verify aioboto3 app works
- [ ] Delete old IAM user access keys

### Phase 3: Automation (Weeks 5-6)

**Goal**: Implement SCIM for automatic provisioning

```
Week 5:
  Day 1-2: Configure SCIM with Okta/Entra ID
  Day 3:   Test user provisioning
  Day 4:   Test group sync
  Day 5:   Test deprovisioning

Week 6:
  Day 1:   Document onboarding process
  Day 2:   Document offboarding process
  Day 3:   Train HR on new process
  Day 4:   Test with new hire
  Day 5:   Measure time savings
```

### Phase 4: Optimization (Ongoing)

**Goal**: Refine and improve

- Monitor CloudTrail for suspicious activity
- Rotate SCIM tokens before 1-year expiry
- Review permission sets quarterly
- Measure onboarding/offboarding time
- Collect feedback from developers

---

## Complete Examples

### Example 1: FastAPI App with aioboto3 + AWS SSO

See previous [AWS SSO + aioboto3 Integration](#aws-sso-aioboto3-integration) section.

### Example 2: Pulumi Infrastructure with fnox + 1Password

```python
# __main__.py
import pulumi
import pulumi_aws as aws
import pulumi_github as github
import requests
import os

# Get secrets from fnox + 1Password
slack_webhook = os.getenv("SLACK_WEBHOOK_URL")
github_token = os.getenv("GITHUB_TOKEN")

# AWS credentials from AWS SSO (automatic)
# Create S3 bucket for application data
bucket = aws.s3.Bucket("app-uploads",
    acl="private",
    server_side_encryption_configuration=aws.s3.BucketServerSideEncryptionConfigurationArgs(
        rule=aws.s3.BucketServerSideEncryptionConfigurationRuleArgs(
            apply_server_side_encryption_by_default=aws.s3.BucketServerSideEncryptionConfigurationRuleApplyServerSideEncryptionByDefaultArgs(
                sse_algorithm="AES256",
            ),
        ),
    ),
    versioning=aws.s3.BucketVersioningArgs(
        enabled=True,
    ),
)

# Create DynamoDB table
table = aws.dynamodb.Table("app-data",
    attributes=[
        aws.dynamodb.TableAttributeArgs(name="id", type="S"),
        aws.dynamodb.TableAttributeArgs(name="timestamp", type="N"),
    ],
    hash_key="id",
    range_key="timestamp",
    billing_mode="PAY_PER_REQUEST",
    point_in_time_recovery=aws.dynamodb.TablePointInTimeRecoveryArgs(
        enabled=True,
    ),
)

# Create GitHub repository webhook (using token from 1Password)
webhook = github.RepositoryWebhook("deployment-webhook",
    repository="my-app",
    configuration=github.RepositoryWebhookConfigurationArgs(
        url=slack_webhook,  # From 1Password via fnox
        content_type="json",
    ),
    events=["push", "pull_request"],
    opts=pulumi.ResourceOptions(
        provider=github.Provider("github", token=github_token)
    )
)

# Send Slack notification on completion
def send_slack_notification(args):
    bucket_name, table_name = args
    if slack_webhook:
        requests.post(slack_webhook, json={
            "text": f"✅ Infrastructure deployed!\n• Bucket: {bucket_name}\n• Table: {table_name}"
        })
    return f"Notification sent to Slack"

# Export outputs
pulumi.export("bucket_name", bucket.id)
pulumi.export("table_name", table.name)
pulumi.export("notification", pulumi.Output.all(bucket.id, table.name).apply(send_slack_notification))
```

Run with:

```bash
# Login to AWS SSO
aws sso login --profile my-dev

# Login to 1Password (if needed)
op signin

# Deploy via fnox (gets all secrets)
export AWS_PROFILE=my-dev
fnox exec -- pulumi up
```

### Example 3: CI/CD with GitHub Actions

`.github/workflows/deploy.yml`:

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main, staging]

env:
  AWS_REGION: us-east-1

jobs:
  deploy:
    runs-on: ubuntu-latest

    # Use OIDC for AWS authentication (no long-lived keys!)
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      # Install mise and fnox
      - name: Install mise
        uses: jdx/mise-action@v2

      - name: Install fnox
        run: mise use -g fnox

      # Configure AWS credentials using OIDC (temporary, no stored secrets!)
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      # Set up 1Password service account for non-AWS secrets
      - name: Setup 1Password
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          curl -sSfLo op.zip https://cache.agilebits.com/dist/1P/op2/pkg/v2.24.0/op_linux_amd64_v2.24.0.zip
          unzip -od /usr/local/bin op.zip
          op --version

      # Install dependencies
      - name: Install dependencies
        run: |
          pip install pulumi pulumi-aws pulumi-github

      # Select Pulumi stack
      - name: Select Pulumi stack
        run: |
          if [ "${{ github.ref }}" = "refs/heads/main" ]; then
            STACK="production"
          else
            STACK="staging"
          fi
          echo "PULUMI_STACK=$STACK" >> $GITHUB_ENV

      # Deploy infrastructure via fnox (gets secrets from 1Password)
      - name: Deploy with Pulumi
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          fnox exec --profile ci -- pulumi stack select $PULUMI_STACK
          fnox exec --profile ci -- pulumi up --yes

      # Send notification
      - name: Notify on success
        if: success()
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          fnox exec --profile ci -- curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"✅ Deployed $PULUMI_STACK successfully\"}"
```

**GitHub Secrets needed**:
- `AWS_ROLE_ARN`: ARN of IAM role for OIDC (no keys!)
- `OP_SERVICE_ACCOUNT_TOKEN`: 1Password service account token

**No long-lived AWS keys in CI!**

---

## Summary

### What You've Achieved

1. **Eliminated long-lived AWS tokens**
   - ✅ Replaced with AWS SSO temporary credentials
   - ✅ Auto-refresh while session active
   - ✅ Works seamlessly with aioboto3

2. **Centralized non-AWS secrets**
   - ✅ fnox + 1Password for Pulumi, Slack, GitHub
   - ✅ Easy access control via 1Password vaults
   - ✅ Service accounts for CI/CD

3. **Automated user lifecycle**
   - ✅ SCIM provisioning: onboard in 15 minutes
   - ✅ Automatic deprovisioning: offboard in 5 minutes
   - ✅ 90% reduction in admin time

4. **Improved security**
   - ✅ Temporary credentials (expire automatically)
   - ✅ Per-user audit trail in CloudTrail
   - ✅ MFA enforcement
   - ✅ No credentials in git

### Next Steps

1. **Week 1-2**: Set up AWS IAM Identity Center with pilot users
2. **Week 3-4**: Roll out to entire team
3. **Week 5-6**: Implement SCIM for automation
4. **Ongoing**: Monitor, optimize, and iterate

### Resources

**AWS Documentation**:
- [IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/howtogetcredentials.html)
- [Configuring AWS CLI with SSO](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
- [SCIM Provisioning](https://docs.aws.amazon.com/singlesignon/latest/userguide/provision-automatically.html)

**Tools**:
- [fnox Documentation](https://fnox.jdx.dev/)
- [1Password CLI](https://developer.1password.com/docs/cli/)
- [aioboto3 GitHub](https://github.com/terrycain/aioboto3)

**Community**:
- [Stack Overflow: boto3 with AWS SSO](https://stackoverflow.com/questions/62311866/how-to-use-the-aws-python-sdk-while-connecting-via-sso-credentials)
- [fnox Discussion](https://github.com/jdx/mise/discussions/6779)

---

## Sources

- [Getting IAM Identity Center user credentials](https://docs.aws.amazon.com/singlesignon/latest/userguide/howtogetcredentials.html)
- [Configuring AWS CLI SSO](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
- [IAM Identity Center SCIM](https://docs.aws.amazon.com/singlesignon/latest/userguide/provision-automatically.html)
- [Microsoft Entra ID AWS SSO Provisioning](https://learn.microsoft.com/en-us/entra/identity/saas-apps/aws-single-sign-on-provisioning-tutorial)
- [Boto3 with AWS SSO](https://stackoverflow.com/questions/62311866/how-to-use-the-aws-python-sdk-while-connecting-via-sso-credentials)
- [fnox Introduction](https://github.com/jdx/mise/discussions/6779)
- [GitHub Codespaces](https://github.com/features/codespaces)
- [CDW: IAM SSO Streamlines User Management](https://www.cdw.com/content/cdw/en/articles/security/iam-sso-streamlines-onboarding-and-offboarding-aws-users.html)
