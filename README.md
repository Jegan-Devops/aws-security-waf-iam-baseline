# AWS Security Baseline: WAF + IAM Least Privilege

IAM least-privilege policies and a WAF rule set, both defined as code,
reflecting the security baseline that achieved 100% compliance with
enterprise security standards across all managed AWS accounts.

## Problem

Two of the most common ways production environments get breached: IAM
roles with overly broad permissions ("just use AdministratorAccess, it's
easier"), and public-facing ALBs/CloudFront distributions with no layer 7
protection against common web exploits and bots.

## Solution

### IAM (`iam/`)
- **`least-privilege-policy.json`** — scopes a CI/CD deploy role down to
  exactly the actions it needs (update one named ECS service, push to one
  named ECR repo) instead of a wildcard `ecs:*` / `ecr:*`. Includes an
  explicit `Deny` on delete actions, so even a compromised credential can't
  tear down infrastructure.
- **`deploy-role-trust-policy.json`** — an OIDC trust policy that lets
  GitHub Actions assume this role *only* from a specific repo and branch,
  with no long-lived AWS access keys stored anywhere.

### WAF (`waf/`)
- AWS Managed Common Rule Set — blocks SQL injection, XSS, and request
  smuggling patterns without writing custom signatures
- Known Bad Inputs rule set — catches exploit patterns like log4j-style
  payloads
- A custom rate-based rule — blocks any single IP exceeding 2000 requests
  per 5-minute window, which is the actual mechanism behind basic DDoS
  mitigation (not just "WAF = magic protection")

## Tech Used

AWS IAM, AWS WAFv2, Terraform, OIDC federation

## Usage

```bash
cd waf
terraform init
terraform plan -var="alb_arn=arn:aws:elasticloadbalancing:..."
terraform apply
```

The IAM JSON policies in `iam/` are reference documents — attach them via
console, CLI, or your existing Terraform IAM module:

```bash
aws iam put-role-policy \
  --role-name my-deploy-role \
  --policy-name least-privilege-deploy \
  --policy-document file://iam/least-privilege-policy.json
```

## Notes

Replace `ACCOUNT_ID` placeholders in the IAM JSON files with a real AWS
account ID before applying. This is a sanitized version of the access
control pattern used across managed production accounts — the actual
production policies were scoped per-application rather than this single
demo example.

## Cleanup

```bash
cd waf && terraform destroy
```
