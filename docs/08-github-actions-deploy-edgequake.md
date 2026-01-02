# GitHub Actions → Infra Dispatch (Option A)

High-signal, copy‑pasteable guide to implement the recommended CI/CD flow:
- Build & push images for `edgequake/` (backend) and `edgequake_webui/` (Next.js) in the `raphaelmansuy/edgequake` repo
- Push images to Artifact Registry (regional)
- Notify infra repo (`raphaelmansuy/gcp-cloud-graph-stack`) via `repository_dispatch` with image URLs
- Infra repo receives dispatch, runs Terraform plan → (optionally) apply using Workload Identity Federation (OIDC)

Quick ASCII overview (high signal):

  DEV PUSH / PR (edgequake repo)
      |
      | 1. GitHub Actions (build & test)
      v
  Build & Push Images -----------------> Artifact Registry
      |                                     |
      | 2. On success                        | 3. Images available
      v                                     v
  Send repository_dispatch (payload with image URLs) ---> gcp-cloud-graph-stack repo
                                                       |
                                                       | 4. GitHub Actions in infra repo (OIDC auth to GCP)
                                                       v
                                               Terraform plan (using image URLs)
                                                       |
                                                       | 5. Optional: manual approval or auto-apply
                                                       v
                                               Terraform apply -> Cloud Run/VM updated

Why this pattern
- Auditable: builds are in the app repo and the infrastructure changes are applied from a single, protected infra repo (clear audit trail). 
- Secure: no long lived keys; use GitHub OIDC to impersonate a GCP service account.
- Reproducible: images are tagged by SHA; rollbacks are easy (re-dispatch older tag).

---

## 1) Infrastructure prerequisites (GCP)

Commands below assume: `PROJECT=saas-app-001`, `REGION=us-central1`.

1. Create a GCP service account for CI (used by infra workflows):

```bash
gcloud iam service-accounts create edgequake-ci \
  --display-name "Edgequake CI Service Account" --project=${PROJECT}
```

2. Grant least-privilege roles required to deploy infra (adjust as needed):

```bash
# Artifact Registry for pushes
gcloud projects add-iam-policy-binding ${PROJECT} --member="serviceAccount:edgequake-ci@${PROJECT}.iam.gserviceaccount.com" --role="roles/artifactregistry.writer"

# Run & Compute & Storage for infra operations
gcloud projects add-iam-policy-binding ${PROJECT} --member="serviceAccount:edgequake-ci@${PROJECT}.iam.gserviceaccount.com" --role="roles/run.admin"
gcloud projects add-iam-policy-binding ${PROJECT} --member="serviceAccount:edgequake-ci@${PROJECT}.iam.gserviceaccount.com" --role="roles/compute.admin"
gcloud projects add-iam-policy-binding ${PROJECT} --member="serviceAccount:edgequake-ci@${PROJECT}.iam.gserviceaccount.com" --role="roles/storage.admin"

# Allow the SA to be impersonated by GitHub OIDC
gcloud iam service-accounts add-iam-policy-binding \
  edgequake-ci@${PROJECT}.iam.gserviceaccount.com \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT}/locations/global/workloadIdentityPools/GITHUB_POOL/attribute.repository/raphaelmansuy/edgequake" \
  --role="roles/iam.workloadIdentityUser"
```

> Note: Use smaller, targeted roles if you can; these are examples that cover common needs for deploying Cloud Run and Compute resources.

3. Create a Workload Identity Pool and Provider (for GitHub OIDC):

```bash
# Create pool
gcloud iam workload-identity-pools create GITHUB_POOL \
  --project=${PROJECT} --location="global" --display-name="GitHub Actions pool"

# Create provider
gcloud iam workload-identity-pools providers create-oidc GITHUB_PROVIDER \
  --project=${PROJECT} --location="global" \
  --workload-identity-pool=GITHUB_POOL \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping='"google.subject=assertion.sub,attribute.repository=assertion.repository"'
```

4. Confirm and document the provider resource id to use in GitHub Actions (`projects/${PROJECT}/locations/global/workloadIdentityPools/GITHUB_POOL/providers/GITHUB_PROVIDER`).

---

## 2) Edgequake repo: build, push, dispatch workflow

