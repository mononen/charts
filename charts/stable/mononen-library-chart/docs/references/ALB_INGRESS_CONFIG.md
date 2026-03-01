# ALB Ingress Configuration

**Purpose:** AWS Application Load Balancer ingress annotation helpers and configuration patterns.

> **CRITICAL**: While the helper templates can auto-generate `loadBalancerName`, `groupName`, and `securityGroups` from a prefix, you MUST always explicitly set these 3 values in your `values.yaml` and environment configs. Never rely on auto-generation. **Discover the correct values from existing ingresses in the target cluster** using the Kubernetes MCP tool (see [Ingress Value Discovery via Kubernetes MCP](#ingress-value-discovery-via-kubernetes-mcp) below). Getting these wrong will break routing or create security issues.

## Ingress Generation Overview

The common-library-chart automatically generates Kubernetes Ingress resources for each component. Understanding when and how ingresses are created helps you configure them correctly.

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
| **Internal** | Enabled | Creates an internal ALB for cluster/VPC traffic |
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
      subdomain: "my-custom-subdomain"  # Override the default (component name)
      internal:
        enabled: true
        loadBalancerName: "myorg-dev-internal"
        groupName: "myorg-dev-internal"
        securityGroups: "dev-alb-internal, myorg-dev-alb-internal"
      external:
        enabled: false
```

---

## Auto-Generation from Prefix

ALB names are auto-generated from `global.alb.prefix` (defaults to `global.clientCode`) and `global.env`:

```yaml
global:
  clientCode: myorg
  env: dev
  alb:
    prefix: myorg  # Optional, defaults to clientCode
```

**Generated Values:**

| Setting | Internal Pattern | External Pattern |
|---------|------------------|------------------|
| `loadBalancerName` | `{prefix}-{env}-internal` | `{prefix}-{env}-external` |
| `groupName` | `{prefix}-{env}-internal` | `{prefix}-{env}-external` |
| `securityGroups` | `{env}-alb-internal, {prefix}-{env}-alb-internal` | `{env}-alb-external, {prefix}-{env}-alb-external` |

**Example:** prefix `myorg` + env `dev` generates:
- Internal: `myorg-dev-internal`
- External: `myorg-dev-external`
- Security groups: `dev-alb-internal, myorg-dev-alb-internal`

## Helper Template: Internal ALB

Add to `_helpers.tpl`:

```yaml
{{/*
Internal ALB Ingress annotations
Auto-generates load balancer name, group name, and security groups from prefix

Usage: {{ include "ingress.alb.internal" (dict "global" $global "config" $internal "certificateARN" $certARN "component" $component) }}

Auto-generated pattern:
  - loadBalancerName: {prefix}-{env}-internal
  - groupName: {prefix}-{env}-internal  
  - securityGroups: {env}-alb-internal, {prefix}-{env}-alb-internal

Each value can be overridden via config map:
  - config.loadBalancerName
  - config.groupName
  - config.securityGroups
  - config.groupOrder (default: "100")
  - config.healthcheckPath (optional - override auto-inherited path)

Healthcheck path priority:
  1. config.healthcheckPath (manual override)
  2. Auto-extracted from component readinessProbe/livenessProbe
  3. Not set (ALB uses default)
*/}}
{{- define "ingress.alb.internal" -}}
{{- $global := .global }}
{{- $config := .config | default dict }}
{{- $prefix := ($global.alb).prefix | default $global.clientCode }}
{{- $env := $global.env }}
{{- $groupOrder := $config.groupOrder | default "100" }}
{{- $certARN := .certificateARN }}
{{- $lbName := $config.loadBalancerName | default (printf "%s-%s-internal" $prefix $env) }}
{{- $grpName := $config.groupName | default (printf "%s-%s-internal" $prefix $env) }}
{{- $secGroups := $config.securityGroups | default (printf "%s-alb-internal, %s-%s-alb-internal" $env $prefix $env) }}
alb.ingress.kubernetes.io/load-balancer-name: {{ $lbName | quote }}
alb.ingress.kubernetes.io/group.name: {{ $grpName | quote }}
alb.ingress.kubernetes.io/group.order: '{{ $groupOrder }}'
alb.ingress.kubernetes.io/scheme: internal
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/certificate-arn: {{ $certARN }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
alb.ingress.kubernetes.io/security-groups: {{ $secGroups | quote }}
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=300,load_balancing.algorithm.type=least_outstanding_requests
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
{{- if $config.healthcheckPath }}
alb.ingress.kubernetes.io/healthcheck-path: {{ $config.healthcheckPath | quote }}
{{- end }}
{{- end }}
```

## Helper Template: External ALB

Add to `_helpers.tpl`:

```yaml
{{/*
External ALB Ingress annotations
Auto-generates load balancer name, group name, and security groups from prefix

Usage: {{ include "ingress.alb.external" (dict "global" $global "config" $external "certificateARN" $certARN "component" $component) }}

Auto-generated pattern:
  - loadBalancerName: {prefix}-{env}-external
  - groupName: {prefix}-{env}-external
  - securityGroups: {env}-alb-external, {prefix}-{env}-alb-external

Each value can be overridden via config map:
  - config.loadBalancerName
  - config.groupName
  - config.securityGroups
  - config.groupOrder (default: "100")
  - config.healthcheckPath (optional - override auto-inherited path)

Healthcheck path priority:
  1. config.healthcheckPath (manual override)
  2. Auto-extracted from component readinessProbe/livenessProbe
  3. Not set (ALB uses default)
*/}}
{{- define "ingress.alb.external" -}}
{{- $global := .global }}
{{- $config := .config | default dict }}
{{- $prefix := ($global.alb).prefix | default $global.clientCode }}
{{- $env := $global.env }}
{{- $groupOrder := $config.groupOrder | default "100" }}
{{- $certARN := .certificateARN }}
{{- $lbName := $config.loadBalancerName | default (printf "%s-%s-external" $prefix $env) }}
{{- $grpName := $config.groupName | default (printf "%s-%s-external" $prefix $env) }}
{{- $secGroups := $config.securityGroups | default (printf "%s-alb-external, %s-%s-alb-external" $env $prefix $env) }}
alb.ingress.kubernetes.io/load-balancer-name: {{ $lbName | quote }}
alb.ingress.kubernetes.io/group.name: {{ $grpName | quote }}
alb.ingress.kubernetes.io/group.order: '{{ $groupOrder }}'
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/certificate-arn: {{ $certARN }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
alb.ingress.kubernetes.io/security-groups: {{ $secGroups | quote }}
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=300,load_balancing.algorithm.type=least_outstanding_requests
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
{{- if $config.healthcheckPath }}
alb.ingress.kubernetes.io/healthcheck-path: {{ $config.healthcheckPath | quote }}
{{- end }}
{{- end }}
```

## Helper Template: FQDN

```yaml
{{/*
Expand the ingress FQDN depending on the environment
*/}}
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

## Using Helpers in Ingress Template

```yaml
# templates/myapp/ingress.yaml
{{- $global := .Values.global | default dict }}
{{- $myapp := .Values.components.myapp | default dict }}
{{- $ingress := $myapp.ingress | default dict }}
{{- $internal := $ingress.internal | default dict }}
{{- $external := $ingress.external | default dict }}

{{/* Internal Ingress */}}
{{- if ne $internal.enabled false }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "myapp-internal"
  namespace: {{ $global.namespace | default $global.clientCode }}
  annotations:
    {{- include "ingress.alb.internal" (dict "global" $global "config" $internal "certificateARN" $global.certificateARN) | nindent 4 }}
    {{- with $internal.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  rules:
    - host: "myapp.{{ include "ingress.fqdn" . }}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: "myapp"
                port:
                  number: {{ $myapp.service.port | default 80 }}
{{- end }}

{{/* External Ingress */}}
{{- if $external.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "myapp-external"
  namespace: {{ $global.namespace | default $global.clientCode }}
  annotations:
    {{- include "ingress.alb.external" (dict "global" $global "config" $external "certificateARN" $global.certificateARN) | nindent 4 }}
    {{- with $external.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  rules:
    - host: "myapp.{{ include "ingress.fqdn" . }}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: "myapp"
                port:
                  number: {{ $myapp.service.port | default 80 }}
{{- end }}
```

## Per-Ingress Explicit Configuration

Always provide all 3 required values for each enabled ingress type:

```yaml
components:
  api:
    ingress:
      # Override subdomain (defaults to component name "api")
      subdomain: "backend"   # Host becomes: backend.{env}.{domain}
      
      internal:
        enabled: true
        loadBalancerName: "custom-api-internal"                    # REQUIRED - discovered from cluster
        groupName: "custom-api-internal"                           # REQUIRED - discovered from cluster
        securityGroups: "dev-alb-internal, custom-dev-alb-internal"  # REQUIRED - discovered from cluster
        groupOrder: "100"
        healthcheckPath: "/health"
      external:
        enabled: true
        loadBalancerName: "custom-api-external"                    # REQUIRED - discovered from cluster
        groupName: "custom-api-external-group"                     # REQUIRED - discovered from cluster
        securityGroups: "custom-sg-1, custom-sg-2"                 # REQUIRED - discovered from cluster
        groupOrder: "100"
        healthcheckPath: "/api/health"
        annotations:
          alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": {"Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
```

## Values.yaml Ingress Configuration

> **IMPORTANT**: `loadBalancerName`, `groupName`, and `securityGroups` are REQUIRED for each enabled ingress type. Discover these values from existing ingresses in the target cluster using the Kubernetes MCP tool (see [Ingress Value Discovery via Kubernetes MCP](#ingress-value-discovery-via-kubernetes-mcp)).

```yaml
components:
  myapp:
    # Ingress configuration
    ingress:
      # Host name configuration
      subdomain: ""           # Override subdomain (defaults to component name)
      certificateARN: ""      # Override global certificate ARN for this component
      
      # Custom path routing (optional - defaults to "/" -> service)
      paths: []
      
      # Internal ALB - enabled by default
      internal:
        enabled: true
        loadBalancerName: ""  # REQUIRED - discover from cluster via K8s MCP
        groupName: ""         # REQUIRED - discover from cluster via K8s MCP
        securityGroups: ""    # REQUIRED - discover from cluster via K8s MCP
        groupOrder: "100"
        healthcheckPath: ""   # Optional: custom healthcheck path
        annotations: {}       # Additional annotations
      
      # External ALB - disabled by default
      external:
        enabled: false
        loadBalancerName: ""  # REQUIRED when enabled - discover from cluster via K8s MCP
        groupName: ""         # REQUIRED when enabled - discover from cluster via K8s MCP
        securityGroups: ""    # REQUIRED when enabled - discover from cluster via K8s MCP
        groupOrder: "100"
        healthcheckPath: ""   # Optional: custom healthcheck path
        annotations: {}
```

### Host Name Examples

```yaml
# Example 1: Default subdomain (uses component name)
components:
  api:
    ingress:
      internal:
        enabled: true
        loadBalancerName: "myorg-dev-internal"
        groupName: "myorg-dev-internal"
        securityGroups: "dev-alb-internal, myorg-dev-alb-internal"
# Result: api.{env}.{domain} (e.g., api.dev.example.com)

# Example 2: Custom subdomain
components:
  api:
    ingress:
      subdomain: "backend-api"
      internal:
        enabled: true
        loadBalancerName: "myorg-dev-internal"
        groupName: "myorg-dev-internal"
        securityGroups: "dev-alb-internal, myorg-dev-alb-internal"
# Result: backend-api.{env}.{domain} (e.g., backend-api.dev.example.com)

# Example 3: Multiple components with different subdomains
components:
  frontend:
    ingress:
      subdomain: "app"
      internal:
        enabled: true
        loadBalancerName: "myorg-dev-internal"
        groupName: "myorg-dev-internal"
        securityGroups: "dev-alb-internal, myorg-dev-alb-internal"
      external:
        enabled: true
        loadBalancerName: "myorg-dev-external"
        groupName: "myorg-dev-external"
        securityGroups: "dev-alb-external, myorg-dev-alb-external"
  
  api:
    ingress:
      subdomain: "api"
      internal:
        enabled: true
        loadBalancerName: "myorg-dev-internal"
        groupName: "myorg-dev-internal"
        securityGroups: "dev-alb-internal, myorg-dev-alb-internal"
  
  admin:
    ingress:
      subdomain: "admin"
      internal:
        enabled: true
        loadBalancerName: "myorg-dev-internal"
        groupName: "myorg-dev-internal"
        securityGroups: "dev-alb-internal, myorg-dev-alb-internal"
# Results:
#   - app.dev.example.com (frontend, internal + external)
#   - api.dev.example.com (api, internal only)
#   - admin.dev.example.com (admin, internal only)
```

## Environment-Specific ALB Configuration

Always explicitly set ingress values per environment:

```yaml
# config/sbx.yaml - Sandbox
global:
  env: sbx

components:
  myapp:
    ingress:
      internal:
        enabled: true
        loadBalancerName: "sbx-internal"
        groupName: "sbx-internal"
        securityGroups: "sbx-cluster-alb-internal"
      external:
        enabled: false
```

```yaml
# config/prd.yaml - Production
global:
  env: prd

components:
  myapp:
    ingress:
      internal:
        enabled: true
        loadBalancerName: "myorg-prd-internal"
        groupName: "myorg-prd-internal"
        securityGroups: "prd-alb-internal, myorg-prd-alb-internal"
      external:
        enabled: true
        loadBalancerName: "myorg-prd-external"
        groupName: "myorg-prd-external"
        securityGroups: "prd-alb-external, myorg-prd-alb-external"
```

## Common ALB Annotations

| Annotation | Purpose | Default |
|------------|---------|---------|
| `scheme` | `internal` or `internet-facing` | Set by helper |
| `target-type` | `ip` or `instance` | `ip` |
| `ssl-redirect` | Redirect HTTP to HTTPS | `443` |
| `certificate-arn` | ACM certificate | From `global.certificateARN` |
| `healthcheck-path` | ALB healthcheck path | Traffic path (typically `/`) |
| `idle_timeout` | Connection idle timeout | `300` seconds |
| `deregistration_delay` | Deregistration delay | `300` seconds |
| `load_balancing.algorithm.type` | Load balancing algorithm | `least_outstanding_requests` |

## Ingress Value Discovery via Kubernetes MCP

Instead of asking users to manually provide ALB ingress values, discover them from existing ingresses in the target cluster using the Kubernetes MCP tool. Each cluster has multiple load balancers serving different purposes, so the user must select which one is appropriate for their project.

### Step-by-Step Procedure

**1. List available cluster contexts**

```
CallMcpTool:
  server: user-kubernetes-mcp-server
  toolName: configuration_contexts_list
```

Cross-reference the returned contexts with the project's account/environment mapping from `global-config.yml`:
- `sdprod` → clusters: sbx, int, stg, prd
- `combobulate` → clusters: dev, stg, prd
- `govcloud` → clusters: govcloud-sbx, govcloud-int, govcloud-stg, govcloud-prd

**2. List all ingresses in the target cluster**

```
CallMcpTool:
  server: user-kubernetes-mcp-server
  toolName: resources_list
  arguments:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    context: <cluster-context>
```

**3. Extract and group unique load balancer names**

From the returned ingresses, extract unique values of these annotations:
- `alb.ingress.kubernetes.io/load-balancer-name` — the LB name
- `alb.ingress.kubernetes.io/scheme` — `internal` or `internet-facing`

Group LB names by scheme. Example output to present to the user:

```
Internal load balancers:
  - acme-int-internal
  - shared-int-internal
  - platform-int-internal

External load balancers:
  - acme-int-external
  - shared-int-external
```

**4. Prompt the user to select a load balancer**

Ask: "Which internal load balancer should this project use?" Present the discovered options. If the project needs external ingress, also ask which external LB to use.

**5. Fetch full annotation values from a matching ingress**

Once the user selects an LB, use `resources_get` on one of the ingresses that references that LB name:

```
CallMcpTool:
  server: user-kubernetes-mcp-server
  toolName: resources_get
  arguments:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    name: <ingress-name>
    namespace: <namespace>
    context: <cluster-context>
```

Extract the 3 required values from the ingress annotations:
- `loadBalancerName` ← `alb.ingress.kubernetes.io/load-balancer-name`
- `groupName` ← `alb.ingress.kubernetes.io/group.name`
- `securityGroups` ← `alb.ingress.kubernetes.io/security-groups`

**6. Repeat for each environment's cluster if they differ**

If the project deploys across different accounts/clusters (e.g., govcloud-int vs govcloud-prd), repeat the lookup for each cluster. Set the discovered values in the corresponding environment config files (`.ci/config/<env>.yaml`).

### External Ingress Defaults

- **Lower environments (sbx, int, stg):** Default to **internal-only** ingress. Do not enable external ingress unless the user explicitly requests it.
- **Production (prd):** Prompt the user: **"Which components/services need to be exposed externally (internet-facing) on production?"** Enable external ingress only for those components in `prd.yaml`.

### Example: Discovered Values Applied

After running the discovery procedure against a cluster where the user selected `acme-int-internal`:

```yaml
# values.yaml (base config, internal only)
components:
  api:
    ingress:
      internal:
        enabled: true
        loadBalancerName: "acme-int-internal"
        groupName: "acme-int-internal"
        securityGroups: "int-alb-internal, acme-int-alb-internal"
      external:
        enabled: false
```

```yaml
# config/prd.yaml (user selected api for external exposure)
components:
  api:
    ingress:
      internal:
        loadBalancerName: "acme-prd-internal"
        groupName: "acme-prd-internal"
        securityGroups: "prd-alb-internal, acme-prd-alb-internal"
      external:
        enabled: true
        loadBalancerName: "acme-prd-external"
        groupName: "acme-prd-external"
        securityGroups: "prd-alb-external, acme-prd-alb-external"
```

---

## Custom Healthcheck Path

### Automatic Probe Inheritance

**By default, the ALB healthcheck path is automatically inherited from your container probes!**

The chart automatically extracts the healthcheck path from your container's:
1. `readinessProbe.httpGet.path` (preferred)
2. `livenessProbe.httpGet.path` (fallback)

```yaml
components:
  myapp:
    containers:
      - name: myapp
        ports:
          - name: http
            containerPort: 8080
        readinessProbe:
          httpGet:
            path: /health    # ← ALB automatically uses this!
            port: http
    
    ingress:
      internal:
        enabled: true
        # healthcheckPath: "/health" ← Not needed! Auto-inherited from probe
```

**Result:** ALB healthcheck annotation is automatically set to `/health`

### Manual Override

You can still manually set a healthcheck path to override the probe-derived value:

```yaml
components:
  myapp:
    containers:
      - name: myapp
        readinessProbe:
          httpGet:
            path: /ready     # Kubernetes uses this for pod readiness
            port: http
    
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/health"  # ALB uses this instead
      external:
        enabled: true
        healthcheckPath: "/api/health"  # Different for external
```

### Priority Order

The healthcheck path is determined in this priority:

1. **Manual override** - `ingress.internal.healthcheckPath` or `ingress.external.healthcheckPath`
2. **Probe inheritance** - Extracted from container's `readinessProbe` or `livenessProbe`
3. **No annotation** - ALB uses default traffic path (typically `/`)

### When to Use Manual Override

✅ **Override when:**
- You need different healthcheck paths for internal vs external ALBs
- ALB requires a different endpoint than Kubernetes probes use
- You want to use a lighter healthcheck endpoint for ALB
- Your app has no httpGet probes (e.g., tcpSocket or exec probes)

❌ **No override needed when:**
- ALB should check the same endpoint as Kubernetes probes (most common case)
- Your container has a readinessProbe with httpGet.path defined
