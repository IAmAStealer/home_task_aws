# Serverless Health Check API

A `/health` endpoint (API Gateway HTTP API → Lambda → DynamoDB) deployed via Terraform, with staging/prod environments.

## Architecture

```
Client → API Gateway (HTTP API) → Lambda (Python) → DynamoDB (SSE-KMS encrypted)
                                        │
                                        └→ CloudWatch Logs
```

- **API Gateway**: HTTP API with `GET /health` and `POST /health` routes, throttled (current limits are conservative placeholders — adapt to real traffic before going further than staging).
- **Lambda**: logs the incoming event, valid or not for later debugging / security review, validates that a POST body contains a `payload` key (400 if missing), writes a record to DynamoDB, returns 200.
- **DynamoDB**: single table, partition key `uuid`, encrypted with a customer-managed KMS key (SSE-KMS).
- **IAM**: restricted only to the requirements: `dynamodb:PutItem` on the table's ARN, `logs:CreateLogStream`/`PutLogEvents` on the function's log group, `kms:GenerateDataKey`/`Decrypt`/`DescribeKey` on the CMK.

All resources follow the naming convention `{environment}-resource-name` (e.g. `staging-lambda-requests`, `prod-lambda-requests-db`).

## Prerequisites

- Terraform >= 1.16
- An AWS account with credentials configured locally (`aws configure` or SSO), with permissions to create IAM roles, KMS keys, DynamoDB tables, Lambda functions, CloudWatch log groups, and API Gateway APIs.
- Python 3 (only used locally to sanity-check the Lambda source with `py_compile` — no external dependencies are required at runtime, the code only uses `boto3`, which is already provided by the Lambda Python runtime).

No secrets are stored in this repository. Local deployment uses your own AWS CLI credentials; `*.tfvars` files are gitignored (see `.gitignore`) since they can hold environment-specific values, but the ones used for staging/prod here contain no sensitive data — you can recreate them from the example below.

### Required variables (per environment, via `.tfvars`)

