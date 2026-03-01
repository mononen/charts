# New Project Standup Guide

A step-by-step guide for DevOps engineers standing up a new project using the Mosaic Helm chart library and pipeline library. This walks you through everything from intake to first deployment.

**Prerequisites**: You have already gathered the information in [NEW_PROJECT_INTAKE.md](./NEW_PROJECT_INTAKE.md) from the dev team.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Before You Start](#2-before-you-start)
3. [Step 1: Create the Repository Structure](#step-1-create-the-repository-structure)
4. [Step 2: Set Up the Helm Chart](#step-2-set-up-the-helm-chart)
5. [Step 3: Configure Environment Overrides](#step-3-configure-environment-overrides)
6. [Step 4: Set Up the CI/CD Pipeline](#step-4-set-up-the-cicd-pipeline)
7. [Step 5: Platform-Specific Setup](#step-5-platform-specific-setup)
8. [Step 6: First Deployment](#step-6-first-deployment)
9. [Common Patterns & Recipes](#common-patterns--recipes)
10. [Troubleshooting](#troubleshooting)
11. [Quick Reference](#quick-reference)

---

## 1. Overview

Every Mosaic project uses two shared libraries:

| Library | What It Does |
|---------|-------------|
| **common-library-chart** | Helm library chart. Generates all Kubernetes resources (Deployments, Services, Ingresses, HPAs, etc.) from a single `values.yaml`. |
| **build-libraries** | CI/CD pipeline library. Handles container builds, chart packaging, versioning, and multi-environment deployments from a single `pipeline-config.yml`. |

A typical project ends up with:
- A `values.yaml` that describes the application's Kubernetes footprint
- Per-environment override files (e.g., `int.yaml`, `prd.yaml`)
- A `pipeline-config.yml` that describes how to build and deploy it
- A 2-line Jenkinsfile or a templated `bitbucket-pipelines.yml`

That's it. The libraries handle everything else.

---

## 2. Before You Start

Make sure you have:

- [ ] Completed the [intake checklist](./NEW_PROJECT_INTAKE.md) with the dev team
- [ ] Access to the Bitbucket repository
- [ ] Access to Harbor registry (`registry.moslrn.net`)
- [ ] The AWS ACM certificate ARN for the project's domain
- [ ] The Teams webhook URL for notifications
- [ ] Kubernetes namespace created in target clusters (or permission to create it)
- [ ] Harbor project created for the client (e.g., `ptsi/` in the registry)

---

## Step 1: Create the Repository Structure

In the project's Git repository, create the following directory structure:

```
repo-root/
├── .ci/
│   ├── chart/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── resources.yaml
│   └── config/
│       ├── int.yaml          # Integration overrides
│       ├── stg.yaml          # Staging overrides
│       └── prd.yaml          # Production overrides
├── docker/
│   ├── app/
│   │   └── Dockerfile
│   └── nginx/                # (if applicable)
│       └── Dockerfile
├── pipeline-config.yml
├── Jenkinsfile               # (if using Jenkins)
└── bitbucket-pipelines.yml   # (if using Bitbucket Pipelines)
```

**Key conventions:**
- Chart lives in `.ci/chart/` (this is the default `chartPath`)
- Environment overrides live in `.ci/config/`
- Dockerfiles live in `docker/<component>/`
- Pipeline config lives at the repo root

---

## Step 2: Set Up the Helm Chart

### 2a. Chart.yaml

Create `.ci/chart/Chart.yaml`:

```yaml
apiVersion: v2
name: <project-name>
description: Helm chart for <Project Display Name>
type: application
version: 0.1.0
appVersion: "0.1.0"

dependencies:
  - name: common-library-chart
    version: "1.0.0"
    repository: "oci://registry.moslrn.net/library/charts"
```

Replace `<project-name>` with the chart name (e.g., `ptsi-lms`, `acme-portal`).

### 2b. templates/resources.yaml

Create `.ci/chart/templates/resources.yaml` with exactly one line:

```yaml
{{- include "common.all" . }}
```

This single line tells the library chart to generate all Kubernetes resources from your `values.yaml`. You should not need any other template files.

### 2c. values.yaml (Base Configuration)

Create `.ci/chart/values.yaml`. This is the main file that describes your entire application. Here's a complete, annotated template:

```yaml
global:
  # -----------------------------------------------------------------------
  # Identity — from intake sections 1 & 2
  # -----------------------------------------------------------------------
  clientCode: "<client-code>"        # e.g., ptsi, acme
  project: "<project-name>"          # e.g., lms, portal
  env: dev                           # Default env (overridden per environment)
  namespace: "<namespace>"           # Usually matches clientCode

  # -----------------------------------------------------------------------
  # Networking — from intake section 2
  # -----------------------------------------------------------------------
  domain: "<domain>"                 # e.g., example.com
  certificateARN: "<cert-arn>"       # AWS ACM certificate ARN

  # ALB prefix — defaults to clientCode if omitted
  alb:
    prefix: "<client-code>"

  # -----------------------------------------------------------------------
  # Image defaults
  # -----------------------------------------------------------------------
  imageDefaults:
    registry: registry.moslrn.net
    pullPolicy: IfNotPresent
    pullSecrets:
      - name: harbor                 # MUST be 'harbor', not 'registry-secret'

# =========================================================================
# Components — from intake section 4
# =========================================================================
# Define one block per application component (api, frontend, worker, etc.)
# The key name becomes part of the resource names.

components:
  # -----------------------------------------------------------------------
  # Example: API component (Deployment + Service + Ingress)
  # -----------------------------------------------------------------------
  api:
    enabled: true

    containers:
      - name: api
        image:
          repository: <client>/<project>/api   # e.g., ptsi/lms/api
          # tag is set automatically during deployment — don't hardcode it
        ports:
          - name: http
            containerPort: 8080                # From intake section 4
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: "1"
            memory: 512Mi
        # Health checks — from intake section 5
        readinessProbe:
          httpGet:
            path: /health                      # ALB healthcheck inherits this automatically
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 15
          periodSeconds: 20

    service:
      port: 80
      targetPort: http

    ingress:
      # subdomain defaults to the component name (e.g., "api")
      # Result: api.dev.example.com (non-prod), api.example.com (prod)
      internal:
        enabled: true                          # Internal ALB — on by default
      external:
        enabled: false                         # External ALB — off by default
        # Set to true for public-facing components (from intake section 2)

    autoscaling:
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 80

  # -----------------------------------------------------------------------
  # Example: Frontend / SPA (same as API but different port/image)
  # -----------------------------------------------------------------------
  # frontend:
  #   enabled: true
  #   containers:
  #     - name: nginx
  #       image:
  #         repository: <client>/<project>/nginx
  #       ports:
  #         - name: http
  #           containerPort: 80
  #       readinessProbe:
  #         httpGet:
  #           path: /healthz
  #           port: http
  #   service:
  #     enabled: true
  #     port: 80
  #     targetPort: http
  #   ingress:
  #     internal:
  #       enabled: true
  #     external:
  #       enabled: true           # Public-facing

  # -----------------------------------------------------------------------
  # Example: Background Worker (Deployment only — no Service or Ingress)
  # -----------------------------------------------------------------------
  # worker:
  #   enabled: true
  #   generate:
  #     service: false
  #     ingress: false
  #   containers:
  #     - name: worker
  #       image:
  #         repository: <client>/<project>/worker
  #       command: ["python", "worker.py"]
  #       resources:
  #         requests:
  #           cpu: 500m
  #           memory: 512Mi
  #         limits:
  #           cpu: "2"
  #           memory: 1Gi
```

### Important Rules for values.yaml

1. **Image tags**: Never hardcode image tags. The pipeline sets them during deployment via `--set`.
2. **Pull secret**: Must be `harbor`, not `registry-secret`.
3. **Healthcheck path**: Define it in `readinessProbe.httpGet.path` and the ALB healthcheck inherits it automatically. No need to set `healthcheckPath` separately.
4. **ALB ingress values**: Discover `loadBalancerName`, `groupName`, and `securityGroups` from existing ingresses in the target cluster using the Kubernetes MCP tool. See `references/ALB_INGRESS_CONFIG.md` for the discovery procedure.
5. **External ingress**: Off by default. Lower environments (sbx, int, stg) should remain internal-only. For production, explicitly ask which components need external (internet-facing) access.
6. **Subdomain**: Defaults to the component name. Only set `ingress.subdomain` if you need something different.

---

## Step 3: Configure Environment Overrides

Create one override file per environment in `.ci/config/`. These files use Helm's value merging — they only need to contain values that **differ** from the base `values.yaml`.

### Critical Rule: Never Override Arrays

Helm **replaces** arrays entirely on merge — it does not merge them. This means you should **never** redefine `containers`, `ports`, `env`, or any array in override files. Only override scalar values.

### int.yaml (Integration)

```yaml
# .ci/config/int.yaml
global:
  env: int
  certificateARN: "<int-cert-arn>"   # Only if different from base
```

### stg.yaml (Staging)

```yaml
# .ci/config/stg.yaml
global:
  env: stg
  certificateARN: "<stg-cert-arn>"

components:
  api:
    autoscaling:
      minReplicas: 2
      maxReplicas: 5
```

### prd.yaml (Production)

```yaml
# .ci/config/prd.yaml
global:
  env: prd
  certificateARN: "<prd-cert-arn>"

components:
  api:
    autoscaling:
      minReplicas: 3
      maxReplicas: 20
      targetCPUUtilizationPercentage: 70
```

### What Typically Changes Per Environment

| Setting | int | stg | prd |
|---------|-----|-----|-----|
| `global.env` | `int` | `stg` | `prd` |
| `certificateARN` | Same or different per AWS account | | |
| `autoscaling.minReplicas` | 1-2 | 2 | 3+ |
| `autoscaling.maxReplicas` | 3-5 | 5-10 | 10-50 |
| Environment variables | Dev URLs, debug flags | Staging URLs | Production URLs |

---

## Step 4: Set Up the CI/CD Pipeline

### 4a. pipeline-config.yml

Create `pipeline-config.yml` at the repository root. This file drives all CI/CD behavior.

```yaml
# Pipeline Configuration
project:
  name: <client-code>                                    # e.g., ptsi
  chart: <chart-name>                                    # e.g., ptsi-lms (matches Chart.yaml name)
  repository: bitbucket.org/MosaicLearning/<repo>.git    # Git repo URL
  registry: registry.moslrn.net                          # Container registry
  chartPath: .ci/chart                                   # Path to Helm chart
  v2: true                                               # Use v2 chart spec

# Docker images to build — one entry per Dockerfile
# From intake section 3
images:
  - name: <client>/<project>/<component>     # e.g., ptsi/lms/api
    dockerfile: ./docker/app                  # Path to Dockerfile directory
    target: prod                              # Multi-stage build target (if applicable)
    platform: linux/amd64
    # buildArgs:                              # Build arguments (if applicable)
    #   NODE_VERSION: "20"

# Enable parallel builds if you have 2+ images
build:
  container:
    parallel: true                            # STRONGLY recommended for multi-image projects

# Environments — from intake section 6
environments:
  - name: int
    displayName: Integration
    type: testing
    branch: dev                               # Which branch triggers this deployment
    account: govcloud                         # AWS account (govcloud | sdprod | combobulate)
    namespace: <namespace>
    valuesFile: .ci/config/int.yaml
    notifications:
      enabled: true
      onSuccess: true
      onFailure: true

  - name: stg
    displayName: Staging
    type: staging
    branches:
      - main
      - hotfix/.*
    account: govcloud
    namespace: <namespace>
    valuesFile: .ci/config/stg.yaml
    notifications:
      enabled: true
      onSuccess: false
      onFailure: true
    approval:
      enabled: true
      message: "Release Candidate {VERSION} deployed to Staging"
      okText: "Promote to Production"

  - name: prd
    displayName: Production
    type: production
    branches:
      - main
      - hotfix/.*
    account: govcloud
    namespace: <namespace>
    valuesFile: .ci/config/prd.yaml
    notifications:
      enabled: true
      onSuccess: true
      onFailure: true
    tagging:
      enabled: true                           # Git-tag production releases

# Notifications — from intake section 12
notifications:
  office365:
    url: <teams-webhook-url>
```

### Key Configuration Notes

**Accounts** — There are three pre-configured AWS accounts in `global-config.yml`:

| Account Name | Region | Purpose | Clusters |
|-------------|--------|---------|----------|
| `govcloud` | us-gov-east-1 | GovCloud workloads | govcloud-sbx, govcloud-int, govcloud-stg, govcloud-prd |
| `sdprod` | us-east-1 | Commercial AWS | sbx, int, stg, prd |
| `combobulate` | us-east-1 | Cross-account | dev, stg, prd |

You reference these by name in the `account` field. The library automatically looks up the region, cluster name, and authentication method.

**Branch → Environment mapping**: Each environment watches one or more branches. When a commit lands on that branch, the pipeline deploys to that environment.

| Branch | Typical Environment |
|--------|-------------------|
| `dev` | Integration (auto-deploy) |
| `main` | Staging (manual gate) → Production (manual gate) |
| `hotfix/.*` | Staging → Production |
| `sandbox/main` | Sandbox (auto-deploy) |

**What you don't need to configure** — these are inherited from `global-config.yml`:
- BuildKit addresses and TLS paths
- S3 cache settings
- Versioning strategy and markers
- Default branch patterns for builds
- Credential IDs
- Default notification settings

---

## Step 5: Platform-Specific Setup

### Option A: Jenkins

Create a `Jenkinsfile` at the repo root:

```groovy
@Library('helpers@3.0.0') _
standardPipeline()
```

That's it. Two lines. The library reads `pipeline-config.yml` and handles everything.

**Jenkins prerequisites:**
- The `helpers` shared library is configured in Jenkins (pointing to the build-libraries repo)
- Jenkins credentials are set up: `harbor`, `bitbucket-mlsoftware`, `jenkins-ssh-key`
- Jenkins agent label matches (default: `k8s-agent`)

### Option B: Bitbucket Pipelines

Create `bitbucket-pipelines.yml` at the repo root:

```yaml
image: registry.moslrn.net/library/build-lib-ctr:latest

clone:
  depth: full

definitions:
  caches:
    helm: ~/.cache/helm

  steps:
    - step: &execute-pipeline
        name: Execute Standard Pipeline
        caches:
          - helm
        script:
          - execute-pipeline.sh
        artifacts:
          - "*.tgz"
          - helm-test-results.xml

    - step: &build-containers
        name: Build Container Images
        runs-on:
          - self.hosted
          - ops
          - kubernetes
        runtime:
          self-hosted:
            volumes:
              - "/tmp/buildkit-ca:/tmp/buildkit-ca:ro"
              - "/tmp/buildkit-client-certs:/tmp/buildkit-client-certs:ro"
              - "/tmp/docker-config:/root/.docker:ro"
        script:
          - execute-pipeline.sh --stage container-build

    - step: &deploy-int
        name: Deploy to Integration
        deployment: integration
        script:
          - execute-pipeline.sh --stage deploy-int

    - step: &deploy-stg
        name: Deploy to Staging
        deployment: staging
        trigger: manual
        script:
          - execute-pipeline.sh --stage deploy-stg

    - step: &deploy-prd
        name: Deploy to Production
        deployment: production
        trigger: manual
        script:
          - execute-pipeline.sh --stage deploy-prd

pipelines:
  pull-requests:
    '**':
      - step:
          <<: *execute-pipeline
          name: Run Tests & Validate

  branches:
    main:
      - step: *build-containers
      - step: *execute-pipeline
      - step: *deploy-stg
      - step: *deploy-prd

    dev:
      - step: *build-containers
      - step: *execute-pipeline
      - step: *deploy-int

options:
  max-time: 120
  size: 2x
```

**Bitbucket prerequisites:**
- The `build-lib-ctr` image is accessible from your runners
- Self-hosted runners have the BuildKit volume mounts configured
- Deployment environments are created in Bitbucket settings: `integration`, `staging`, `production`
- Repository variables are set if not using Pod Identity:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - GovCloud: `GOVCLOUD_AWS_ACCESS_KEY_ID`, `GOVCLOUD_AWS_SECRET_ACCESS_KEY`

**Adjust the branch/step definitions** to match the environments in your `pipeline-config.yml`. Add or remove deploy steps as needed (e.g., add `&deploy-sbx` for a sandbox environment).

---

## Step 6: First Deployment

### 1. Update Helm dependencies

```bash
cd .ci/chart
helm dependency update
```

This downloads the `common-library-chart` library. Commit the resulting `Chart.lock` file.

### 2. Validate locally (optional but recommended)

```bash
helm template test-release .ci/chart \
  -f .ci/config/int.yaml \
  --set global.imageDefaults.tag=test
```

Review the output. You should see Deployments, Services, Ingresses, HPAs, PDBs, and ServiceAccounts generated for each component.

### 3. Push and watch

```bash
git add -A
git commit -m "Initial chart and pipeline configuration"
git push origin dev
```

The pipeline will:
1. Calculate a version (e.g., `0.1.0-alpha.1`)
2. Build container images (and push to Harbor)
3. Package the Helm chart (and push to Harbor)
4. Deploy to the integration environment
5. Send a Teams notification

### 4. Verify the deployment

```bash
# Check pods
kubectl -n <namespace> get pods

# Check ingress
kubectl -n <namespace> get ingress

# Check ALB target health (AWS console or CLI)
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

---

## Common Patterns & Recipes

### Multi-Container Component (e.g., PHP + Nginx)

```yaml
components:
  web:
    enabled: true
    containers:
      - name: php
        image:
          repository: ptsi/lms/moodle/php
        ports:
          - name: php-fpm
            containerPort: 9000
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: "2"
            memory: 1Gi
      - name: nginx
        image:
          repository: ptsi/lms/moodle/nginx
        ports:
          - name: http
            containerPort: 80
        readinessProbe:
          httpGet:
            path: /healthz
            port: http
    service:
      port: 80
      targetPort: http        # Points to nginx
```

### Database Migration Job (Helm Hook)

```yaml
components:
  migrate:
    enabled: true
    generate:
      deployment: false
      service: false
      ingress: false
    jobs:
      - name: migrate
        hook: "pre-install,pre-upgrade"
        hookWeight: "-5"
        containers:
          - name: migrate
            image:
              repository: ptsi/lms/api
            command: ["python", "manage.py", "migrate"]
            env:
              - name: DATABASE_URL
                valueFrom:
                  secretKeyRef:
                    name: db-credentials
                    key: url
        restartPolicy: Never
        backoffLimit: 3
```

### Init Container (Migration Before App Starts)

```yaml
components:
  api:
    initContainers:
      - name: migrate
        image:
          repository: ptsi/lms/api
        command: ["python", "manage.py", "migrate"]
        env:
          - name: DATABASE_URL
            valueFrom:
              secretKeyRef:
                name: db-credentials
                key: url
    containers:
      - name: api
        # ... normal container spec
```

### CronJob

```yaml
components:
  cleanup:
    enabled: true
    generate:
      deployment: false
      service: false
      ingress: false
    cronjobs:
      - name: cleanup
        schedule: "0 2 * * *"           # 2 AM daily
        concurrencyPolicy: Forbid
        containers:
          - name: cleanup
            image:
              repository: ptsi/lms/api
            command: ["python", "cleanup.py"]
        restartPolicy: OnFailure
```

### External Secrets (Doppler)

```yaml
components:
  api:
    containers:
      - name: api
        envFrom:
          - secretRef:
              name: doppler-secrets     # Managed by ExternalSecrets operator
```

### Alloy Logging Sidecar

```yaml
components:
  api:
    generate:
      logging: true
    logging:
      logTargets:
        - name: app-logs
          jobs:
            - name: app
              sidecarLogfile: /var/log/app/application.log
              autoConfigure: true
    volumes:
      - name: log-volume
        emptyDir: {}
    containers:
      - name: api
        volumeMounts:
          - name: log-volume
            mountPath: /var/log/app
```

### Custom Build Arguments in Pipeline

```yaml
# pipeline-config.yml
images:
  - name: ptsi/lms/api
    dockerfile: ./docker/app
    target: prod
    buildArgs:
      NODE_VERSION: "20"
      BUILD_ENV: "production"
```

### Sandbox Environment

Add to `pipeline-config.yml`:

```yaml
environments:
  - name: sbx
    displayName: Sandbox
    type: testing
    branch: sandbox/main
    account: govcloud
    namespace: <namespace>
    valuesFile: .ci/config/sbx.yaml
```

Add to `bitbucket-pipelines.yml`:

```yaml
    - step: &deploy-sbx
        name: Deploy to Sandbox
        deployment: sandbox
        script:
          - execute-pipeline.sh --stage deploy-sbx
```

---

## Troubleshooting

### "Image pull error" / ImagePullBackOff

- Verify the `harbor` pull secret exists in the namespace: `kubectl -n <ns> get secret harbor`
- Verify `pullSecrets` in `values.yaml` uses `name: harbor` (not `registry-secret`)
- Verify the image name and tag are correct: `kubectl -n <ns> describe pod <pod>`

### ALB not routing traffic

- Check the ALB target group health in AWS console
- Verify the healthcheck path matches what the app responds to
- Confirm the `readinessProbe` is defined — the ALB healthcheck path is auto-inherited from it
- Check the pod is passing its readiness probe: `kubectl -n <ns> describe pod <pod>`

### Helm upgrade fails with "field is immutable"

- Usually caused by changing something Kubernetes doesn't allow on running resources (e.g., service type, volume claim size)
- May need to delete and recreate the resource

### Container build fails in Bitbucket

- Verify volume mounts are present on the build step (BuildKit certs)
- Check the runner has the BuildKit CA and client certs at `/tmp/buildkit-ca/` and `/tmp/buildkit-client-certs/`
- Check the Docker config exists at `/tmp/docker-config/config.json`

### "No matching environment" — pipeline skips deployment

- The current branch doesn't match any environment's `branch` or `branches` pattern
- Check your `pipeline-config.yml` branch patterns against the actual branch name

### Helm values not merging correctly

- Remember: Helm **replaces** arrays entirely. If your override file redefines `containers`, it will replace the base, not merge
- Only override scalar values (replicas, resource limits, env settings) in environment files
- Use `helm template` locally to verify the merged output

### Version not incrementing

- The library queries Harbor for the latest version. If Harbor is unreachable, versioning may fail
- Check that the image name in `pipeline-config.yml` matches the Harbor project path
- For major/minor bumps, include `%MAJOR_RELEASE%` or `%MINOR_RELEASE%` in your commit message

---

## Quick Reference

### File Locations

| File | Location | Purpose |
|------|----------|---------|
| `Chart.yaml` | `.ci/chart/Chart.yaml` | Chart definition + library dependency |
| `values.yaml` | `.ci/chart/values.yaml` | Base Kubernetes configuration |
| `resources.yaml` | `.ci/chart/templates/resources.yaml` | One-liner that invokes the library |
| `int.yaml` etc. | `.ci/config/<env>.yaml` | Per-environment overrides |
| `pipeline-config.yml` | repo root | CI/CD configuration |
| `Jenkinsfile` | repo root | Jenkins entry point (2 lines) |
| `bitbucket-pipelines.yml` | repo root | Bitbucket entry point |

### Host Name Generation

| Environment | Pattern | Example |
|-------------|---------|---------|
| Non-production | `{subdomain}.{env}.{domain}` | `api.int.example.com` |
| Production | `{subdomain}.{domain}` | `api.example.com` |

### ALB Naming

| Type | Pattern | Example |
|------|---------|---------|
| Internal | `{prefix}-{env}-internal` | `ptsi-int-internal` |
| External | `{prefix}-{env}-external` | `ptsi-int-external` |

### Version Suffixes

| Branch | Suffix | Example |
|--------|--------|---------|
| `dev` | `-alpha.N` | `1.2.0-alpha.3` |
| `main` | `-rc.N` | `1.2.0-rc.1` |
| `hotfix/*` | `-rc.N` | `1.2.1-rc.1` |

### Commit Markers for Version Bumps

| Marker | Effect | When to Use |
|--------|--------|-------------|
| `%MAJOR_RELEASE%` | Bump major version | Breaking changes |
| `%MINOR_RELEASE%` | Bump minor version | New features |
| *(none)* | Bump patch version | Bug fixes, minor updates |

### What's Auto-Generated (Don't Configure These)

- ALB names, group names, and security groups (discovered from existing ingresses in target cluster via K8s MCP)
- Ingress host names
- ALB healthcheck path (from `readinessProbe`)
- Image tags (set during deployment)
- BuildKit configuration
- Registry credentials
- AWS region and cluster (from `account` lookup)
- Pod security contexts
- PodDisruptionBudgets
- HorizontalPodAutoscalers
- ServiceAccounts

---

## Checklist: Minimum Viable Project

For the fastest possible standup, you need exactly these files:

- [ ] `.ci/chart/Chart.yaml` — with library dependency
- [ ] `.ci/chart/templates/resources.yaml` — one-liner
- [ ] `.ci/chart/values.yaml` — components, ports, healthcheck, images
- [ ] `.ci/config/int.yaml` — at minimum one environment override
- [ ] `pipeline-config.yml` — project, images, environments, webhook
- [ ] `Jenkinsfile` or `bitbucket-pipelines.yml` — platform entry point
- [ ] Dockerfiles — one per buildable image

Everything else has sensible defaults or can be added incrementally.
