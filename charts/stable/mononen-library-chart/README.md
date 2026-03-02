# Common Library Chart

A Helm library chart providing reusable templates for Kubernetes resources.

> **Note:** Chart packages only include essential files (Chart.yaml, values.yaml, templates/, README.md). All CI/CD files, documentation, and scripts are excluded via `.helmignore` for smaller, cleaner packages.

## Installation

Add as a dependency in your `Chart.yaml`:

```yaml
dependencies:
  - name: mononen-library-chart
    version: "1.0.0"
    repository: "https://mononen.github.io/charts/"
```

### Using the Library Chart

1. **Add the dependency** to your `Chart.yaml`:
   ```yaml
   dependencies:
     - name: mononen-library-chart
       version: "1.0.0"
       repository: "https://mononen.github.io/charts/"
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
```

**Semantic Versioning:**
- **Patch** (1.0.X): Bug fixes, backward compatible
- **Minor** (1.X.0): New features, backward compatible
- **Major** (X.0.0): Breaking changes

**Key Points:**
- Only tagged commits are released
- Tag format: `vX.Y.Z` or `X.Y.Z` (v prefix optional)

## Ingress Configuration

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

### Ingress Class and Annotations

The `className` and `annotations` fields let you configure ingress for any controller (nginx, traefik, ALB, etc.):

```yaml
global:
  clientCode: myorg
  env: dev

components:
  api:
    ingress:
      className: nginx
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
      internal:
        enabled: true
      external:
        enabled: false
```

Shared `className` and `annotations` at the ingress level apply to both internal and external. Per-type overrides take precedence:

```yaml
components:
  api:
    ingress:
      className: nginx              # Default for both
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt
      internal:
        enabled: true
      external:
        enabled: true
        className: nginx-external    # Override for external only
        annotations:                 # Merged with shared annotations
          nginx.ingress.kubernetes.io/whitelist-source-range: "0.0.0.0/0"
```

### Per-Ingress Override

Override any specific ingress when needed:

```yaml
components:
  api:
    ingress:
      subdomain: "backend"       # Custom subdomain (default: component name)
      internal:
        enabled: true
      external:
        enabled: false
```

### Pattern Summary

| Setting | Pattern |
|---------|---------|
| `host` | `{subdomain}.{env}.{domain}` or `{subdomain}.{domain}` (prd) |
| `className` | Set per-component or per-type |
| `annotations` | Shared + per-type (merged) |

## Quick Start

### values.yaml

```yaml
global:
  clientCode: myorg
  project: myapp
  env: dev
  namespace: myorg
  domain: example.com

  imageDefaults:
    registry: registry.example.com
    pullPolicy: IfNotPresent
    pullSecrets:
      - name: regcred

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
    
    ingress:
      className: nginx
      internal:
        enabled: true
      external:
        enabled: false
```

## Image Configuration

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

## Helm Array Merging

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

## Environment Overrides

No need to repeat ingress settings per environment - they follow `global.env`:

```yaml
# config/prd.yaml
global:
  env: prd

# That's it! Host names become {subdomain}.{domain} automatically (no env prefix)
```

Override only if you need different values:

```yaml
# config/special.yaml
components:
  api:
    ingress:
      internal:
        annotations:
          custom-annotation: "special-value"
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

### Global Logging Configuration

Configure the logging infrastructure globally:

```yaml
global:
  logs:
    lokiEndpoint: "https://loki.example.com"
  
  logging:
    image:
      repository: grafana/alloy
      tag: v1.9.1
```

### Sidecar Defaults

| Setting | Default Value |
|---------|---------------|
| **Image** | `grafana/alloy:v1.9.1` |
| **Loki Endpoint** | Must be configured via `global.logs.lokiEndpoint` |
| **Loki Auth Secret** | `loki-auth` |
| CPU Request | `50m` |
| Memory Request | `64Mi` |
| Memory Limit | `256Mi` |
| Security Context | `runAsGroup: 473` |

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

- [Docs Index](docs/README.md) - Skills and reference materials
