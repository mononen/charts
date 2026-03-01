# New Project Intake Checklist

What to collect from a dev team before standing up a new project with the Mosaic libraries. Organized by category with must-haves first and "if applicable" items after.

---

## 1. Project Identity (required)

- **Client code** — the org/client identifier (e.g., `ptsi`, `acme`). Used in naming across the board: namespaces, ALBs, resource names.
- **Project name** — the application name (e.g., `lms`, `portal`).
- **Kubernetes namespace** — usually matches client code or project name.
- **Git repository URL** — the Bitbucket repo (e.g., `bitbucket.org/MosaicLearning/my-repo.git`).

---

## 2. Domain & Networking (required)

- **Primary domain** — base domain (e.g., `example.com`). Hosts are auto-generated: `{subdomain}.{env}.{domain}` for non-prod, `{subdomain}.{domain}` for prod.
- **AWS ACM Certificate ARN** — for HTTPS on the ALB. One per environment/account if they differ.
- **ALB prefix** — defaults to client code. Only needed if they want it different.
- **Which components need external (internet-facing) ingress on production?** — Internal ALB is on by default; external is off by default. Lower environments (sbx, int, stg) default to internal-only. Only production should have external ingress, and only for components that need public access. The agent will prompt for this during standup.
- **ALB load balancer name, group name, and security groups** — these are **auto-discovered** from existing ingresses in the target cluster using the Kubernetes MCP tool. The agent lists available LBs and prompts the user to select which one to use. No need to gather these manually.
- **Subdomains per component** — defaults to component name (e.g., component `api` = `api.dev.example.com`). Only needed if they want to override.

---

## 3. Container Images & Dockerfiles (required)

- **How many Docker images?** — One per buildable component (e.g., `app`, `nginx`, `worker`).
- **For each image:**
  - **Image name/path in registry** — naming convention: `{client}/{project}/{component}` (e.g., `ptsi/lms/moodle/php`).
  - **Dockerfile location** — directory or full path (e.g., `./docker/app` or `./docker/Dockerfile.prod`).
  - **Multi-stage build target** — if using multi-stage Dockerfiles, which target? (e.g., `prod`).
  - **Build arguments** — any build-time variables needed? (e.g., `PHP_VERSION: "8.2"`).
  - **Build context** — only if different from the Dockerfile directory.

---

## 4. Application Components (required)

- **List of components and their type** — What makes up the app? Examples:
  - Web API (deployment + service + ingress)
  - Frontend/SPA (deployment + service + ingress)
  - Background worker (deployment only, no ingress)
  - Scheduler/CronJob
- **For each component:**
  - **Container port** — what port does the app listen on? (e.g., `8080`, `3000`).
  - **Service port** — usually `80`, mapped to the container port.
  - **Resource requests/limits** — CPU and memory (e.g., `cpu: 500m, memory: 512Mi`). At minimum, limits.

---

## 5. Health Checks (required for any component with ingress)

- **Healthcheck endpoint path** — e.g., `/health`, `/healthz`, `/api/health`.
  - The ALB healthcheck auto-inherits from the Kubernetes `readinessProbe` path, so if they define a `readinessProbe`, they get the ALB healthcheck for free.
- **Do they need separate paths for:**
  - Liveness probe (is the process alive?) vs. readiness probe (is it ready to serve traffic)?
  - Internal vs. external ALB healthchecks? (e.g., lighter check for external)
- **Startup probe?** — needed for slow-starting apps (e.g., large JVM apps, apps with DB migrations at startup).

---

## 6. Environments & Deployment (required)

- **Which environments?** — e.g., `int` (integration), `stg` (staging), `prd` (production), `sbx` (sandbox).
- **For each environment:**
  - **Git branch that triggers deployment** — e.g., `dev` → int, `main` → prd.
  - **AWS account** — `govcloud`, `sdprod` (commercial), or `combobulate` (cross-account).
  - **Replica count or autoscaling settings** — min/max replicas, CPU/memory targets.
- **Does production need a manual approval gate?**
- **Do they want git tagging on production releases?**

---

## 7. Database / Migrations (if applicable)

