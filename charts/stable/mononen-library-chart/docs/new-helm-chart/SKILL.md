---
name: new-helm-chart
description: Create new Helm chart projects using the common-library-chart. Sets up component-based values.yaml, auto-generated ingress, and multi-environment configuration.
---

# Create New Helm Chart Project

Use this skill when creating a **new Helm chart from scratch** using the common-library-chart.

## High-Level Workflow

### 1. Create Directory Structure

```
.ci/
├── chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── resources.yaml
│       └── _helpers.tpl
└── config/
    ├── sbx.yaml
    ├── int.yaml
    ├── stg.yaml
    └── prd.yaml
```

### 2. Create Chart.yaml

```yaml
apiVersion: v2
name: my-application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: mononen-library-chart
    version: "1.0.0"
    repository: "https://mononen.github.io/charts/"
```

### 3. Create values.yaml

Minimal configuration (see `references/VALUES_PATTERNS.md` for complete templates):

```yaml
global:
  clientCode: myorg
  project: myapp
  env: dev
  namespace: myorg
  domain: example.com
  
  imageDefaults:
    registry: registry.example.com
    pullSecrets:
      - name: regcred

components:
  myapp:
    enabled: true
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    containers:
      - name: myapp
        image:
          repository: myorg/myapp
          tag: ""  # Set via --set during deployment
        ports:
          - name: http
            containerPort: 8080
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
    service:
      port: 80
      targetPort: http
    ingress:
      className: nginx
      internal:
        enabled: true
```

> **CRITICAL**: Define complete container specs in base `values.yaml`. Never override `containers` array in environment configs - Helm replaces arrays entirely.
>
> **CRITICAL**: Every component MUST include an explicit `generate` block listing all resource types, even when all values are `true` (the defaults). This makes the chart self-documenting and ensures teams can immediately see which resources each component produces without consulting library defaults. Never omit the `generate` block.

### 4. Create Template Entry Point

```yaml
# templates/resources.yaml
{{- include "common.all" . }}
```

### 5. Build and Test

```bash
cd .ci/chart
helm dependency update
helm lint .
helm template my-release . > rendered.yaml
```

## Key Configuration Patterns

See `references/COMPONENT_EXAMPLES.md` for detailed examples:

| Pattern | Key Setting |
|---------|-------------|
| Per-component generation | `generate:` block (REQUIRED on every component) |
| Ingress class | `ingress.className` (e.g., nginx, traefik) |
| Primary component | `primaryComponent: true` |
| Multi-container pod | Multiple entries in `containers[]` |
| Persistent storage | `volumes[]` with PVC |
| Init containers | `initContainers[]` |
| Logging sidecar | `generate.logging: true` |

## Ingress Configuration

The library generates Kubernetes Ingress resources with configurable `className` and `annotations`. Host names are auto-generated from subdomain + environment + domain.

### Configuration

```yaml
components:
  myapp:
    ingress:
      className: nginx           # ingressClassName
      subdomain: ""              # defaults to component name
      annotations:               # shared annotations
        cert-manager.io/cluster-issuer: letsencrypt
      internal:
        enabled: true            # enabled by default
        annotations: {}          # per-type annotations (merged with shared)
      external:
        enabled: false           # disabled by default
        annotations: {}
```

### Host Name Generation

```
Non-production: {subdomain}.{env}.{domain}
Production:     {subdomain}.{domain}
```

### External Ingress: Prod Prompt, Lower Envs Internal-Only

> **Default behavior**: All lower environments (sbx, int, stg) should default to **internal-only** ingress. Only production (prd) should have external ingress, and only for components that need it.

When setting up ingress, prompt the user: **"Which components/services need to be exposed externally (internet-facing) on production?"** Apply external ingress only to those components in `prd.yaml`. Lower environment configs should not enable external ingress unless the user explicitly requests it.

### Resulting Configuration

```yaml
# values.yaml (base - internal only)
components:
  myapp:
    ingress:
      className: nginx
      internal:
        enabled: true
      external:
        enabled: false
```

```yaml
# config/prd.yaml (enable external only for user-selected components)
components:
  myapp:
    ingress:
      external:
        enabled: true
```

See `references/INGRESS_CONFIG.md` for detailed ingress patterns.

## Environment Configuration

Create minimal env files with **only scalar overrides**:

```yaml
# config/prd.yaml
global:
  env: prd

components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    replicaCount: 3
    autoscaling:
      minReplicas: 3
      maxReplicas: 20
    # NO 'containers' array!
```

Deploy with:
```bash
helm upgrade --install myapp . \
  -f values.yaml \
  -f config/prd.yaml \
  --set global.imageDefaults.tag=${VERSION}
```

## Validation Checklist

- [ ] Chart.yaml has library dependency
- [ ] values.yaml has global + components structure
- [ ] **Every component has an explicit `generate` block** (even if all values are `true`)
- [ ] `ingress.className` set for components that need ingress
- [ ] templates/resources.yaml created
- [ ] `helm dependency update` successful
- [ ] `helm lint` passes
- [ ] Resource names follow convention
- [ ] Security contexts defined
- [ ] Resource limits defined
- [ ] Probes configured

## Common Issues

See `references/TROUBLESHOOTING_CHARTS.md`:

- **Template not found** - Check _helpers.tpl exists
- **Nil pointer** - Add `| default dict` for nested values
- **Resources not generating** - Check `generate` block flags are set to `true`
- **Wrong ingress hosts** - Verify `global.env` in env configs

## Related References

- `references/VALUES_PATTERNS.md` - Complete values.yaml templates
- `references/COMPONENT_EXAMPLES.md` - Multi-container, storage, secrets
- `references/INGRESS_CONFIG.md` - Ingress configuration and host generation
- `references/LOGGING_SIDECARS.md` - Alloy/Loki configuration
- `references/TROUBLESHOOTING_CHARTS.md` - Issue resolution