Place this as `.github/workflows/build-and-push.yml` in `raphaelmansuy/edgequake`.

Important notes before using:
- Set repo secrets: `GCP_PROJECT` (saas-app-001), `REGION` (us-central1), and `INFRA_REPO_TOKEN` (a small-scope Personal Access Token that can send repository_dispatch to `raphaelmansuy/gcp-cloud-graph-stack` — `repo` scope required for repo dispatch). Alternatively, you can use a GitHub App for dispatching.

Example workflow (high signal):

```yaml
name: Build & Push Images
on:
  push:
    branches: [ main ]
    paths:
      - 'edgequake/**'
      - 'edgequake_webui/**'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read # for checkout
    env:
      PROJECT: ${{ secrets.GCP_PROJECT }}
      REGION: ${{ secrets.REGION }}
      REPO: 'raphaelmansuy/gcp-cloud-graph-stack'

    steps:
      - uses: actions/checkout@v4

      - name: Set up Google Cloud auth (OIDC)
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: 'projects/${{ secrets.GCP_PROJECT }}/locations/global/workloadIdentityPools/GITHUB_POOL/providers/GITHUB_PROVIDER'
          service_account: 'edgequake-ci@${{ secrets.GCP_PROJECT }}.iam.gserviceaccount.com'

      - name: Configure Docker for Artifact Registry
        run: |
          gcloud auth configure-docker ${REGION}-docker.pkg.dev

      - name: Build Next.js image
        run: |
          docker build -t ${REGION}-docker.pkg.dev/${PROJECT}/edgequake-images/nextjs:${{ github.sha }} -f edgequake_webui/Dockerfile .

      - name: Push Next.js image
        run: |
          docker push ${REGION}-docker.pkg.dev/${PROJECT}/edgequake-images/nextjs:${{ github.sha }}

      - name: Build Rust API image
        run: |
          docker build -t ${REGION}-docker.pkg.dev/${PROJECT}/edgequake-images/rust-api:${{ github.sha }} -f edgequake/Dockerfile .

      - name: Push Rust API image
        run: |
          docker push ${REGION}-docker.pkg.dev/${PROJECT}/edgequake-images/rust-api:${{ github.sha }}

      - name: Notify infra repo (repository_dispatch)
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.INFRA_REPO_TOKEN }}  # PAT with repo scope
          repository: ${{ env.REPO }}
          event-type: new-image
          client-payload: |
            {
              "nextjs_image": "${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT }}/edgequake-images/nextjs:${{ github.sha }}",
              "rust_image": "${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT }}/edgequake-images/rust-api:${{ github.sha }}",
              "source_commit": "${{ github.sha }}"
            }
```

Security note: using `INFRA_REPO_TOKEN` (a PAT) is needed because `GITHUB_TOKEN` cannot trigger workflows in other repos. Create an account with minimal scope if possible and store the PAT in repository secrets.

---

## 3) Infra repo: receive dispatch + terraform plan/apply workflow

Place this as `.github/workflows/deploy-on-dispatch.yml` in `gcp-cloud-graph-stack`.

Security model:
- This job uses OIDC to authenticate as `edgequake-ci@${PROJECT}.iam.gserviceaccount.com` in GCP and runs `terraform plan` / `terraform apply`.
- Because an infra `apply` is potentially dangerous, include an `approval` step (manual `workflow_run` or require `manual_approval` via GitHub Environments) for production.

High-signal workflow:

