# Just-in-Time Access for Temporary Hires

## Executive Summary

For short-term contractors (1-2 days), traditional onboarding is too slow and heavyweight. This guide demonstrates **just-in-time (JIT) access** using 1Password's guest accounts and time-limited sharing features.

### Key Benefits

✅ **Fast**: Grant access in 5 minutes (vs 2+ hours for full onboarding)
✅ **Automatic expiration**: Access revokes itself after 1-7 days
✅ **Minimal overhead**: No AWS SSO setup, no group management
✅ **Secure**: Limited scope, full audit trail
✅ **Zero cleanup**: Auto-expires, no manual revocation needed

### Use Cases

- 🔧 **Contractor** fixing specific bug (1-2 days)
- 📊 **Consultant** reviewing architecture (half-day)
- 🚨 **Incident responder** during emergency (hours)
- 🔍 **Auditor** reviewing specific systems (1-2 days)
- 🎓 **Trainer** demonstrating features (1 day)
- 💻 **Freelancer** implementing specific feature (2-3 days)

---

## Table of Contents

1. [1Password Guest Accounts](#1password-guest-accounts) - Best for 1-7 days
2. [1Password Item Sharing](#1password-item-sharing) - Best for hours to 1 day
3. [AWS Temporary Credentials](#aws-temporary-credentials) - For AWS-only access
4. [Complete Workflow Examples](#complete-workflow-examples)
5. [Security Considerations](#security-considerations)
6. [Cost Analysis](#cost-analysis)

---

## 1Password Guest Accounts

**Best for**: 1-7 day engagements where contractor needs multiple secrets

### Overview

[1Password guest accounts](https://support.1password.com/guests/) allow you to:
- Grant limited vault access
- Set automatic expiration (1-90 days)
- No additional cost (included in Business/Teams)
- Full audit trail
- Easy revocation

### Architecture

```
┌─────────────────────────────────────────────────────┐
│         1Password Guest Account Flow                 │
├─────────────────────────────────────────────────────┤
│                                                      │
│  1. Admin invites guest (5 min)                     │
│     └─→ Sets expiration: 2 days                     │
│                                                      │
│  2. Guest receives email                            │
│     └─→ Creates temporary 1Password account         │
│                                                      │
│  3. Guest gets access to specific vaults            │
│     └─→ "Contractor-Temp" vault only                │
│                                                      │
│  4. Guest uses fnox to run tasks                    │
│     └─→ fnox exec -- npm start                      │
│                                                      │
│  5. After 2 days: Access auto-expires               │
│     └─→ No cleanup needed!                          │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### Setup: Create Guest Account (5 minutes)

#### Step 1: Invite Guest (2 minutes)

**Via 1Password Web App**:
1. Go to 1Password admin console
2. Click "Invite People" → "Invite Guest"
3. Enter contractor's email
4. **Set expiration**: Choose duration
   - 1 day (24 hours)
   - 2 days (48 hours)
   - 7 days (1 week)
   - Custom (1-90 days)
5. Click "Send Invitation"

**Via 1Password CLI**:
```bash
# Invite guest with 2-day expiration
op user provision \
    --email contractor@example.com \
    --role guest \
    --vault "Contractor-Temp" \
    --expiration 2d

# Or 48 hours exactly
op user provision \
    --email contractor@example.com \
    --role guest \
    --vault "Contractor-Temp" \
    --expiration 48h
```

#### Step 2: Grant Vault Access (2 minutes)

Create a dedicated vault for contractors:

1. **Create vault**: "Contractor-Temp"
2. **Add only needed secrets**:
   ```
   Contractor-Temp vault:
   ├── GitHub (read-only PAT)
   ├── Staging Database (connection string)
   ├── Staging API Keys (Stripe test, SendGrid)
   └── Documentation (links, credentials)
   ```
3. **Grant guest access**:
   - Vault → Manage Access → Add guest
   - Permission: "View and copy" (read-only)
4. **Do NOT grant access to**:
   - Production vaults
   - Employee credentials
   - Sensitive customer data

#### Step 3: Contractor Accepts Invite (1 minute)

Contractor receives email and:
1. Clicks "Accept Invitation"
2. Creates temporary 1Password account
3. Installs 1Password (optional, can use web)
4. Sees only "Contractor-Temp" vault

**No personal 1Password account needed!**

### Usage: Contractor Workflow

Contractor runs tasks using fnox + 1Password:

```bash
# 1. Sign in to 1Password
op signin

# 2. Verify access
op vault list
# Shows: "Contractor-Temp" vault

# 3. Use secrets via fnox
fnox exec -- npm start
fnox exec -- npm test
fnox exec -- pulumi preview --stack staging
```

**fnox.toml for contractors**:
```toml
# fnox.toml (already in repo)

[providers]
onepassword = { type = "1password" }

[secrets]
GITHUB_TOKEN = {
    provider = "onepassword",
    ref = "op://Contractor-Temp/GitHub/token"
}

STAGING_DATABASE_URL = {
    provider = "onepassword",
    ref = "op://Contractor-Temp/Database/staging-url"
}

STRIPE_TEST_KEY = {
    provider = "onepassword",
    ref = "op://Contractor-Temp/Stripe/test-key"
}
```

### Auto-Expiration

After the configured time (e.g., 2 days):

1. **Guest account automatically suspended**
2. **Contractor loses all access** (cannot sign in)
3. **Audit log preserved** (who accessed what, when)
4. **No admin action required** (zero cleanup!)

**Timeline**:
```
Day 0, 9am:  Invite sent
Day 0, 10am: Contractor accepts, starts work
Day 2, 10am: Account auto-expires
Day 2, 11am: Contractor tries to access → Denied
```

### Extension (if needed)

If work takes longer:

```bash
# Extend expiration by 2 more days
op user update contractor@example.com --expiration +2d

# Or set specific date
op user update contractor@example.com --expiration 2024-12-31
```

### Manual Revocation (if needed early)

```bash
# Suspend immediately
op user suspend contractor@example.com

# Or remove entirely
op user delete contractor@example.com
```

---

## 1Password Item Sharing

**Best for**: Hours to 1 day, single secret needed

### Overview

For ultra-short engagements (few hours), skip guest accounts and use **item sharing**:
- Share specific item (not entire vault)
- Set expiration (1 hour to 30 days)
- No 1Password account needed for recipient
- View-only link with expiration

### Use Cases

- Contractor needs **only** staging database URL (4 hours)
- Consultant needs **only** read-only GitHub token (half-day)
- Auditor needs **only** specific API key (1 day)

### How to Share Item

#### Via 1Password App:

1. Find item (e.g., "Staging Database URL")
2. Right-click → "Share"
3. Configure:
   - **Link expires**: 8 hours (or 1, 4, 24 hours, 7 days)
   - **View limit**: 1 time (or unlimited)
   - **Password protect**: Optional (add PIN)
4. Copy link and send to contractor

**Contractor receives**:
```
https://share.1password.com/s/abc123xyz
(expires in 8 hours)
```

Contractor clicks link, views secret, copies value.

#### Via 1Password CLI:

```bash
# Share item with 8-hour expiration
op item share "Staging Database URL" \
    --expiration 8h \
    --vault "Contractor-Temp"

# With view limit
op item share "GitHub Token" \
    --expiration 24h \
    --max-views 1 \
    --vault "Contractor-Temp"
```

### Limitations

- ❌ Contractor can copy/save secret (trust required)
- ❌ No audit trail after link expires
- ❌ Only for single secrets (not multiple)

**Recommendation**: Use item sharing only for:
- Very short engagements (< 1 day)
- Non-critical secrets (test/staging)
- Trusted contractors

For anything longer or more sensitive, use guest accounts.

---

## AWS Temporary Credentials

**Best for**: Contractor needs AWS access only (no other secrets)

### Option 1: AWS SSO with Time-Limited Permission Set

**Setup** (10 minutes):

1. **Create temporary IAM Identity Center user**:
   ```bash
   aws sso-admin create-user \
       --instance-arn arn:aws:sso:::instance/ssoins-xxx \
       --user-name contractor-john-temp \
       --email john@contractor.com \
       --first-name John \
       --last-name Contractor
   ```

2. **Create time-limited permission set**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["s3:GetObject", "s3:ListBucket"],
         "Resource": [
           "arn:aws:s3:::staging-bucket",
           "arn:aws:s3:::staging-bucket/*"
         ]
       },
       {
         "Effect": "Allow",
         "Action": ["logs:Tail", "logs:GetLogEvents"],
         "Resource": "arn:aws:logs:*:*:log-group:/aws/staging/*"
       }
     ]
   }
   ```

3. **Assign with session duration**:
   ```bash
   # Max session: 1 hour (contractor must re-login every hour)
   aws sso-admin create-permission-set \
       --instance-arn arn:aws:sso:::instance/ssoins-xxx \
       --name "ContractorReadOnly" \
       --session-duration PT1H  # 1 hour
   ```

4. **Set reminder to revoke**:
   - Add calendar reminder for end of engagement
   - Delete user manually after work complete

**Limitations**:
- ⚠️ No auto-expiration (must manually delete user)
- ⚠️ Overhead for short engagements

### Option 2: AWS STS AssumeRole with Session Tokens (Recommended)

**For very short access** (1-12 hours):

1. **Create temporary IAM role**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::YOUR_ACCOUNT:user/admin"
         },
         "Action": "sts:AssumeRole",
         "Condition": {
           "StringEquals": {
             "sts:ExternalId": "contractor-john-2024-11-23"
           }
         }
       }
     ]
   }
   ```

2. **Generate temporary credentials** (admin does this):
   ```bash
   aws sts assume-role \
       --role-arn arn:aws:iam::123456789:role/ContractorTemp \
       --role-session-name contractor-john \
       --duration-seconds 14400 \  # 4 hours
       --external-id contractor-john-2024-11-23 \
       --output json > contractor-creds.json
   ```

3. **Share credentials with contractor**:
   ```json
   {
     "Credentials": {
       "AccessKeyId": "ASIA...",
       "SecretAccessKey": "...",
       "SessionToken": "...",
       "Expiration": "2024-11-23T18:00:00Z"
     }
   }
   ```

4. **Contractor sets environment variables**:
   ```bash
   export AWS_ACCESS_KEY_ID="ASIA..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_SESSION_TOKEN="..."

   # Test
   aws s3 ls s3://staging-bucket
   ```

5. **Credentials auto-expire** after 4 hours (no cleanup needed!)

**Advantages**:
- ✅ Automatic expiration (1-12 hours)
- ✅ No manual revocation needed
- ✅ Audit trail in CloudTrail
- ✅ No IAM user creation

**Disadvantages**:
- ⚠️ Max 12-hour duration
- ⚠️ Credentials shareable (trust required)
- ⚠️ Manual generation by admin

---

## Complete Workflow Examples

### Scenario 1: Bug Fix Contractor (2 days)

**Context**: Contractor needs to fix staging bug, needs GitHub, database, API keys.

**Workflow**:

```bash
# ============================================================================
# Admin: 5 minutes setup
# ============================================================================

# 1. Create temporary vault
op vault create "Contractor-BugFix-Nov2024"

# 2. Add secrets
op item create --vault "Contractor-BugFix-Nov2024" \
    --category Login \
    --title "GitHub Token" \
    --field "label=token,type=concealed,value=ghp_staging_readonly_..."

op item create --vault "Contractor-BugFix-Nov2024" \
    --category Database \
    --title "Staging Database" \
    --field "label=url,value=postgresql://staging.example.com/db"

op item create --vault "Contractor-BugFix-Nov2024" \
    --category Login \
    --title "Stripe Test Key" \
    --field "label=key,type=concealed,value=sk_test_..."

# 3. Invite guest with 2-day expiration
op user provision \
    --email contractor@example.com \
    --role guest \
    --vault "Contractor-BugFix-Nov2024" \
    --expiration 2d

# ============================================================================
# Contractor: 2 minutes onboarding
# ============================================================================

# 1. Accept invite email
# 2. Create 1Password account
# 3. Install 1Password CLI
brew install 1password-cli

# 4. Sign in
op signin

# 5. Verify access
op vault list
# Shows: "Contractor-BugFix-Nov2024"

# ============================================================================
# Contractor: Work
# ============================================================================

# Clone repo
git clone https://github.com/company/app.git
cd app

# Create fnox.toml for temporary vault
cat > fnox.local.toml <<EOF
[providers]
onepassword = { type = "1password" }

[secrets]
GITHUB_TOKEN = {
    provider = "onepassword",
    ref = "op://Contractor-BugFix-Nov2024/GitHub Token/token"
}

DATABASE_URL = {
    provider = "onepassword",
    ref = "op://Contractor-BugFix-Nov2024/Staging Database/url"
}

STRIPE_KEY = {
    provider = "onepassword",
    ref = "op://Contractor-BugFix-Nov2024/Stripe Test Key/key"
}
EOF

# Run tests
fnox exec -- npm test

# Run app
fnox exec -- npm start

# Fix bug, commit, push
git add .
git commit -m "fix: resolve staging bug"
git push

# ============================================================================
# After 2 days: Auto-expiration
# ============================================================================

# Day 2, same time as invite:
# - Contractor's 1Password account suspended
# - Can no longer sign in
# - All access revoked
# - No admin action needed!
```

**Total admin time**: 5 minutes
**Total contractor onboarding**: 2 minutes
**Cleanup required**: 0 minutes (auto-expires)

### Scenario 2: Emergency Incident Response (4 hours)

**Context**: Production incident, need external consultant to help debug immediately.

**Workflow**:

```bash
# ============================================================================
# Admin: 2 minutes (during incident!)
# ============================================================================

# Share production log access (item sharing)
op item share "Production Datadog API Key" \
    --expiration 4h \
    --max-views 10 \
    --vault "Production"

# Share production database read-only credentials
op item share "Production DB Read-Only" \
    --expiration 4h \
    --max-views 5 \
    --vault "Production"

# Send links via Slack/email to consultant
# Links expire in 4 hours automatically

# ============================================================================
# Consultant: Immediate access
# ============================================================================

# 1. Click links (no account needed!)
# 2. View credentials
# 3. Copy to local environment

export DATADOG_API_KEY="copied-from-link"
export DATABASE_URL="copied-from-link"

# 4. Debug production issue
datadog-cli logs tail --service api

psql $DATABASE_URL -c "SELECT * FROM error_logs ORDER BY timestamp DESC LIMIT 100"

# 5. Identify root cause, suggest fix

# ============================================================================
# After 4 hours: Links expire
# ============================================================================

# Links no longer work
# Consultant cannot access secrets again
# No cleanup needed
```

**Total admin time**: 2 minutes
**Total consultant onboarding**: 0 minutes (just click links)
**Cleanup required**: 0 minutes (auto-expires)

### Scenario 3: Freelancer Feature Implementation (3 days)

**Context**: Freelancer implementing new feature, needs staging access, not production.

**Workflow**:

```bash
# ============================================================================
# Admin: 7 minutes setup
# ============================================================================

# 1. Create guest account with 3-day expiration
op user provision \
    --email freelancer@example.com \
    --role guest \
    --expiration 3d

# 2. Create dedicated vault
op vault create "Freelancer-NewFeature-Nov2024"

# 3. Grant vault access
op vault grant "Freelancer-NewFeature-Nov2024" \
    --user freelancer@example.com \
    --permission view-copy

# 4. Copy staging secrets to freelancer vault
op item get "Staging Database" --vault Staging \
    | op item create --vault "Freelancer-NewFeature-Nov2024"

op item get "Staging API Keys" --vault Staging \
    | op item create --vault "Freelancer-NewFeature-Nov2024"

# 5. Add GitHub PAT with limited scope (repo read + PR create)
op item create --vault "Freelancer-NewFeature-Nov2024" \
    --category Login \
    --title "GitHub Limited PAT" \
    --field "label=token,value=ghp_limited_scope_..."

# ============================================================================
# Freelancer: Standard workflow
# ============================================================================

# Accept invite, sign in to 1Password
op signin

# Use fnox for all work
fnox exec -- npm start
fnox exec -- npm test
fnox exec -- npm run build

# Implement feature over 3 days
git checkout -b feature/new-feature
# ... work ...
git push origin feature/new-feature

# Create PR
gh pr create --title "feat: new feature" --body "..."

# ============================================================================
# After 3 days: Auto-expiration
# ============================================================================

# Freelancer's access revoked
# Can no longer access secrets
# Vault remains (admin can delete later if desired)
```

**Total admin time**: 7 minutes
**Total freelancer onboarding**: 2 minutes
**Cleanup required**: 0 minutes (auto-expires), optionally delete vault later

---

## Security Considerations

### Principle of Least Privilege

**Create separate vaults for different risk levels**:

```
Vaults:
├── Production (full-time employees only)
├── Staging (employees + senior contractors)
├── Development (employees + all contractors)
├── Contractor-Temp (time-limited guests only)
└── Read-Only-Logs (auditors, consultants)
```

**Grant minimal permissions**:
- Guests: "View and copy" only (read-only)
- No "Create and edit" (cannot modify secrets)
- No "Manage" (cannot change vault settings)

### Audit Trail

1Password logs all access:

```bash
# View guest activity
op activity --user contractor@example.com

# Export audit log
op activity --format json > contractor-audit.json

# Check specific item access
op item get "Staging Database" --vault Contractor-Temp --activity
```

**Review**:
- Who accessed what secrets
- When they accessed them
- From which IP address
- Which device

### Trust but Verify

**For higher-risk secrets, use additional controls**:

1. **IP restrictions** (1Password firewall rules):
   ```bash
   # Only allow access from contractor's IP
   op vault update "Contractor-Temp" \
       --allowed-ips "203.0.113.42"
   ```

2. **Require 2FA** for guest account

3. **Watermark secrets**:
   ```bash
   # Add contractor identifier to credentials
   # e.g., create a unique API key for each contractor
   STRIPE_KEY_CONTRACTOR_JOHN="sk_test_contractor_john_..."
   ```

   Then you can identify leaked credentials by identifier.

4. **Rotate after engagement**:
   ```bash
   # After contractor work complete, rotate any accessed secrets
   # (especially if they had production access)
   ```

### What NOT to Share with Temporary Hires

❌ **Never share with guests**:
- Production database write access
- Production API keys (read-only acceptable with caution)
- Customer PII or financial data
- Admin credentials (AWS root, 1Password owner, etc.)
- Source code signing keys
- Infrastructure automation credentials (Terraform, Pulumi state)

✅ **Safe to share**:
- Staging environment credentials
- Test API keys (Stripe test mode, SendGrid sandbox)
- Read-only production logs (for debugging)
- Development database credentials
- Documentation and onboarding materials

### Emergency Revocation

If contractor account compromised:

```bash
# Immediate suspension
op user suspend contractor@example.com

# Check what they accessed
op activity --user contractor@example.com --format json \
    | jq '.[] | select(.action=="ItemUsed") | {item, timestamp}'

# Rotate any secrets they accessed
# (see list from above command)

# Remove from vault
op vault revoke "Contractor-Temp" --user contractor@example.com

# Delete account
op user delete contractor@example.com
```

**Document in incident log**:
- When account was compromised
- What secrets were accessed
- What was rotated
- Timeline of revocation

---

## Cost Analysis

### 1Password Pricing

| Plan | Guest Accounts | Item Sharing | Cost |
|------|----------------|--------------|------|
| **Teams** | Included (unlimited) | Included | $20/month (5 users) |
| **Business** | Included (unlimited) | Included | $8/user/month |

**No additional cost for guest accounts!**

### Cost Comparison

**Traditional onboarding** (2-day contractor):
- Admin time: 2 hours × $100/hr = $200
- AWS SSO setup: 1 hour × $100/hr = $100
- Offboarding: 1 hour × $100/hr = $100
- **Total**: $400

**JIT with 1Password guest** (2-day contractor):
- Admin time: 5 minutes × $100/hr = $8
- 1Password cost: $0 (included)
- Offboarding: 0 minutes (auto-expires)
- **Total**: $8

**Savings**: $392 per contractor (98% reduction)

### ROI for Multiple Contractors

If you hire 10 short-term contractors per year:

| Method | Cost/contractor | Total cost/year |
|--------|----------------|-----------------|
| Traditional | $400 | $4,000 |
| JIT (1Password) | $8 | $80 |
| **Savings** | **$392** | **$3,920** |

Plus: Improved security, better audit trail, zero cleanup.

---

## Advanced: Automated JIT Access

For frequent contractor engagements, automate the process:

### Self-Service Contractor Portal

```python
# contractor_portal.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
import subprocess
import datetime

app = FastAPI()

class ContractorRequest(BaseModel):
    email: EmailStr
    duration_days: int  # 1-7
    vault_template: str  # "staging" or "development"
    justification: str

@app.post("/request-access")
async def request_access(req: ContractorRequest):
    """
    Contractor submits access request
    Manager approves via Slack
    System auto-creates guest account
    """

    # 1. Send approval request to Slack
    await send_slack_approval_request(req)

    # 2. Wait for manager approval (async webhook)
    # ...

    # 3. Auto-create guest account
    vault_name = f"Contractor-{req.vault_template}-{datetime.date.today()}"

    # Create vault from template
    subprocess.run([
        "op", "vault", "create", vault_name
    ])

    # Copy secrets from template
    template_items = get_vault_items(f"{req.vault_template}-template")
    for item in template_items:
        copy_item(item, vault_name)

    # Invite guest
    subprocess.run([
        "op", "user", "provision",
        "--email", req.email,
        "--role", "guest",
        "--vault", vault_name,
        "--expiration", f"{req.duration_days}d"
    ])

    # 4. Send welcome email to contractor
    await send_welcome_email(req.email, vault_name, req.duration_days)

    return {
        "status": "approved",
        "vault": vault_name,
        "expires": f"{req.duration_days} days"
    }
```

**Workflow**:
1. Contractor fills form: email, duration, justification
2. Manager gets Slack notification
3. Manager approves (clicks button)
4. System auto-creates guest account
5. Contractor receives email with instructions
6. Access auto-expires after duration

---

## Best Practices

### ✅ Do This

1. **Always set expiration** on guest accounts (default: 2-3 days)
2. **Use dedicated vaults** for contractors (never production)
3. **Create vault per engagement** (e.g., "Contractor-BugFix-Nov2024")
4. **Grant read-only access** unless write absolutely required
5. **Review audit logs** after engagement completes
6. **Rotate secrets** if contractor had production access
7. **Document engagement** (who, what, when, why)

### ❌ Don't Do This

1. ❌ Share from production vaults directly
2. ❌ Grant "Team Member" role for short engagements
3. ❌ Use item sharing for multi-day access
4. ❌ Skip expiration dates (always set!)
5. ❌ Reuse vaults across contractors
6. ❌ Share owner/admin credentials
7. ❌ Forget to check audit logs

---

## Summary: Quick Reference

### Choose Your Method

| Duration | Users | Secrets | Method | Setup Time |
|----------|-------|---------|--------|------------|
| **< 4 hours** | 1 | 1-2 | Item sharing | 1 min |
| **4-24 hours** | 1 | 1-5 | Item sharing | 2 min |
| **1-2 days** | 1 | 5+ | Guest account | 5 min |
| **2-7 days** | 1 | Any | Guest account | 5 min |
| **1 week+** | 1 | Any | Full onboarding | 15 min |
| **Multiple** | 2+ | Any | Dedicated vault + guests | 10 min |

### Expiration Guidelines

| Engagement Type | Recommended Expiration |
|----------------|----------------------|
| Emergency debug | 4 hours |
| Quick fix | 1 day |
| Small feature | 2-3 days |
| Medium project | 5-7 days |
| Large project | Full onboarding (not JIT) |

### Security by Secret Type

| Secret Type | Guest Access | Item Sharing |
|-------------|-------------|--------------|
| Staging database | ✅ Yes | ✅ Yes |
| Test API keys | ✅ Yes | ✅ Yes |
| Dev environment | ✅ Yes | ✅ Yes |
| Production read-only | ⚠️ Careful | ⚠️ Careful |
| Production write | ❌ No | ❌ No |
| Customer PII | ❌ No | ❌ No |
| Admin credentials | ❌ No | ❌ No |

---

## Conclusion

Just-in-time access with 1Password guest accounts provides:

✅ **5-minute setup** vs 2+ hours traditional onboarding
✅ **Auto-expiration** (no manual cleanup)
✅ **Zero additional cost** (included in Teams/Business)
✅ **Full audit trail** (who accessed what, when)
✅ **Secure by default** (read-only, limited scope)

**Perfect for**:
- Short-term contractors (1-7 days)
- Emergency responders (hours)
- Consultants and auditors
- Freelancers on small projects
- Any temporary access need

**Next Steps**:
1. Create "Contractor-Template" vault with staging secrets
2. Document your JIT access process
3. Train managers on inviting guests
4. Set default expiration policy (e.g., 3 days)
5. Review audit logs monthly
