# Ingress Configuration

**Purpose:** Ingress resource generation, host name patterns, and configuration reference.

## Ingress Generation Overview

The common-library-chart automatically generates Kubernetes Ingress resources for each component. The chart supports dual ingress (internal/external) with configurable `ingressClassName` and annotations.

### When Ingresses Are Generated

Ingresses are generated for a component when **ALL** of the following are true:

1. **Component is enabled:** `components.<name>.enabled: true`
2. **Global ingress generation is enabled:** `global.resources.ingresses: true` (default)
3. **Component ingress generation is not disabled:** `components.<name>.generate.ingress` is not `false`
4. **At least one ingress type is enabled:**
   - Internal: `components.<name>.ingress.internal.enabled` is not `false` (enabled by default)
   - External: `components.<name>.ingress.external.enabled: true` (disabled by default)

### Default Behavior

| Ingress Type | Default | Description |
|--------------|---------|-------------|
| **Internal** | Enabled | Creates an ingress for internal/cluster traffic |
| **External** | Disabled | Must be explicitly enabled for internet-facing access |

### Disabling Ingress Generation

```yaml
# Option 1: Disable globally (affects all components)
global:
  resources:
    ingresses: false

# Option 2: Disable for specific component
components:
  worker:
    generate:
      ingress: false

# Option 3: Disable both internal and external
components:
  api:
    ingress:
      internal:
        enabled: false
      external:
        enabled: false
```

---

## Host Name Generation

The ingress host name is automatically constructed from the **subdomain** and **FQDN (Fully Qualified Domain Name)**.

### Host Name Formula

```
host = {subdomain}.{fqdn}
```

Where:
- **subdomain** = `ingress.subdomain` or defaults to `componentName`
- **fqdn** = computed from environment and domain (see below)

### FQDN Computation

| Environment | FQDN Pattern | Example |
|-------------|--------------|---------|
| Non-production (dev, stg, sbx) | `{env}.{domain}` | `dev.example.com` |
| Production (prd) | `{domain}` | `example.com` |
| Override | `{domainOverride}` | Any custom value |

### Examples

```yaml
global:
  domain: "example.com"
  env: dev

components:
  api:
    ingress: {}           # Host: api.dev.example.com (uses component name)
  
  frontend:
    ingress:
      subdomain: "app"    # Host: app.dev.example.com (custom subdomain)
  
  admin:
    ingress:
      subdomain: "admin-portal"  # Host: admin-portal.dev.example.com
```

**Production example:**
```yaml
global:
  domain: "example.com"
  env: prd

components:
  api:
    ingress: {}           # Host: api.example.com (no env prefix in prd)
```

### Subdomain Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ingress.subdomain` | string | Component name | The subdomain prefix for the host |

```yaml
components:
  myapp:
    ingress:
      subdomain: "my-custom-subdomain"
      internal:
        enabled: true
      external:
        enabled: false
```

---

## Ingress Class and Annotations

### className

Set `ingressClassName` to match your ingress controller (nginx, traefik, etc.):

```yaml
components:
  myapp:
    ingress:
      className: nginx              # Shared default for both types
      internal:
        enabled: true
      external:
        enabled: true
        className: nginx-external   # Override for external type
```

### Annotations

Annotations can be set at the shared level (applied to both internal and external) or per-type. Per-type annotations are merged with shared annotations, with per-type taking precedence:

```yaml
components:
  myapp:
    ingress:
      className: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt
      internal:
        enabled: true
      external:
        enabled: true
        annotations:
          nginx.ingress.kubernetes.io/whitelist-source-range: "0.0.0.0/0"
```

### TLS Configuration

```yaml
components:
  myapp:
    ingress:
      className: nginx
      internal:
        enabled: true
        tls:
          - secretName: myapp-tls
            hosts:
              - myapp.dev.example.com
```

---

## Values.yaml Ingress Configuration

```yaml
components:
  myapp:
    ingress:
      className: ""           # ingressClassName (e.g., nginx, traefik)
      subdomain: ""           # Override subdomain (defaults to component name)
      annotations: {}         # Shared annotations for all ingress types
      
      internal:
        enabled: true         # Internal ingress (enabled by default)
        className: ""         # Override ingressClassName for this type
        annotations: {}       # Per-type annotations (merged with shared)
        paths: []             # Custom path routing (defaults to / -> service)
        tls: []               # TLS configuration
      
      external:
        enabled: false        # External ingress (disabled by default)
        className: ""         # Override ingressClassName
        annotations: {}       # Per-type annotations
        paths: []             # Custom path routing
        tls: []               # TLS configuration
```

### Host Name Examples

```yaml
# Example 1: Default subdomain (uses component name)
components:
  api:
    ingress:
      className: nginx
      internal:
        enabled: true
# Result: api.{env}.{domain} (e.g., api.dev.example.com)

# Example 2: Custom subdomain
components:
  api:
    ingress:
      className: nginx
      subdomain: "backend-api"
      internal:
        enabled: true
# Result: backend-api.{env}.{domain} (e.g., backend-api.dev.example.com)

# Example 3: Multiple components with different subdomains
components:
  frontend:
    ingress:
      className: nginx
      subdomain: "app"
      internal:
        enabled: true
      external:
        enabled: true
  
  api:
    ingress:
      className: nginx
      subdomain: "api"
      internal:
        enabled: true
  
  admin:
    ingress:
      className: nginx
      subdomain: "admin"
      internal:
        enabled: true
# Results:
#   - app.dev.example.com (frontend, internal + external)
#   - api.dev.example.com (api, internal only)
#   - admin.dev.example.com (admin, internal only)
```

## Environment-Specific Ingress Configuration

```yaml
# config/sbx.yaml - Sandbox
global:
  env: sbx

components:
  myapp:
    ingress:
      internal:
        enabled: true
      external:
        enabled: false
```

```yaml
# config/prd.yaml - Production (enable external for selected components)
global:
  env: prd

components:
  myapp:
    ingress:
      internal:
        enabled: true
      external:
        enabled: true
```

## Custom Path Routing

Override default path routing (defaults to `/` -> service):

```yaml
components:
  api:
    ingress:
      className: nginx
      internal:
        enabled: true
        paths:
          - path: /api
            pathType: Prefix
          - path: /health
            pathType: Exact
            servicePort: 8081
      external:
        enabled: true
        paths:
          - path: /api/v1
            pathType: Prefix
```

### Path Configuration

| Field | Default | Description |
|-------|---------|-------------|
| `path` | `/` | URL path to match |
| `pathType` | `Prefix` | `Prefix` or `Exact` |
| `serviceName` | Component fullname | Override backend service name |
| `servicePort` | Component service port | Override backend port number |
| `portName` | | Use named port instead of number |

## Helper Template: FQDN

Available in consuming charts for custom templates:

```yaml
{{- define "ingress.fqdn" -}}
{{- $global := .Values.global | default dict }}
{{- if $global.domainOverride }}
{{- printf "%s" $global.domainOverride }}
{{- else }}
{{- if eq ($global.env | default "dev") "prd" }}
{{- printf "%s" $global.domain }}
{{- else }}
{{- printf "%s.%s" $global.env $global.domain }}
{{- end }}
{{- end }}
{{- end }}
```