```yaml
name: Deploy on Image Dispatch
on:
  repository_dispatch:
    types: [ new-image ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Parse payload
        id: payload
        run: |
          echo "NEXTJS_IMAGE=$(jq -r .nextjs_image "$GITHUB_EVENT_PATH")" >> $GITHUB_ENV
          echo "RUST_IMAGE=$(jq -r .rust_image "$GITHUB_EVENT_PATH")" >> $GITHUB_ENV
          echo "SOURCE_COMMIT=$(jq -r .source_commit "$GITHUB_EVENT_PATH")" >> $GITHUB_ENV

      - name: Authenticate to GCP (OIDC)
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: 'projects/${{ secrets.GCP_PROJECT }}/locations/global/workloadIdentityPools/GITHUB_POOL/providers/GITHUB_PROVIDER'
          service_account: 'edgequake-ci@${{ secrets.GCP_PROJECT }}.iam.gserviceaccount.com'

      - name: Setup gcloud and terraform
        run: |
          gcloud config set project ${{ secrets.GCP_PROJECT }}
          cd terraform
          terraform init -backend-config="bucket=${{ secrets.GCP_PROJECT }}-tf-state" -backend-config="prefix=terraform/state"

      - name: Terraform plan (with new images)
        working-directory: ./terraform
        run: |
          terraform plan -var="nextjs_image_url=${NEXTJS_IMAGE}" -var="rust_api_image_url=${RUST_IMAGE}" -out=tfplan-${{ env.SOURCE_COMMIT }}

      - name: Upload plan as artifact
        uses: actions/upload-artifact@v4
        with:
          name: tfplan-${{ env.SOURCE_COMMIT }}
          path: terraform/tfplan-${{ env.SOURCE_COMMIT }}

      - name: Apply (AUTO_APPLY)
        if: ${{ env.AUTO_APPLY == 'true' }}
        working-directory: ./terraform
        run: |
          terraform apply -auto-approve tfplan-${{ env.SOURCE_COMMIT }}
```

Operational note: For production workflows, set `AUTO_APPLY` from GitHub environment or require workflow-level approvals. You can also create a pull request that updates `terraform.tfvars` (with the image URLs), and have human reviewers approve & merge to `main` which runs the infra apply.

---

## 4) Terraform changes (infra repo)

1. Accept image URLs as variables in `terraform/variables.tf`:

```hcl
variable "nextjs_image_url" { type = string }
variable "rust_api_image_url" { type = string }
```

2. Wire them into your Cloud Run module calls:

```hcl
module "cloud_run_nextjs" {
  source = "./modules/cloud_run"
  image_url = var.nextjs_image_url
  # ... other args
}

module "cloud_run_rust_api" {
  source = "./modules/cloud_run"
  image_url = var.rust_api_image_url
  # ... other args
}
```

3. Make image updates manageable:
- Remove or make configurable the `lifecycle { ignore_changes = [template[0].spec[0].containers[0].image] }` in `modules/cloud_run/main.tf` so Terraform will update the service when the image variable changes.

Example change (cloud_run module):
```hcl
variable "allow_image_update" { type = bool, default = true }

# then conditionally include ignore_changes only when false
lifecycle {
  ignore_changes = var.allow_image_update ? [] : [template[0].spec[0].containers[0].image]
}
```

This lets you control whether image changes are pushed via Terraform or via `gcloud run deploy` in CI.

---

## 5) Rollback & recovery

- To rollback to previous image, dispatch again with the older image tag (re-dispatch an artifact or use `repository_dispatch` with previous tag). The infra workflow will `plan` and you can `apply` the older tag.
- Alternatively: update `terraform` variables to the known-good tag and apply.
- Always keep images tagged by commit SHA and optionally maintain `stable` tags for releases.

---

## 6) Verification checklist (high-signal)

- [ ] edgequake repo has `.github/workflows/build-and-push.yml` configured with OIDC + PAT for dispatch
- [ ] artifact pushed to Artifact Registry under `edgequake-images/` with commit SHA
- [ ] infra repo has `.github/workflows/deploy-on-dispatch.yml` listening for `new-image`
- [ ] `terraform` variables `nextjs_image_url` / `rust_api_image_url` exist and are used to deploy Cloud Run
- [ ] `edgequake-ci` SA has appropriate roles and WIF binding; provider configured in GitHub Actions
- [ ] Test: push to `main` (or force-dispatch) and confirm plan, then apply

---

## References
- Workload Identity Federation: https://cloud.google.com/iam/docs/workload-identity-federation
- GitHub OIDC docs: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- Artifact Registry docs: https://cloud.google.com/artifact-registry/docs
- Terraform Cloud Run resource: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service

---

If you'd like, I can:
- Create the two example workflows in the `edgequake` repo (build/push + dispatch),
- Create the dispatch receiver workflow in this infra repo and wire it to the current Terraform configuration (and add a safety approval step),
- Or create a PR template and README snippets to guide release engineers.

Tell me which one to do first and I'll implement it and open a PR.
