# User Lifecycle Management Runbook

This runbook provides step-by-step procedures for onboarding and offboarding team members with AWS SSO, 1Password, and fnox.

## Table of Contents

1. [Onboarding New Developer](#onboarding-new-developer)
2. [Offboarding Departing Employee](#offboarding-departing-employee)
3. [Granting Additional Access](#granting-additional-access)
4. [Revoking Specific Access](#revoking-specific-access)
5. [Troubleshooting](#troubleshooting)

---

## Onboarding New Developer

### Prerequisites

- [ ] New hire has been added to identity provider (Okta, Entra ID, etc.)
- [ ] New hire has email access
- [ ] New hire has 1Password account
- [ ] Admin access to AWS IAM Identity Center
- [ ] Admin access to 1Password

### Timeline: 15-20 minutes total

### Step 1: Identity Provider Setup (2 minutes)

**If using SCIM (automatic provisioning)**:
1. HR adds user to Okta/Entra ID
2. User automatically syncs to AWS IAM Identity Center (0-40 minutes)
3. ✅ Done - proceed to Step 2

**If manual provisioning**:
1. Log in to AWS IAM Identity Center console
2. Go to Users → Add user
3. Fill in details:
   - Username: `firstname.lastname@company.com`
   - Email: `firstname.lastname@company.com`
   - First name: `Firstname`
   - Last name: `Lastname`
   - Display name: `Firstname Lastname`
4. Click "Add user"
5. User receives welcome email with activation link

**Verification**:
```bash
# Verify user exists
aws sso-admin list-users \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --query 'Users[?UserName==`firstname.lastname@company.com`]'
```

### Step 2: Add to Groups (2 minutes)

**In identity provider** (recommended):
1. Add user to appropriate group:
   - `Engineering` → gets DeveloperAccess
   - `DevOps` → gets AdminAccess
   - `DataScience` → gets DataScientistAccess
2. If using SCIM, group membership syncs automatically

**Or in AWS IAM Identity Center**:
1. Go to Groups → Select group (e.g., "Engineering")
2. Click "Add users"
3. Select the new user
4. Click "Add users"

**Verification**:
```bash
# Verify group membership
aws sso-admin list-members \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --group-id group-xxxxx
```

### Step 3: Verify Permission Set Assignments (1 minute)

Permission sets should be automatically assigned via group membership.

**Verification**:
```bash
# Check account assignments for user
aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --account-id 123456789012 \
    --query 'AccountAssignments[?PrincipalId==`user-id-xxxxx`]'
```

Expected result: User should have access to appropriate accounts with assigned permission sets.

### Step 4: 1Password Setup (3 minutes)

1. **Create 1Password account** (if not exists):
   - Go to 1Password admin console
   - Click "Invite People"
   - Enter email: `firstname.lastname@company.com`
   - Select "Team Member" role
   - Send invitation

2. **Grant vault access**:
   - Go to Vaults → "Development" vault
   - Click "Manage Access"
   - Add user with "Can view and copy" permissions
   - Repeat for other relevant vaults:
     - `Engineering` (for team secrets)
     - `Shared-Credentials` (for shared services)

3. **User accepts invitation**:
   - New hire receives email
   - Creates 1Password account
   - Downloads 1Password app (desktop + browser extension)

**Verification**:
- New hire should see "Development" vault in 1Password
- Can view items but not edit (unless granted)

### Step 5: Developer Machine Setup (10 minutes)

**Send to new hire** (or include in onboarding docs):

```bash
# ============================================================================
# Developer Setup Instructions
# ============================================================================

# 1. Install AWS CLI v2
# macOS:
brew install awscli

# Linux:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version  # Should be 2.x

# ============================================================================
# 2. Configure AWS SSO
# ============================================================================

aws configure sso

# When prompted, enter:
# SSO session name: my-company
# SSO start URL: https://my-company.awsapps.com/start
# SSO region: us-east-1
# SSO registration scopes: sso:account:access

# Choose your account and role (e.g., DeveloperAccess)
# CLI default region: us-east-1
# CLI default output: json

# ============================================================================
# 3. Test AWS access
# ============================================================================

# Login (opens browser)
aws sso login --profile my-dev

# Test access
aws s3 ls --profile my-dev
aws sts get-caller-identity --profile my-dev

# Set default profile (optional)
export AWS_PROFILE=my-dev
echo 'export AWS_PROFILE=my-dev' >> ~/.bashrc  # or ~/.zshrc

# ============================================================================
# 4. Install 1Password CLI
# ============================================================================

# macOS:
brew install 1password-cli

# Linux:
curl -sSfLo op.zip https://cache.agilebits.com/dist/1P/op2/pkg/v2.24.0/op_linux_amd64_v2.24.0.zip
unzip -od /usr/local/bin op.zip

# Verify
op --version

# ============================================================================
# 5. Sign in to 1Password
# ============================================================================

op signin

# Enter your 1Password credentials
# This saves your session for future use

# Test
op vault list  # Should see "Development" vault

# ============================================================================
# 6. Install mise and fnox
# ============================================================================

# Install mise
curl https://mise.run | sh
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

# Install fnox
mise use -g fnox

# Verify
fnox --version

# ============================================================================
# 7. Clone repository and test
# ============================================================================

git clone git@github.com:your-org/your-repo.git
cd your-repo

# Test that fnox can read secrets from 1Password
fnox list

# Run application with secrets
fnox exec -- npm start
# or
fnox exec -- python app.py

# ============================================================================
# 8. Test complete setup
# ============================================================================

# Test AWS access
aws s3 ls

# Test 1Password access
op item get "Pulumi" --vault Development --fields access-token

# Test fnox integration
fnox exec -- pulumi preview

# ============================================================================
# ✅ Setup complete!
# ============================================================================
```

### Step 6: Verify Complete Setup (2 minutes)

**Admin verification checklist**:
- [ ] User appears in AWS IAM Identity Center
- [ ] User is member of correct group(s)
- [ ] User has access to development AWS account
- [ ] User has 1Password account
- [ ] User has access to Development vault
- [ ] User can log in via SSO: `aws sso login`
- [ ] User can access secrets via fnox

**New hire verification** (send this checklist):
- [ ] Can run: `aws sso login --profile my-dev`
- [ ] Can run: `aws s3 ls` (shows buckets)
- [ ] Can run: `op signin` (logs into 1Password)
- [ ] Can run: `fnox list` (shows secrets)
- [ ] Can run: `fnox exec -- <command>` (runs with secrets)

### Common Issues During Onboarding

See [Troubleshooting](#troubleshooting) section below.

---

## Offboarding Departing Employee

### Prerequisites

- [ ] HR notification of departure
- [ ] List of employee's access (AWS accounts, 1Password vaults, repos)
- [ ] Admin access to AWS IAM Identity Center
- [ ] Admin access to 1Password
- [ ] Admin access to GitHub (if applicable)

### Timeline: 5-10 minutes total

### ⚡ URGENT: Day of Departure

**Complete these steps on the employee's last day (or immediately upon notification of unexpected departure)**:

### Step 1: Deactivate in Identity Provider (2 minutes)

**If using SCIM** (automatic):
1. HR deactivates user in Okta/Entra ID
2. User automatically deactivated in AWS IAM Identity Center (within 40 minutes)
3. ✅ Done - user loses access

**If manual**:
1. Log in to AWS IAM Identity Center console
2. Go to Users → Find user
3. Click user → Actions → "Disable user"
4. Confirm action

**Verification**:
```bash
# Verify user is disabled
aws sso-admin describe-user \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --user-id user-xxxxx \
    --query 'User.Status'
# Should return: "DISABLED"
```

**Effect**:
- ✅ Existing SSO sessions terminated (effective on next credential refresh, max 12 hours)
- ✅ Cannot create new SSO sessions
- ✅ Cannot access AWS console via SSO portal
- ✅ CLI commands fail immediately on next credential refresh

### Step 2: Remove from 1Password (3 minutes)

1. Log in to 1Password admin console
2. Go to People → Find user
3. Click user → "Suspend" or "Remove from team"
4. Choose "Remove from team" (permanent) or "Suspend" (temporary)
5. Confirm action

**Effect**:
- ✅ User loses access to all vaults
- ✅ Cannot decrypt secrets from 1Password
- ✅ fnox commands fail (can't retrieve secrets)

**Remove from specific vaults** (alternative to full removal):
1. For each vault: Vaults → Select vault → Manage Access
2. Find user and click "Remove"
3. Confirm

### Step 3: Revoke GitHub Access (1 minute)

**Organization level**:
1. Go to GitHub org → People
2. Find user → Remove from organization

**Repository level**:
1. For each repository with custom access
2. Settings → Collaborators → Remove user

**Effect**:
- ✅ Loses access to private repositories
- ✅ Cannot push code
- ✅ Cannot create pull requests

### Step 4: Force Credential Expiration (Optional, 2 minutes)

If you need to revoke access **immediately** (not wait for SSO session expiration):

```bash
# Find and delete the user's permission set assignments
# This immediately revokes access to AWS accounts

aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --account-id 123456789012 \
    --query 'AccountAssignments[?PrincipalId==`user-xxxxx`]'

# For each assignment, delete it:
aws sso-admin delete-account-assignment \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --target-id 123456789012 \
    --target-type AWS_ACCOUNT \
    --permission-set-arn arn:aws:sso:::permissionSet/ssoins-xxxxx/ps-xxxxx \
    --principal-type USER \
    --principal-id user-xxxxx
```

**Effect**: User immediately loses access to AWS accounts (even if SSO session still active).

### 📋 Post-Departure Cleanup (Within 1 Week)

### Step 5: Audit and Document Access (30 minutes)

Run this checklist to document the user's access:

```bash
#!/bin/bash
# audit-user-access.sh

USER_EMAIL="departing.user@company.com"
USER_ID="user-xxxxx"  # From AWS IAM Identity Center

echo "==================================================="
echo "Access Audit for: $USER_EMAIL"
echo "==================================================="

# AWS access
echo "\n1. AWS Account Assignments:"
aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --account-id 123456789012 \
    --query "AccountAssignments[?PrincipalId=='$USER_ID']"

# CloudTrail recent activity (last 7 days)
echo "\n2. Recent AWS Activity (last 7 days):"
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=Username,AttributeValue=$USER_EMAIL \
    --max-results 10

# GitHub org membership
echo "\n3. GitHub Access:"
gh api orgs/your-org/memberships/$USER_EMAIL

# 1Password vaults
echo "\n4. 1Password Vaults:"
op user get --user $USER_EMAIL --format json | jq '.vaults'

echo "\n==================================================="
echo "Audit complete. Review and save this report."
echo "==================================================="
```

### Step 6: Review CloudTrail for Suspicious Activity (15 minutes)

Check the user's recent AWS activity for anomalies:

1. Go to AWS CloudTrail console
2. Event history → Filter by user: `departing.user@company.com`
3. Review last 30 days of activity
4. Look for:
   - ⚠️ Unusual API calls
   - ⚠️ Access to sensitive resources
   - ⚠️ Downloads of data
   - ⚠️ Creation of new IAM users/keys
   - ⚠️ Modification of security groups/policies

**If suspicious activity found**:
- Escalate to security team
- Review affected resources
- Consider rotating credentials for affected services

### Step 7: Remove from Documentation and Systems (10 minutes)

- [ ] Remove from on-call rotation
- [ ] Remove from Slack channels (if private)
- [ ] Remove from email distribution lists
- [ ] Update documentation (remove from "Team" page, etc.)
- [ ] Remove from Datadog, Sentry, or monitoring tools
- [ ] Remove SSH keys from servers (if applicable)
- [ ] Revoke any API tokens created by user

### Step 8: Permanent Deletion (After 30-90 days)

**Only delete after retention period**:

1. Delete user from AWS IAM Identity Center:
   ```bash
   aws sso-admin delete-user \
       --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
       --user-id user-xxxxx
   ```

2. Delete user from 1Password (if suspended):
   - 1Password admin console → People → User → "Delete permanently"

3. Remove from identity provider (Okta/Entra ID)

---

## Granting Additional Access

### Scenario: Developer needs production access

**Approval required**: Yes (manager approval + security team)

**Steps**:

1. **Verify approval**:
   - Manager approval via email/ticket
   - Security team approval (if production)

2. **Add to appropriate group**:
   - Add user to "Production-Developers" group in Okta/Entra ID
   - Group membership syncs to AWS IAM Identity Center
   - User automatically gets permission set assignment

3. **Verify**:
   ```bash
   aws sso-admin list-account-assignments \
       --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
       --account-id 999999999999 \  # Production account
       --query "AccountAssignments[?PrincipalId=='user-xxxxx']"
   ```

4. **Notify user**:
   - Send email: "Production access granted"
   - Remind to re-run: `aws configure sso` (to see new account)

5. **Document**:
   - Log in access management system
   - Set reminder for quarterly access review

### Scenario: Developer needs access to additional 1Password vault

**Steps**:

1. Go to 1Password → Vaults → Select vault
2. Click "Manage Access"
3. Add user with appropriate permissions:
   - **View and copy**: Read-only access
   - **Create and edit**: Can add/modify secrets
   - **Manage**: Full control (admin)
4. Save changes

**Notify user**: User will see vault in 1Password immediately.

---

## Revoking Specific Access

### Scenario: Developer no longer needs staging access

**Steps**:

1. **Remove from group**:
   - Remove user from "Staging-Developers" group
   - Or manually delete account assignment:
     ```bash
     aws sso-admin delete-account-assignment \
         --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
         --target-id 222222222222 \  # Staging account
         --target-type AWS_ACCOUNT \
         --permission-set-arn arn:aws:sso:::permissionSet/ssoins-xxxxx/ps-dev \
         --principal-type USER \
         --principal-id user-xxxxx
     ```

2. **Verify**:
   - User should no longer see staging account in AWS SSO portal
   - User's existing sessions expire within configured duration (max 12 hours)

3. **Notify user**: "Staging access revoked. You will lose access within 12 hours."

### Scenario: Revoke access to specific 1Password vault

**Steps**:

1. Go to 1Password → Vaults → Select vault
2. Click "Manage Access"
3. Find user → Click "Remove"
4. Confirm

**Effect**: User immediately loses access to vault.

---

## Troubleshooting

### Issue: User can't log in to AWS SSO

**Symptoms**:
- `aws sso login` fails
- Error: "Unable to find account assignment"

**Diagnosis**:
```bash
# Check if user exists
aws sso-admin list-users \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --filter "UserName eq \"user@company.com\""

# Check group membership
aws sso-admin list-group-memberships \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --user-id user-xxxxx

# Check account assignments
aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --account-id 123456789012
```

**Resolutions**:
1. ✅ User not in any group → Add to appropriate group
2. ✅ Group not assigned to account → Create account assignment
3. ✅ User disabled → Enable user
4. ✅ SCIM sync failed → Manually add user

### Issue: SSO session expired error

**Symptoms**:
- Error: "Token expired" or "TokenRetrievalError"
- `aws` commands fail

**Resolution**:
```bash
# Simply re-login
aws sso login --profile my-dev

# Test
aws sts get-caller-identity
```

**Prevention**: Configure longer session duration (up to 12 hours).

### Issue: fnox can't access 1Password secrets

**Symptoms**:
- `fnox exec` fails
- Error: "401 Unauthorized" or "Unable to retrieve secret"

**Diagnosis**:
```bash
# Test 1Password CLI access
op signin
op vault list

# Test specific secret
op item get "Pulumi" --vault Development
```

**Resolutions**:
1. ✅ Not signed in → Run: `op signin`
2. ✅ No vault access → Grant access in 1Password admin
3. ✅ Secret doesn't exist → Verify `op://` reference in fnox.toml
4. ✅ Wrong vault name → Check vault name matches exactly

### Issue: SCIM sync not working

**Symptoms**:
- User added to Okta but not in AWS
- Delay > 40 minutes

**Diagnosis**:
```bash
# Check SCIM token expiration
# Go to AWS IAM Identity Center → Settings → Automatic provisioning
# Check token expiration date
```

**Resolutions**:
1. ✅ Token expired → Regenerate token in AWS, update in Okta
2. ✅ SCIM not enabled → Enable in both AWS and Okta
3. ✅ Network/firewall issue → Check Okta can reach AWS endpoint
4. ✅ User missing required fields → Ensure firstName, lastName, email set

**Test SCIM**:
- Manually trigger sync in Okta: Applications → AWS IAM Identity Center → Provisioning → Push Now

### Issue: User has access after offboarding

**Symptoms**:
- User can still access AWS after being disabled
- fnox still works

**Diagnosis**:
```bash
# Check user status
aws sso-admin describe-user \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --user-id user-xxxxx

# Check CloudTrail for recent activity
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=Username,AttributeValue=user@company.com \
    --max-results 5
```

**Resolutions**:
1. ✅ User not disabled → Disable user immediately
2. ✅ Using cached credentials → Wait for session expiration (max 12 hours)
3. ✅ Using IAM user (not SSO) → Check for IAM users with same email, delete
4. ✅ Using API keys → Rotate API keys, revoke old ones

**Immediate revocation**:
```bash
# Delete all account assignments (revokes access immediately)
aws sso-admin delete-account-assignment \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --target-id 123456789012 \
    --target-type AWS_ACCOUNT \
    --permission-set-arn arn:aws:sso:::permissionSet/ssoins-xxxxx/ps-dev \
    --principal-type USER \
    --principal-id user-xxxxx
```

---

## Appendix: Useful Commands

### List all users

```bash
aws sso-admin list-users \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx
```

### List all groups

```bash
aws sso-admin list-groups \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx
```

### List permission sets

```bash
aws sso-admin list-permission-sets \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx
```

### List account assignments for account

```bash
aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --account-id 123456789012
```

### Check who has access to specific AWS account

```bash
aws sso-admin list-account-assignments \
    --instance-arn arn:aws:sso:::instance/ssoins-xxxxx \
    --account-id 123456789012 \
    --query 'AccountAssignments[*].[PrincipalType,PrincipalId,PermissionSetArn]' \
    --output table
```

### 1Password: List all users

```bash
op user list --format json | jq '.[] | {email, name, state}'
```

### 1Password: List user's vault access

```bash
op user get user@company.com --format json | jq '.vaults'
```

---

## Summary

### Onboarding Checklist
- [ ] Add to identity provider (Okta/Entra ID)
- [ ] Add to appropriate groups
- [ ] Verify AWS account access
- [ ] Create 1Password account
- [ ] Grant vault access
- [ ] Send setup instructions
- [ ] Verify complete setup

### Offboarding Checklist
- [ ] Disable in identity provider (immediate)
- [ ] Remove from 1Password (immediate)
- [ ] Revoke GitHub access (immediate)
- [ ] Audit CloudTrail for suspicious activity
- [ ] Document access
- [ ] Remove from systems
- [ ] Permanent deletion (after retention period)

### Time Savings
- **Onboarding**: 15 minutes (vs 2-4 hours manual)
- **Offboarding**: 5 minutes (vs 1-2 hours manual)
- **Access changes**: 2 minutes (vs 30-60 minutes manual)