- **Database needed?** If yes:
  - **Engine** — Aurora PostgreSQL, MySQL, etc.
  - **Engine version** — e.g., `16.1`.
  - **Instance class** — e.g., `db.r6g.large`.
  - **Master username** — or use default (`dbadmin`).
  - **VPC ID and subnet group** — for RDS placement.
  - **EKS security group IDs** — to allow access from pods.
- **Database migrations** — how do they run?
  - **Init container?** — runs before the app starts (use `initContainers` in the chart).
  - **Helm pre-install/pre-upgrade Job?** — runs as a Helm hook before deployment (use `jobs` with `hook: "pre-install,pre-upgrade"`).
  - **Migration command** — e.g., `["php", "artisan", "migrate", "--force"]` or `["python", "manage.py", "migrate"]`.
  - **Does it need the same env vars / secrets as the main app?**

---

## 8. Environment Variables & Secrets (if applicable)

- **Environment variables** — list of non-sensitive config values per environment (e.g., `APP_ENV`, `LOG_LEVEL`, `API_URL`).
- **Secrets** — list of sensitive values (e.g., `DATABASE_URL`, `API_KEY`, `REDIS_PASSWORD`).
  - Where do they come from? Kubernetes Secrets? External Secrets (Doppler)?
  - Are they shared across components or component-specific?
- **ConfigMaps** — any config files that need to be mounted? (e.g., `nginx.conf`, `php.ini`).

---

## 9. Storage (if applicable)

- **S3 buckets** — does the app need object storage?
  - Bucket name (globally unique, convention: `{client}-{project}-{env}-{purpose}`).
  - Versioning needed?
  - Lifecycle rules (e.g., delete after 90 days)?
- **Persistent volumes** — does any component need persistent disk storage?
  - Size and access mode.
- **Pod Identity / IAM** — does the app need AWS API access (S3, Bedrock, SES, etc.)?
  - Service account name.
  - Which AWS services / policy ARNs?

---

## 10. CronJobs & Background Jobs (if applicable)

- **Scheduled tasks** — any cron-based work?
  - **Schedule** — cron expression (e.g., `"0 2 * * *"` for 2 AM daily).
  - **Command** — what to run.
  - **Concurrency policy** — can jobs overlap? (`Forbid`, `Allow`, `Replace`).
- **One-off jobs** — any Helm hook jobs (besides migrations)?
  - Pre-install? Post-install? Pre-upgrade?

---

## 11. Logging & Monitoring (if applicable)

- **Does the app write logs to files** (not just stdout)?
  - If yes, enable the Alloy logging sidecar and specify log file paths.
  - Multiline log patterns? (e.g., Java stack traces).
- **Prometheus metrics?**
  - Metrics endpoint path and port.
  - Scrape interval.

---

## 12. Notifications (recommended)

- **Microsoft Teams / Office 365 webhook URL** — for build and deployment notifications.
- **Which environments should notify?** — usually all, but some teams only want prod.

---

## What's Auto-Generated (devs don't need to provide)

These are handled by the libraries and don't need input:

- ALB names, group names, and security groups (discovered from existing ingresses in target cluster via Kubernetes MCP)
- Ingress host names (from `subdomain` + `env` + `domain`)
- ALB healthcheck path (inherited from `readinessProbe`)
- Image tags (set during deployment via `--set`)
- BuildKit configuration (from global config)
- Harbor/Bitbucket/Jenkins credentials (from global config)
- AWS region and cluster (derived from `account` in global config)
- Pod security contexts (secure defaults applied)
- PodDisruptionBudgets (auto-generated)
- HorizontalPodAutoscalers (auto-generated with sensible defaults)
- ServiceAccounts (auto-generated)

---

## Minimum Viable Intake (absolute bare minimum)

If you want the shortest possible list to get started:

1. Client code + project name
2. Git repo URL
3. Domain + certificate ARN
4. Docker image(s): name, Dockerfile path, build target
5. Container port(s)
6. Healthcheck endpoint path
7. Environments: names, branches, AWS account
8. Teams webhook URL

Everything else has sensible defaults or can be added later incrementally.
