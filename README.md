# URL Shortener: Terraform + GitHub Actions on AWS

A tiny serverless app whose real purpose is practising **Infrastructure as Code and CI/CD**.
It costs pennies a month at hobby traffic.

```
Browser ──► CloudFront ──► S3 (private, OAC)          frontend
Browser ──► API Gateway (HTTP API) ──► Lambda ──► DynamoDB   backend
GitHub Actions ──OIDC──► IAM roles (no stored AWS keys)
```

## Repo layout

| Path | What it is |
|---|---|
| `bootstrap/` | One-time setup run from your laptop: state bucket, GitHub OIDC, IAM roles, budget alert |
| `modules/` | Reusable modules: `dynamodb-table`, `lambda-api`, `static-site`, plus the `url-shortener` composition |
| `envs/dev`, `envs/prod` | Root modules, one state file each |
| `app/` | Python Lambda + pytest tests |
| `frontend/` | `index.html` template (API URL injected by Terraform) |
| `.github/workflows/` | `pr.yml`, `deploy.yml` (+ `_apply.yml`), `drift.yml`, `destroy.yml` |

## Pipeline

| Trigger | What runs |
|---|---|
| Pull request | fmt → validate → `terraform test` (unit, mocked) → tflint → Checkov → pytest → `plan` for dev & prod, posted as PR comments |
| Merge to `main` | tests → apply **dev** + smoke test → *(you approve)* → apply **prod** + smoke test |
| Weekly / manual | Integration test: real table + Lambda + API created, called, destroyed |
| Daily schedule | `plan -detailed-exitcode` on both envs; opens an issue if drift is found |
| Manual | `destroy` an environment (type its name to confirm) |

## One-time setup

**Prereqs:** Terraform ≥ 1.10, AWS CLI, an admin-capable login on your new account
(use an IAM Identity Center user or IAM user, not the root user).

1. **Create the GitHub repo** (public) and push this code to `main`.

2. **Bootstrap AWS** from your laptop:
   ```bash
   cd bootstrap
   cp terraform.tfvars.example terraform.tfvars   # fill in GitHub owner/repo + email
   terraform init
   terraform apply
   ```
   Confirm the AWS Budgets email subscription when it arrives.
   Keep `bootstrap/terraform.tfstate` safe (it's git-ignored).

3. **Repo variables** — *Settings → Secrets and variables → Actions → Variables* (these are ARNs, not secrets):
   - `TF_STATE_BUCKET` = output `tf_state_bucket`
   - `PLAN_ROLE_ARN` = output `plan_role_arn`

4. **Environments** — *Settings → Environments*:
   - `dev`: add variable `APPLY_ROLE_ARN` = `apply_role_arns["dev"]`
   - `prod`: add variable `APPLY_ROLE_ARN` = `apply_role_arns["prod"]`,
     tick **Required reviewers** (add yourself), and set **Deployment branches** to `main` only.

5. **Branch protection** — *Settings → Rules → New branch ruleset* for `main`:
   require a pull request and the status checks from `PR checks`.

6. Open a PR with any small change, watch the plan comments appear, merge, approve prod. 🎉
   The site URL shows on the Actions run summary and the Environments page.

## Cost notes

- Everything is on-demand: DynamoDB PAY_PER_REQUEST, Lambda (arm64, 128 MB), HTTP API, CloudFront `PriceClass_100`.
- Logs expire after 7 days; old state versions after 90 days.
- API is throttled (5 req/s, burst 10) so a public URL can't run up your bill.
- **Deliberately avoided:** NAT Gateway, load balancers, EKS, RDS, public IPv4 addresses.
- Tear down when you're not using it: run the **Destroy** workflow.

## Security notes (public repo)

- No AWS keys in GitHub. Roles trust only this repo, and:
  - the plan role: pull requests + `main` (read-only + state lock),
  - apply roles: only jobs running in the matching GitHub Environment.
- PRs from forks never receive OIDC tokens, and the plan job is skipped for them.
- Apply roles can't modify the `gha-*` roles themselves.
- Never commit `*.tfvars` with personal info or any `*.tfstate` (see `.gitignore`).

## Terraform tests

| Layer | Where | Real AWS? |
|---|---|---|
| Unit | `modules/*/tests/unit.tftest.hcl` (mocked provider, plan only) | No |
| Integration | `modules/lambda-api/tests/integration.tftest.hcl` | Yes – created and destroyed |
| Smoke | last step of `_apply.yml` (curl the live API and site) | Yes – live env |

```bash
cd modules/lambda-api
terraform init -backend=false
terraform test -filter=tests/unit.tftest.hcl         # free, no AWS login needed
terraform test -filter=tests/integration.tftest.hcl  # needs AWS credentials
```

If an integration run crashes midway, delete anything named `*-itest-*` by hand.

## Running locally

```bash
cd envs/dev
terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
terraform plan

pip install -r app/requirements-dev.txt && pytest app/tests
```

## Next exercises

1. Make Checkov blocking (`soft_fail: false`) and fix or `#checkov:skip` each finding with a reason.
2. Switch CloudFront to `CachingOptimized` and add an invalidation step to the deploy.
3. Add a custom domain (Route 53 + ACM in us-east-1).
4. Add click counts (DynamoDB `UpdateItem` + a `GET /stats/{code}` route).
5. Move `bootstrap` state into S3 (`backend "s3"` block + `terraform init -migrate-state`).
6. Add `infracost` to PR comments to show the cost of each change.
7. Publish `modules/static-site` as its own versioned module repo.