| Variable                  | Description                                 | Example (staging)    |
|---------------------------|---------------------------------------------|----------------------|
| `environment`             | `staging` or `prod`                         | `"staging"`          |
| `region`                  | AWS region to deploy into                   | `"eu-west-1"`        |
| `log_retention_in_days`   | CloudWatch log retention                    | `60`                 |
| `app_log_level`           | Application log level (Lambda's own logger) | `"INFO"`             |
| `system_log_level`        | Lambda platform log level                   | `"WARN"`             |

## Deploying staging

Staging and prod are isolated via separate Terraform workspaces, backed by a shared S3 backend (see Bootstrap below) — without that, they'd share the same local state file and overwrite each other.

```bash
terraform init
terraform workspace new staging   # first time only; use `select` afterwards
terraform plan -var-file="staging.tfvars" -out staging.plan
terraform apply staging.plan
```

Deploying `prod` is identical, on its own workspace: `terraform workspace new prod` (or `select`), then `terraform plan -var-file="prod.tfvars" -out prod.plan` and `terraform apply prod.plan`.

### Bootstrap (one-time, per AWS account)

Two things need to exist before this project can be deployed at all, neither of which Terraform can create for itself (chicken-and-egg):

**1. The S3 state backend.** Terraform's state has to live somewhere persistent and shared between your machine and CI — a local state file can't do that (and must never be committed to git: it contains account IDs, ARNs and other details you don't want in a public repo). Create the bucket once, manually:

```bash
BUCKET="<a-globally-unique-name>"   # this project used a UUID

aws s3api create-bucket --bucket "$BUCKET" --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Then point `terraform.tf`'s `backend "s3" {}` block at that bucket name (backend blocks can't use variables — it has to be a literal value) and run `terraform init` (or `-migrate-state` if you already have local state), followed by `terraform workspace new staging` and `terraform workspace new prod`.

**2. The CI/CD IAM role.** This repo provisions its own deploy role (OIDC-federated, assumed by GitHub Actions — see `oidc.tf`). That role can't create itself: GitHub can't assume a role that doesn't exist yet. So the **very first** `apply` on a fresh AWS account (the one that creates the OIDC provider, the deploy role, and everything else) has to be run locally, with your own AWS credentials — not through CI. Once that first apply succeeds, all subsequent deploys (staging or prod) can go through GitHub Actions using that role. If you ever destroy and recreate the deploy role itself, you're back to a local bootstrap for that one step.

## Testing the endpoint

```bash
# Valid request
curl -i -X POST https://<api-id>.execute-api.<region>.amazonaws.com/health \
  -H "Content-Type: application/json" \
  -d '{"payload":"hello"}'

# Missing payload -> 400
curl -i -X POST https://<api-id>.execute-api.<region>.amazonaws.com/health \
  -H "Content-Type: application/json" \
  -d '{"foo":"bar"}'

# GET
curl -i https://<api-id>.execute-api.<region>.amazonaws.com/health
```

The `Content-Type: application/json` header is required — without it, API Gateway does not forward the request body to Lambda as expected, and the request will fail.

## CI/CD

The OIDC trust (GitHub → AWS, no stored long-lived keys) and the deploy role's permissions are in place (`oidc.tf`), but the GitHub Actions workflow itself isn't wired up yet — that's my next step. Once done: `terraform fmt -check`/`validate` and a security/IaC scan on every push, `plan` on pull requests, automatic `apply` on staging on merge to `main`, manual approval gate before `apply` on prod. See the Bootstrap section above for why the very first apply still has to be run locally.

## Design choices / assumptions

- **Security-first build order**: the KMS key was deliberately built and wired in *before* any other resource (DynamoDB, IAM, Lambda). Every resource that touches data (DynamoDB, and its consumer's IAM role) was designed against the encryption layer from the start. This mirrors a "security by design" approach.
- **DynamoDB encryption**: uses a customer-managed KMS key (CMK) rather than the AWS-owned default, satisfying both the base SSE requirement and the bonus "customer managed key" item. Key rotation is enabled.
- **IAM**: three distinct roles — one for the Lambda execution (least privilege, scoped to the exact table/log group/key ARNs), one for CI/CD deployment (OIDC-federated, assumed by GitHub Actions for a specific repo/branch only, no stored AWS keys), and your own credentials for the one-time local bootstrap (see Bootstrap section above).
- **API Gateway payload format**: `payload_format_version = "2.0"` is used, giving the Lambda event a `requestContext.http.method` field rather than the older `httpMethod` field.
- **Validation scope**: the `payload` key check only applies to `POST` requests (a `GET /health` has no body to validate).
- **Logging vs. storage**: every request (valid or not) is logged to CloudWatch (`INFO` for valid, `WARN` for rejected) for audit/security visibility, but only successfully validated requests are written to DynamoDB — CloudWatch is the security/audit trail, DynamoDB is the functional data store. Some of those logged-but-rejected events may be worth forwarding to a security team's observability / threat detection tooling later on.
- **Stage**: uses the reserved `$default` stage name (no `/{stage}` segment in the URL) with `auto_deploy = true`, since staging and prod are already fully separate deployments (separate `terraform apply -var-file`, separate API Gateway resources).
- **Routes**: `GET /health` and `POST /health` are declared via a `for_each` over a small map, rather than duplicated resource blocks — the same pattern is used for the two `aws_lambda_permission` statements (one per method, least privilege on `source_arn`).
- **Not implemented (see `TODO.md` for details and rationale)**: DynamoDB TTL, KMS encryption of CloudWatch logs, Lambda in its own VPC, structured (field-level) logging. These were deliberately deprioritized to prioritize a complete, working, and testable core chain (KMS → DynamoDB → IAM → Lambda → API Gateway) over partially-implemented bonus items.
- **FinOps**: `region` is a per-environment variable (staging currently uses a cheaper region), and every resource carries `environment`/`application` tags for cost tracking. Basic, but a base to build on.

## Known limitations

- The GitHub Actions workflow itself isn't wired up yet — the OIDC trust/deploy role are ready, but deploys are still manual for now.
- No `requirements.txt` / dependency scanning set up yet — the Lambda currently has no third-party dependencies beyond `boto3` (provided by the runtime).
