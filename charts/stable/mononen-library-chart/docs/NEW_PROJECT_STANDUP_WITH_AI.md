# New Project Standup — Using the AI Skills

How to stand up a new project by having the AI agent do the heavy lifting. This guide is for DevOps engineers who want to use the Cursor agent skills instead of building everything by hand.

For the manual reference version, see [NEW_PROJECT_STANDUP_GUIDE.md](./NEW_PROJECT_STANDUP_GUIDE.md).

---

## Table of Contents

1. [How It Works](#1-how-it-works)
2. [Before You Start](#2-before-you-start)
3. [Phase 1: Gather Intake Info](#phase-1-gather-intake-info)
4. [Phase 2: Generate the Helm Chart](#phase-2-generate-the-helm-chart)
5. [Phase 3: Generate the Pipeline](#phase-3-generate-the-pipeline)
6. [Phase 4: Review and Validate](#phase-4-review-and-validate)
7. [Phase 5: First Deployment](#phase-5-first-deployment)
8. [Post-Standup: Making Changes](#post-standup-making-changes)
9. [Skill Reference](#skill-reference)
10. [Tips for Good Results](#tips-for-good-results)

---

## 1. How It Works

There are six agent skills that cover the full lifecycle:

| Skill | When to Use |
|-------|-------------|
| **new-helm-chart** | Creating the Helm chart from scratch (Chart.yaml, values.yaml, templates, env configs) |
| **setup-pipeline** | Creating pipeline-config.yml, Jenkinsfile, and/or bitbucket-pipelines.yml from scratch |
| **modify-chart** | Adding features to an existing chart (ingress, sidecars, storage, CronJobs, secrets, etc.) |
| **modify-pipeline** | Adding features to an existing pipeline (images, environments, parallel builds, notifications, etc.) |
| **migrate-helm-chart** | Converting a legacy hand-rolled Helm chart to use the library |
| **migrate-pipeline** | Converting a legacy 300+ line Jenkinsfile to the 2-line library approach |

For a brand new project, you'll primarily use **new-helm-chart** and **setup-pipeline**. The agent picks them up automatically based on what you ask it to do.

---

## 2. Before You Start

**You need:**
- The project's Git repository cloned locally and open in Cursor
- The [intake checklist](./NEW_PROJECT_INTAKE.md) filled out (or at least the minimum viable info)
- Access to Harbor (`registry.moslrn.net`) and the target Kubernetes clusters

**The agent needs:**
- The skills installed in your Cursor workspace (they should already be at `~/.cursor/skills/`)
- Nothing else — it reads the skill files, the library references, and the global config automatically

---

## Phase 1: Gather Intake Info

Before talking to the agent, collect at least the **minimum viable intake** from the dev team:

1. **Client code** + **project name** (e.g., `acme` / `portal`)
2. **Git repo URL** (e.g., `bitbucket.org/MosaicLearning/acme-portal.git`)
3. **Domain** + **certificate ARN** (e.g., `acme.com` + `arn:aws:acm:...`)
4. **Docker images**: name, Dockerfile path, build target for each
5. **Container port(s)** (e.g., `8080`, `3000`)
6. **Healthcheck endpoint** (e.g., `/health`, `/healthz`)
7. **Environments**: names, branches, AWS account (`govcloud` / `sdprod` / `combobulate`)
8. **Teams webhook URL**

Everything else has sensible defaults. You can always add more later with the modify skills.

---

## Phase 2: Generate the Helm Chart

Open the project repo in Cursor and ask the agent to create the chart. Give it the intake info in natural language.

### Example Prompt

```
Create a new Helm chart for this project. Here's the info:

- Client code: acme
- Project: portal
- Namespace: acme
- Domain: acme.com
- Certificate ARN: arn:aws:acm:us-gov-east-1:123456789:certificate/abc-def-ghi

Components:
1. "api" - Node.js API server
   - Image: acme/portal/api
   - Dockerfile: ./docker/api, target: prod
   - Port: 3000
   - Health check: /api/health
   - Needs internal AND external ingress

2. "worker" - Background job processor
   - Image: acme/portal/worker
   - Dockerfile: ./docker/worker, target: prod
   - No ingress needed
   - No service needed

Environments: int (dev branch, govcloud), stg (main, govcloud), prd (main, govcloud)
```

### What the Agent Creates

The agent will use the **new-helm-chart** skill and generate:

| File | Contents |
|------|----------|
| `.ci/chart/Chart.yaml` | Chart definition with common-library-chart dependency |
| `.ci/chart/values.yaml` | Full component definitions with containers, services, ingress, probes, resources |
| `.ci/chart/templates/resources.yaml` | The one-liner `{{- include "common.all" . }}` |
| `.ci/config/int.yaml` | Integration environment overrides |
| `.ci/config/stg.yaml` | Staging environment overrides |
| `.ci/config/prd.yaml` | Production environment overrides |

### What to Check

After the agent finishes, verify:

- [ ] `values.yaml` has `global.imageDefaults.pullSecrets` set to `name: harbor`
- [ ] Image tags are empty (set during deployment, not hardcoded)
- [ ] `readinessProbe` is defined on components with ingress (ALB healthcheck auto-inherits)
- [ ] External ingress is only enabled on production for components that need it (lower envs default to internal-only)
- [ ] Environment override files only contain scalar overrides (no `containers` arrays)
- [ ] `global.env` is set correctly in each env file (`int`, `stg`, `prd`)

---

## Phase 3: Generate the Pipeline

Next, ask the agent to set up the CI/CD pipeline. Again, natural language with the intake info.

### Example Prompt

```
Set up the CI/CD pipeline for this project. Use Bitbucket Pipelines.

- Project name: acme
- Chart name: acme-portal
- Registry: registry.moslrn.net
- Repo: bitbucket.org/MosaicLearning/acme-portal.git

Images:
1. acme/portal/api - dockerfile: ./docker/api, target: prod
2. acme/portal/worker - dockerfile: ./docker/worker, target: prod

Environments:
- int: dev branch, govcloud, auto-deploy
- stg: main branch, govcloud, manual approval
- prd: main branch, govcloud, manual approval, git tagging

Teams webhook: https://outlook.office.com/webhook/abc123

Enable parallel builds (we have 2 images).
```

### What the Agent Creates

The agent will use the **setup-pipeline** skill and generate:

| File | Contents |
|------|----------|
| `pipeline-config.yml` | Project, images, environments, notifications |
| `bitbucket-pipelines.yml` | Step definitions, branch pipelines, volume mounts |

If you asked for Jenkins instead (or both):

| File | Contents |
|------|----------|
| `Jenkinsfile` | The 2-line standard pipeline entry point |

### Parallel Builds

If you have 2+ images and asked for parallel builds, the agent will:

1. Set `build.container.parallel: true` in `pipeline-config.yml`
2. Run `generate-parallel-pipeline.sh` to create the parallel step definitions
3. Update `bitbucket-pipelines.yml` with the generated parallel block

**Important**: The parallel pipeline YAML is generated by a script, not hand-written. The agent knows to run the script rather than try to generate the YAML itself.

### What to Check

- [ ] `pipeline-config.yml` uses `account` field (not raw region/cluster)
- [ ] Branch patterns match your Git workflow
- [ ] Staging and production have `trigger: manual` in `bitbucket-pipelines.yml`
- [ ] Production has `tagging.enabled: true` if you want git tags
- [ ] Volume mounts are present on the container build step (BuildKit certs)
- [ ] The Teams webhook URL is correct
- [ ] Build section only overrides what's needed (most settings come from `global-config.yml`)

---

## Phase 4: Review and Validate

Ask the agent to validate everything before you push.

### Example Prompt

```
Validate the chart and pipeline config. Run helm lint and template rendering.
```

The agent will run:

```bash
# Update library chart dependency
cd .ci/chart && helm dependency update

# Lint the chart
helm lint .

# Render templates to verify output
helm template test-release . -f ../config/int.yaml --set global.imageDefaults.tag=test

# Validate pipeline config syntax
yq eval pipeline-config.yml > /dev/null
```

Review the rendered template output. You should see resources generated for each component: Deployments, Services, Ingresses, HPAs, PDBs, ServiceAccounts.

---

## Phase 5: First Deployment

Once everything looks good:

1. **Commit and push to `dev`**:
   ```bash
   git add -A
   git commit -m "Initial chart and pipeline configuration"
   git push origin dev
   ```

2. **Watch the pipeline** in Bitbucket Pipelines (or Jenkins). It should:
   - Calculate version (e.g., `0.1.0-alpha.1`)
   - Build container images
   - Package and push the Helm chart
   - Deploy to integration
   - Send a Teams notification

3. **Verify in the cluster**:
   ```bash
   kubectl -n <namespace> get pods
   kubectl -n <namespace> get ingress
   kubectl -n <namespace> get svc
   ```

4. **Test the healthcheck endpoint** to confirm the ALB is routing correctly.

---

## Post-Standup: Making Changes

After initial standup, use the **modify** skills for incremental changes. Here are common follow-up tasks and how to ask for them:

### Adding a New Component

```
Add a CronJob component called "cleanup" that runs daily at 2 AM.
Image: acme/portal/api, command: ["node", "scripts/cleanup.js"]
```

The agent uses **modify-chart** to add the CronJob to `values.yaml`.

### Adding a New Docker Image to the Pipeline

```
Add a new image to the pipeline: acme/portal/nginx, dockerfile ./docker/nginx, no build target.
```

The agent uses **modify-pipeline** to add the image entry and update parallel builds if needed.

### Adding a Logging Sidecar

```
Enable the Alloy logging sidecar on the api component. The app writes logs to /var/log/app/application.log.
```

The agent uses **modify-chart** and follows the logging sidecar reference docs.

### Adding a New Environment

```
Add a sandbox environment. Branch: sandbox/main, account: govcloud, auto-deploy.
```

The agent uses **modify-pipeline** to add the environment to `pipeline-config.yml` and the deploy step to `bitbucket-pipelines.yml`, plus uses **modify-chart** to create `.ci/config/sbx.yaml`.

### Enabling External Ingress

```
Make the frontend component externally accessible (internet-facing) on production.
```

The agent uses **modify-chart** and the Kubernetes MCP tool to discover the external load balancer values from the production cluster, then sets `ingress.external.enabled: true` with the discovered values in `prd.yaml`.

### Adding Database Migrations

```
Add a pre-upgrade migration job for the api component. 
Command: ["python", "manage.py", "migrate"]. 
It needs the DATABASE_URL env var from the db-credentials secret.
```

The agent uses **modify-chart** to add a Helm hook Job.

---

## Skill Reference

### Which Skill Handles What

| Task | Skill | What It Reads |
|------|-------|---------------|
| New chart from scratch | **new-helm-chart** | Library values.yaml, VALUES_PATTERNS.md, ALB_INGRESS_CONFIG.md |
| New pipeline from scratch | **setup-pipeline** | global-config.yml, CONFIG_TEMPLATES.md, PROJECT_SETUP_PROCEDURES.md |
| Add component/ingress/sidecar/storage/CronJob | **modify-chart** | COMPONENT_EXAMPLES.md, ALB_INGRESS_CONFIG.md, LOGGING_SIDECARS.md |
| Add image/env/notifications/parallel builds | **modify-pipeline** | CONFIG_TEMPLATES.md, QUICK_REFERENCE.md |
| Convert legacy chart | **migrate-helm-chart** | VALUES_PATTERNS.md, TROUBLESHOOTING_CHARTS.md |
| Convert legacy Jenkinsfile | **migrate-pipeline** | EXTRACTION_PATTERNS.md, CONFIG_TEMPLATES.md |

### What the Skills Know Automatically

You don't need to tell the agent these things — the skills already encode them:

- Library chart OCI registry URL and version
- The `{{- include "common.all" . }}` template pattern
- ALB naming conventions (`{prefix}-{env}-internal/external`)
- **ALB ingress value discovery** — the agent uses the Kubernetes MCP tool to list existing ingresses in the target cluster, presents available load balancer names to you for selection, and automatically pulls the `groupName` and `securityGroups` from a matching ingress
- **External ingress defaults** — lower environments (sbx, int, stg) default to internal-only; the agent prompts you for which components need external access on production
- Host name generation (`{subdomain}.{env}.{domain}`)
- Healthcheck path auto-inheritance from probes
- Image pull secret must be `harbor`
- Never override arrays in environment configs
- AWS account lookup (govcloud, sdprod, combobulate) from global-config.yml
- Volume mounts required for BuildKit in Bitbucket
- Parallel build generation must use the script, not hand-written YAML
- Version suffix conventions (alpha, rc)

---

## Tips for Good Results

### Be Specific with Intake Data

The more concrete info you give the agent, the less you have to fix afterward. Instead of:

> "Create a chart for our app"

Say:

> "Create a chart for client code `acme`, project `portal`, domain `acme.com`. There's one component called `api` that listens on port 3000 with a health endpoint at `/health`. It needs internal ingress only."

### One Phase at a Time

Do the chart first, then the pipeline. Trying to do both in one prompt can lead to the agent losing context. The two-phase approach (chart, then pipeline) maps cleanly to the two skills and gives you a checkpoint in between.

### Review Env Override Files Carefully

The most common bug is arrays being redefined in environment config files. If you see `containers:` in any file under `.ci/config/`, flag it — that will break Helm merging. The skills know this rule, but it's worth double-checking.

### Use Modify Skills for Iteration

Don't try to get everything perfect on the first pass. Stand up the minimum viable project, deploy it, and then layer on features using the modify skills. This is faster and less error-prone than trying to specify everything upfront.

### For Migrations, Use the Migration Skills

If the project already has a Helm chart or Jenkinsfile, don't use the "new" skills. Use **migrate-helm-chart** and **migrate-pipeline** instead. They understand how to analyze existing configurations and transform them while preserving behavior.

---

## End-to-End Example

Here's a complete conversation flow for standing up a new project:

**You:** "I need to stand up a new project. Here's the intake info: [paste from intake checklist]"

**Agent:** Creates the Helm chart (Chart.yaml, values.yaml, templates, env configs).

**You:** "Looks good. Now set up the Bitbucket pipeline with parallel builds."

**Agent:** Creates pipeline-config.yml, runs the parallel generator script, creates bitbucket-pipelines.yml.

**You:** "Validate everything and show me the rendered templates."

**Agent:** Runs `helm dependency update`, `helm lint`, `helm template`, validates YAML syntax.

**You:** "Add a logging sidecar to the api component."

**Agent:** Uses modify-chart to add `generate.logging: true` and the logging configuration.

**You:** "The api also needs an external ingress for the public endpoint."

**Agent:** Uses modify-chart to enable `ingress.external.enabled: true`.

**You:** Commits, pushes, watches the pipeline, verifies the deployment.

Total time: 15-30 minutes for a complete project standup, versus hours of manual YAML writing.
