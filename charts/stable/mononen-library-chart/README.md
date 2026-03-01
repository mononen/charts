# Common Library Chart

A Helm library chart providing reusable templates for Kubernetes resources.

> **Note:** Chart packages only include essential files (Chart.yaml, values.yaml, templates/, README.md). All CI/CD files, documentation, and scripts are excluded via `.helmignore` for smaller, cleaner packages.

## Installation

> ⚠️ **CRITICAL: Registry Configuration**
>
> The common-library-chart MUST be pulled from the OCI registry:
> ```
> oci://registry.moslrn.net/library/charts
> ```
> This is the **ONLY** supported registry. Do NOT use file paths or HTTP registry URLs.

Add as a dependency in your `Chart.yaml`:

```yaml
dependencies:
  - name: common-library-chart
    version: "1.0.0"  # Use latest version from OCI registry
    repository: "oci://registry.moslrn.net/library/charts"
```

### Using the Library Chart

1. **Add the dependency** to your `Chart.yaml`:
   ```yaml
   dependencies:
     - name: common-library-chart
       version: "1.0.0"
       repository: "oci://registry.moslrn.net/library/charts"
   ```

2. **Update dependencies**:
   ```bash
   helm dependency update
   ```

3. **Use the templates** in your chart's `templates/resources.yaml`:
   ```yaml
   {{- include "common.all" . }}
   ```

### Version Management

The library chart uses **git tag-based versioning**. Versions are explicitly controlled via git tags:

```bash
# Create a release tag
git tag v1.0.5
git push origin v1.0.5

# Pipeline automatically extracts version and publishes to OCI registry
```

**Semantic Versioning:**
- **Patch** (1.0.X): Bug fixes, backward compatible
- **Minor** (1.X.0): New features, backward compatible
- **Major** (X.0.0): Breaking changes

**Key Points:**
- Only tagged commits are released
- Tag format: `vX.Y.Z` or `X.Y.Z` (v prefix optional)
- Pipeline fails if no tag exists on commit
- See [Git Tag Versioning Guide](./docs/GIT_TAG_VERSIONING.md) for details

