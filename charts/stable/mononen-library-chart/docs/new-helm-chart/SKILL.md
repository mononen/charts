---
name: new-helm-chart
description: Create new Helm chart projects using the common-library-chart. Sets up component-based values.yaml, auto-generated ALB ingress, and multi-environment configuration.
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
  - name: common-library-chart
    version: "1.0.0"
    repository: "oci://registry.moslrn.net/library/charts"
```

> **CRITICAL**: Only use the OCI registry URL shown above.

### 3. Create values.yaml

Minimal configuration (see `references/VALUES_PATTERNS.md` for complete templates):

```yaml
global:
  clientCode: myorg
  project: myapp
  env: dev
  namespace: myorg
  domain: example.com
  
  alb:
    prefix: myorg  # Auto-generates ALB names
  
  imageDefaults:
    registry: registry.moslrn.net
    pullSecrets:
      - name: harbor  # MUST be 'harbor'

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
```

> **CRITICAL**: Define complete container specs in base `values.yaml`. Never override `containers` array in environment configs - Helm replaces arrays entirely.
>
> **CRITICAL**: Every component MUST include an explicit `generate` block listing all resource types, even when all values are `true` (the defaults). This makes the chart self-documenting and ensures teams can immediately see which resources each component produces without consulting library defaults. Never omit the `generate` block.

### 4. Create Template Entry Point

```yaml
# templates/resources.yaml
{{- include "common.all" . }}
```

### 5. Add ALB Helpers

Copy helpers from `references/ALB_INGRESS_CONFIG.md` to `templates/_helpers.tpl`.

### 6. Build and Test

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
| Ingress values | `loadBalancerName`, `groupName`, `securityGroups` (discover from cluster via K8s MCP) |
| Primary component | `primaryComponent: true` |
| Multi-container pod | Multiple entries in `containers[]` |
| Persistent storage | `volumes[]` with PVC |
| Init containers | `initContainers[]` |
| Logging sidecar | `generate.logging: true` |

## Ingress Configuration (Discover from Cluster via K8s MCP)

> **CRITICAL**: Do NOT guess or invent ingress ALB values. When a component has `generate.ingress: true`, discover the 3 required values (`loadBalancerName`, `groupName`, `securityGroups`) from existing ingresses in the target cluster using the Kubernetes MCP tool.

### Discovery Procedure

**Step 1: Identify target cluster contexts**

Use the Kubernetes MCP to list available contexts:

```
CallMcpTool:
  server: user-kubernetes-mcp-server
  toolName: configuration_contexts_list
```

Cross-reference with the project's account/environment mapping from `global-config.yml` to identify which context corresponds to each environment's cluster.

**Step 2: List ingresses in the target cluster**

For each unique target cluster, list all ingresses:

```
CallMcpTool:
  server: user-kubernetes-mcp-server
  toolName: resources_list
  arguments:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    context: <cluster-context>
```

**Step 3: Extract unique load balancer names**

From the returned ingresses, extract all unique values of the `alb.ingress.kubernetes.io/load-balancer-name` annotation. Group them by the `alb.ingress.kubernetes.io/scheme` annotation (`internal` vs `internet-facing`) to distinguish internal and external LBs. There are multiple load balancers per cluster, each serving different purposes.

**Step 4: Prompt user to select load balancer**

Present the discovered LB names (grouped by internal/external) and ask the user which one to use for this project's internal ingress. If any components need external ingress, ask which external LB to use as well.

**Step 5: Pull groupName and securityGroups from a matching ingress**

Once the user selects an LB, use `resources_get` on one of the ingresses that uses that LB and extract:
- `loadBalancerName` from `alb.ingress.kubernetes.io/load-balancer-name`
- `groupName` from `alb.ingress.kubernetes.io/group.name`
- `securityGroups` from `alb.ingress.kubernetes.io/security-groups`

Use these values in the project's ingress configuration for that environment.

**Step 6: Repeat for each environment's cluster if they differ**

If the project deploys across different accounts/clusters (e.g., govcloud-int, govcloud-prd), repeat the lookup for each cluster since LB names and security groups may differ between environments. Set the discovered values in the corresponding environment config files (`.ci/config/<env>.yaml`).

### External Ingress: Prod Prompt, Lower Envs Internal-Only

> **Default behavior**: All lower environments (sbx, int, stg) should default to **internal-only** ingress. Only production (prd) should have external ingress, and only for components that need it.

When setting up ingress, prompt the user: **"Which components/services need to be exposed externally (internet-facing) on production?"** Apply external ingress only to those components in `prd.yaml`. Lower environment configs should not enable external ingress unless the user explicitly requests it.

### Resulting Configuration

After discovery, the ingress values should look like:

```yaml
# values.yaml (base - internal only, values from cluster lookup)
components:
  myapp:
    ingress:
      internal:
        enabled: true
        loadBalancerName: "discovered-from-cluster"
        groupName: "discovered-from-cluster"
        securityGroups: "discovered-from-cluster"
      external:
        enabled: false
```

```yaml
# config/prd.yaml (enable external only for user-selected components)
components:
  myapp:
    ingress:
      internal:
        loadBalancerName: "discovered-from-prd-cluster"
        groupName: "discovered-from-prd-cluster"
        securityGroups: "discovered-from-prd-cluster"
      external:
        enabled: true
        loadBalancerName: "discovered-from-prd-cluster"
        groupName: "discovered-from-prd-cluster"
        securityGroups: "discovered-from-prd-cluster"
```

See `references/ALB_INGRESS_CONFIG.md` for annotation details and the full discovery reference.

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
- [ ] **Every enabled ingress has explicit `loadBalancerName`, `groupName`, and `securityGroups`** (discovered from cluster via K8s MCP)
- [ ] `global.alb.prefix` set
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
- **Wrong ALB names** - Verify `global.env` in env configs

## Related References

- `references/VALUES_PATTERNS.md` - Complete values.yaml templates
- `references/COMPONENT_EXAMPLES.md` - Multi-container, storage, secrets
- `references/ALB_INGRESS_CONFIG.md` - Ingress annotation helpers
- `references/LOGGING_SIDECARS.md` - Alloy/Loki configuration
- `references/TROUBLESHOOTING_CHARTS.md` - Issue resolution
