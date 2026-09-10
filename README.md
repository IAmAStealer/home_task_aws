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

GitHub Actions, authenticated to AWS via OIDC (no stored long-lived keys, see `oidc.tf`) with a separate least-privilege deploy role per environment. The deploy logic lives once in a reusable workflow (`.github/workflows/deploy.yml`, `on: workflow_call`) parameterized by `environment`, and is called twice from `.github/workflows/main.yml` to avoid duplicating the same steps for staging and prod:

- **`security-checks`** (every push to `main`): `terraform validate`, `tfsec` (IaC security scan), `pip-audit` on the Lambda's dependencies. Gates both deploy jobs below.
- **`deploy-staging`**: runs automatically on push to `main`, calls `deploy.yml` with `environment: staging`.
- **`deploy-prod`**: `needs: [security-checks, deploy-staging]` — only queued after staging has succeeded, then calls `deploy.yml` with `environment: prod`. This job targets the GitHub **`prod` environment**, which has required reviewers configured — the run pauses there until someone approves it in the Actions tab. This is the manual approval gate for prod (no `workflow_dispatch` needed anymore).

Both `staging` and `prod` are set up as GitHub **Environments** (Settings → Environments), each holding its own `DEPLOY_ROLE_ARN`/`REGION` environment variables (same variable names, scoped per environment, resolved automatically by whichever job declares `environment: <name>`) — only `prod` has required reviewers enabled. See the Bootstrap section above for why the very first `apply` still has to be run locally.

## Design choices / assumptions

- **Security-first build order**: the KMS key was deliberately built and wired in *before* any other resource (DynamoDB, IAM, Lambda). Every resource that touches data (DynamoDB, and its consumer's IAM role) was designed against the encryption layer from the start. This mirrors a "security by design" approach.
- **DynamoDB encryption**: uses a customer-managed KMS key (CMK) rather than the AWS-owned default, satisfying both the base SSE requirement and the bonus "customer managed key" item. Key rotation is enabled.
- **IAM**: three distinct roles — one for the Lambda execution (least privilege, scoped to the exact table/log group/key ARNs), one for CI/CD deployment (OIDC-federated, assumed by GitHub Actions for a specific repo/branch only, no stored AWS keys), and your own credentials for the one-time local bootstrap (see Bootstrap section above).
- **API Gateway payload format**: `payload_format_version = "2.0"` is used, giving the Lambda event a `requestContext.http.method` field rather than the older `httpMethod` field.
- **Validation scope**: the `payload` key check only applies to `POST` requests (a `GET /health` has no body to validate).
- **Logging vs. storage**: every request (valid or not) is logged to CloudWatch (`INFO` for valid, `WARN` for rejected) for audit/security visibility, but only successfully validated requests are written to DynamoDB — CloudWatch is the security/audit trail, DynamoDB is the functional data store. Some of those logged-but-rejected events may be worth forwarding to a security team's observability / threat detection tooling later on.
- **Stage**: uses the reserved `$default` stage name (no `/{stage}` segment in the URL) with `auto_deploy = true`, since staging and prod are already fully separate deployments (separate `terraform apply -var-file`, separate API Gateway resources).
- **Routes**: `GET /health` and `POST /health` are declared via a `for_each` over a small map, rather than duplicated resource blocks — the same pattern is used for the two `aws_lambda_permission` statements (one per method, least privilege on `source_arn`).
- **Terraform module**: the whole application stack (API Gateway, Lambda, DynamoDB, KMS, CloudWatch, and the Lambda's own IAM role) is factored into `modules/health-api/`, instantiated once from the root `main.tf` (`module "health_api"`). The root module keeps only what's shared/cross-cutting and can't sensibly live inside the app module: the GitHub Actions OIDC provider and deploy role (`oidc.tf`, `iam.tf`), which need the module's resource ARNs as outputs (see `modules/health-api/outputs.tf`) but aren't themselves part of the "health API" being shipped.
- **Not implemented (see `TODO.md` for details and rationale)**: DynamoDB TTL, KMS encryption of CloudWatch logs, Lambda in its own VPC, structured (field-level) logging, API Gateway-level request validation (the `payload` check is done in the Lambda, not via a JSON Schema model on the route), API key authentication. These were deliberately deprioritized to prioritize a complete, working, and testable core chain (KMS → DynamoDB → IAM → Lambda → API Gateway) over partially-implemented bonus items.
- **FinOps**: `region` is a per-environment variable (staging currently uses a cheaper region), and every resource carries `environment`/`application` tags for cost tracking. Basic, but a base to build on.

## Known limitations

### Known tfsec findings (deliberately not fixed)

The `security-checks` CI job runs tfsec, and it flags a few things that are known, considered, and deliberately deferred rather than silently ignored:

- **`logs:CreateLogStream`/`PutLogEvents` on a wildcarded resource** (`modules/health-api/iam.tf`) — CloudWatch Logs stream names are generated dynamically by AWS and can't be enumerated in advance, so a trailing `:*` on the log group ARN is the standard way to scope this permission. For reference, AWS's own `AWSLambdaBasicExecutionRole` managed policy uses a full `Resource: "*"` for these same actions across every log group in the account — this project's version, scoped to one specific log group, is already stricter than that default. Suppressed with `#tfsec:ignore:aws-iam-no-policy-wildcards`.
- **`kms:ListAliases` on `Resource: "*"`** (root `iam.tf`, deploy role) — this action has no resource-level scoping in AWS's IAM model at all (there is no resource type to restrict it to), so `"*"` is the only valid value. Suppressed with `#tfsec:ignore:aws-iam-no-policy-wildcards`.
- **`aws-api-gateway-enable-access-logging`** (`modules/health-api/api_gateway.tf`) — API Gateway access logs (who called what, when) aren't set up. Not required by the assignment; would need its own log group + IAM wiring.
- **`aws-cloudwatch-log-group-customer-key`** (`modules/health-api/cloudwatch.tf`) — the Lambda's log group isn't encrypted with the project's KMS CMK (see "Not implemented" list above for why — needs a `logs.amazonaws.com` statement added to the key policy first).
- **`aws-lambda-enable-tracing`** (`modules/health-api/lambda.tf`) — AWS X-Ray tracing isn't enabled. Not required by the assignment; would add its own IAM permissions and a small runtime overhead.

DynamoDB Point-in-time recovery was flagged by the same scan and, unlike the above, was worth fixing rather than deferring (cheap, one block) — it's enabled in `modules/health-api/dynamodb.tf`.