Always check the [OCI registry](https://registry.moslrn.net/harbor/projects/library/repositories/charts%2Fcommon-library-chart) for available versions.

## ALB Ingress Configuration

### Host Name Generation

Ingress host names are automatically generated from the **subdomain** and **domain**:

```
Non-production: {subdomain}.{env}.{domain}
Production:     {subdomain}.{domain}
```

The subdomain defaults to the component name but can be overridden:

```yaml
components:
  api:
    ingress: {}                    # Host: api.dev.example.com
  
  frontend:
    ingress:
      subdomain: "app"             # Host: app.dev.example.com
```

### When Ingresses Are Generated

Ingresses are created when:
1. Component is enabled
2. `global.resources.ingresses: true` (default)
3. `generate.ingress` is not `false`
4. Internal (default: enabled) or external (default: disabled) is enabled

### Auto-Generated ALB Names

ALB names are **auto-generated** from a **prefix** and the **environment**:

```yaml
global:
  clientCode: myorg
  env: dev
  
  # Set the prefix for ALB names (defaults to clientCode if not set)
  alb:
    prefix: myorg
```

This generates:
| Setting | Internal | External |
|---------|----------|----------|
| loadBalancerName | `myorg-dev-internal` | `myorg-dev-external` |
| groupName | `myorg-dev-internal` | `myorg-dev-external` |
| securityGroups | `govcloud-dev-alb-internal, myorg-dev-alb-internal` | `govcloud-dev-alb-external, myorg-dev-alb-external` |

### Per-Ingress Override

Override any specific ingress when needed:

```yaml
components:
  api:
    ingress:
      subdomain: "backend"       # Custom subdomain (default: component name)
      internal:
        enabled: true
        groupOrder: "100"
        # Optional ALB overrides (normally auto-generated):
        # loadBalancerName: "custom-alb-name"
        # groupName: "custom-group"
        # securityGroups: "custom-sg-1, custom-sg-2"
      external:
        enabled: false
```

### Pattern Summary

| Setting | Auto-Generated Pattern |
|---------|------------------------|
| `host` | `{subdomain}.{env}.{domain}` or `{subdomain}.{domain}` (prd) |
| `loadBalancerName` | `{prefix}-{env}-internal` or `{prefix}-{env}-external` |
| `groupName` | `{prefix}-{env}-internal` or `{prefix}-{env}-external` |
| `securityGroups` | `govcloud-{env}-alb-{scheme}, {prefix}-{env}-alb-{scheme}` |

## Quick Start

### values.yaml

```yaml
global:
  clientCode: myorg
  project: myapp
  env: dev
  namespace: myorg
  domain: example.com
  certificateARN: "arn:aws:acm:..."
  
  # ALB prefix (defaults to clientCode)
  alb:
    prefix: myorg
  
  # Image defaults - MUST use 'harbor' for pullSecrets
  imageDefaults:
    registry: registry.moslrn.net
    pullPolicy: IfNotPresent
    pullSecrets:
      - name: harbor  # CRITICAL: Must be 'harbor', not 'registry-secret'

components:
  api:
    enabled: true
    containers:
      - name: api
        image:
          repository: myorg/api
          tag: ""  # Set via --set global.imageDefaults.tag during deployment
        ports:
          - name: http
            containerPort: 8080
    service:
      port: 80
    
    # Ingress config - host and ALB settings auto-generated
    ingress:
      subdomain: ""            # Defaults to component name ("api")
      internal:
        enabled: true          # Internal ALB (enabled by default)
        groupOrder: "100"
      external:
        enabled: false         # External ALB (disabled by default)
```

## ⚠️ Critical: Image Configuration

### Image Pull Secret Must Be 'harbor'

```yaml
global:
  imageDefaults:
    pullSecrets:
      - name: harbor  # NOT 'registry-secret' - MUST be 'harbor'
```

### Image Tags Are Set During Deployment

The pipeline automatically sets image tags via:
```bash
helm upgrade --install ... --set global.imageDefaults.tag=${VERSION}
```

Your container image config should have an empty tag:
```yaml
containers:
  - name: api
    image:
      repository: myorg/api
      tag: ""  # Falls back to global.imageDefaults.tag or Chart.AppVersion
```

## ⚠️ Critical: Helm Array Merging

Helm REPLACES arrays entirely - it does NOT merge them. **NEVER override the `containers` array in environment-specific config files!**

**WRONG** - This loses ports, resources, probes:
```yaml
# config/sbx.yaml - DON'T DO THIS!
components:
  api:
    containers:
      - name: api
        image:
          tag: "1.0.0"  # ENTIRE containers array replaced!
```

**CORRECT** - Only override scalar values:
```yaml
# config/sbx.yaml
components:
  api:
    replicaCount: 1
    generate:
      hpa: false
    # NO 'containers' array - uses base values.yaml definition
```

### templates/resources.yaml

```yaml
{{- include "common.all" . }}
```

## Helper Templates

### ALB Annotation Helpers

```yaml
# Internal ALB annotations
{{- include "ingress.alb.internal" (dict "global" $global "config" $internal "certificateARN" $certARN) }}

# External ALB annotations  
{{- include "ingress.alb.external" (dict "global" $global "config" $external "certificateARN" $certARN) }}
```

Parameters:
- `global`: Pass `.Values.global` for auto-generation
- `config`: Per-ingress config with `groupOrder` and optional overrides
- `certificateARN`: ACM certificate ARN

## Environment Overrides

No need to repeat ALB settings per environment - they're auto-generated:

```yaml
# config/prd.yaml
global:
  env: prd
  certificateARN: "arn:aws:acm:...prod-cert..."

# That's it! ALB names become ptsi-prd-internal/external automatically
```

Override only if you need different values:

```yaml
# config/special.yaml
components:
  api:
    ingress:
      internal:
        loadBalancerName: "special-alb"  # Override just this one
```

## Logging (Alloy/Loki Sidecar)

The library includes built-in support for log collection using a **Grafana Alloy sidecar** that ships logs to Loki.

### Basic Usage

```yaml
components:
  myapp:
    generate:
      logging: true
    logging:
      appName: "my-application"  # Optional, defaults to fullname
      logTargets:
        - name: app-logs         # Volume name
          jobs:
            - name: app-access
              sidecarLogfile: access.log
              autoConfigure: true
              level: info
            - name: app-error
              sidecarLogfile: error.log
              autoConfigure: true
              level: error
              multilinePattern: "^\\[\\d{4}-\\d{2}-\\d{2}"
```

This automatically:
1. Creates an Alloy ConfigMap with Loki scrape configurations
2. Injects a logging sidecar container
3. Creates emptyDir volumes for log files
4. Mounts the Loki auth secret for authentication

### Sidecar Defaults

> ⚠️ **DO NOT OVERRIDE** these defaults unless explicitly instructed by the DevOps team.
> The image, endpoint, and auth secret are centrally managed to ensure compatibility
> with the organization's logging infrastructure.

| Setting | Default Value | Override? |
|---------|---------------|-----------|
| **Image** | `registry.moslrn.net/dh/grafana/alloy:v1.9.1` | **NO** - centrally managed |
| **Loki Endpoint** | `https://logs.moslrn.net` | **NO** - centrally managed |
| **Loki Auth Secret** | `loki-auth` | **NO** - cluster-provided |
| CPU Request | `50m` | Only if necessary |
| Memory Request | `64Mi` | Only if necessary |
| Memory Limit | `256Mi` | Only if necessary |
| Security Context | `runAsGroup: 473` | Only if necessary |

The image and endpoint are configured globally and should **never** be overridden in application charts. These are managed centrally to ensure all applications use compatible, tested versions and connect to the correct logging infrastructure.

### What You CAN Configure

Focus only on these application-specific settings:

```yaml
components:
  myapp:
    generate:
      logging: true                    # Enable logging sidecar
    logging:
      appName: "my-application"        # App name in log labels
      logTargets:                      # Your log file definitions
        - name: app-logs
          jobs:
            - name: app-stdout
              sidecarLogfile: application.log
              autoConfigure: true
              level: info
```

### Custom Alloy Configuration

For complex logging scenarios, set `customConfig: true` and create your own template:

```yaml
components:
  myapp:
    generate:
      logging: true
    logging:
      customConfig: true  # Library won't generate ConfigMap
      logTargets:
        - name: app-logs  # Still needed for sidecar volume mounts
```

Then create `templates/myapp/alloy-configmap.yaml` with your custom Alloy config.
Use `{{ include "common.logging.alloy-header" . }}` to include the standard Loki write configuration.

### Log Target Configuration

| Field | Description |
|-------|-------------|
| `name` | Volume name, mounted at `/var/log/<name>` in sidecar |
| `jobs[].name` | Job name for Loki labels |
| `jobs[].sidecarLogfile` | Filename within the volume |
| `jobs[].autoConfigure` | Auto-generate Alloy scrape config (true/false) |
| `jobs[].level` | Optional log level label (info, error, warn) |
| `jobs[].multilinePattern` | Optional regex for multiline logs |
| `jobs[].dropPattern` | Optional regex to drop matching lines |

### Global Logging Defaults (DO NOT MODIFY)

These values are set at the infrastructure level and should **not** be overridden in application charts:

```yaml
# These are infrastructure defaults - DO NOT set in your values.yaml
global:
  logs:
    lokiEndpoint: "https://logs.moslrn.net"  # DO NOT OVERRIDE
  
  logging:
    image:
      repository: registry.moslrn.net/dh/grafana/alloy  # DO NOT OVERRIDE
      tag: v1.9.1                                        # DO NOT OVERRIDE
```

## Generated Resources

The library generates the following resources per component:

- **Deployment** - Container orchestration
- **Service** - Internal networking
- **HorizontalPodAutoscaler** - Autoscaling
- **PodDisruptionBudget** - High availability
- **ServiceAccount** - Pod identity
- **ServiceMonitor** - Prometheus metrics
- **Restart CronJob** - Scheduled restarts (with RBAC)

## Component Configuration

### Enable/Disable Resource Generation

```yaml
components:
  myapp:
    enabled: true
    generate:
      deployment: true      # Generate deployment
      service: true         # Generate service
      hpa: true             # Generate HPA
      pdb: true             # Generate PDB
      serviceaccount: true  # Generate ServiceAccount
      ingress: false        # Use custom ingress template
```

### Primary Component

Use `primaryComponent: true` for the main component to avoid name suffix:

```yaml
components:
  lms:
    enabled: true
    primaryComponent: true  # Resources named "release-name" not "release-name-lms"
```

## Documentation

- [AI New Project Guide](docs/AI_NEW_PROJECT_GUIDE.md) - Creating new projects
- [AI Migration Guide](docs/AI_MIGRATION_GUIDE.md) - Migrating existing charts
