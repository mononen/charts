# Values.yaml Patterns

**Purpose:** Complete values.yaml structure examples and patterns for the common-library-chart.

## Minimal Configuration

> **CRITICAL**: Every component MUST include an explicit `generate` block listing all resource types, even when all values are `true` (the defaults). This makes the chart self-documenting and ensures teams can immediately see which resources each component produces.

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

## Full Configuration Template

```yaml
############# Global Configuration #################
global:
  # Identity
  clientCode: myorg           # Organization/client identifier
  project: myapp              # Project name
  env: dev                    # Environment (dev, stg, prd)
  namespace: myorg            # Kubernetes namespace
  
  # Networking
  domain: example.com         # Primary domain
  altDomain: ""               # Alternate domain (optional)
  domainOverride: ""          # Override computed FQDN (optional)
  
  # Security (enabled by default)
  security:
    enabled: true
    podSecurityContext:
      runAsNonRoot: true
      runAsUser: 1000
      runAsGroup: 1000
      fsGroup: 1000
    containerSecurityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
  
  # Image defaults
  imageDefaults:
    registry: registry.example.com
    pullPolicy: IfNotPresent
    pullSecrets:
      - name: regcred
  
  # Logging
  logs:
    lokiEndpoint: ""          # Set to your Loki endpoint (e.g., https://loki.example.com)
  logging:
    image:
      repository: grafana/alloy
      tag: v1.9.1

##################################
#       COMPONENTS               #
##################################
components:
  myapp:
    enabled: true
    
    # Use primaryComponent: true for main component to avoid name suffix
    primaryComponent: false
    
    # Control which resources the library generates
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: false          # Set false if using custom ingress
    
    # Static replica count (when autoscaling disabled)
    replicaCount: 1
    
    # Container definitions
    containers:
      - name: myapp
        image:
          registry: ""        # Falls back to global.imageDefaults.registry
          repository: myorg/myapp
          tag: ""             # Falls back to Chart.AppVersion
        pullPolicy: ""        # Falls back to global.imageDefaults.pullPolicy
        ports:
          - name: http
            containerPort: 8080
            protocol: TCP
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /health
            port: http
          periodSeconds: 10
          timeoutSeconds: 5
          initialDelaySeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 5
          timeoutSeconds: 3
          initialDelaySeconds: 5
          successThreshold: 1
          failureThreshold: 3
        env:
          - name: APP_ENV
            value: "production"
        envFrom:
          - secretRef:
              name: my-secrets
        volumeMounts:
          - name: data
            mountPath: /data
    
    # Additional sidecars (optional)
    sidecars: []
    
    # Init containers (optional)
    initContainers: []
    
    # Volumes
    volumes:
      - name: data
        emptyDir: {}
    
    # Service configuration
    service:
      type: ClusterIP
      port: 80
      targetPort: http
      annotations: {}
      additionalPorts: []
    
    # Ingress configuration
    ingress:
      className: ""           # ingressClassName (e.g., nginx, traefik)
      subdomain: ""           # Override subdomain (defaults to component name)
      annotations: {}         # Shared annotations for all ingress types
      internal:
        enabled: true
        className: ""         # Override ingressClassName for this type
        annotations: {}       # Per-type annotations (merged with shared)
        paths: []             # Custom path routing (defaults to / -> service)
        tls: []               # TLS configuration
      external:
        enabled: false
        className: ""
        annotations: {}
        paths: []
        tls: []
    
    # Autoscaling (generated when generate.hpa: true)
    autoscaling:
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 80
      targetMemoryUtilizationPercentage: 80
    
    # Pod Disruption Budget (generated when generate.pdb: true)
    pdb:
      minAvailable: 1
    
    # Service Account (generated when generate.serviceaccount: true)
    serviceAccount:
      name: ""
      annotations: {}
    
    # Restart CronJob (generated when generate.restartCronJob: true)
    restartCronJob:
      schedule: "0 9 * * *"
    
    # Prometheus ServiceMonitor (generated when generate.serviceMonitor: true)
    serviceMonitor:
      interval: 30s
      scrapeTimeout: 10s
    
    # Component-specific security override
    security:
      enabled: null            # null = inherit from global
    
    # Logging sidecar (Alloy/Loki) - generated when generate.logging: true
    logging: {}
    
    # Pod configuration
    podAnnotations: {}
    nodeSelector: {}
    tolerations: []
    affinity: {}
```

## Environment-Specific Overrides

> **CRITICAL: Never Override Arrays in Environment Configs**
>
> Helm REPLACES arrays entirely. If you override `containers` in env configs, you lose ports, probes, resources, etc. defined in base `values.yaml`.

### Correct Pattern

```yaml
# config/sbx.yaml - CORRECT
global:
  env: sbx

components:
  myapp:
    replicaCount: 1            # OK - scalar value
    generate:
      hpa: false               # OK - disable HPA for sandbox
      pdb: false               # OK - disable PDB for sandbox
    # NO 'containers' - image tag set via --set
```

### Incorrect Pattern (DON'T DO THIS)

```yaml
# config/sbx.yaml - WRONG!
components:
  myapp:
    containers:                # REPLACES entire array!
      - name: myapp
        image:
          tag: "1.0.0"         # All other container config LOST!
```

### Environment File Examples

**Sandbox (minimal):**
```yaml
global:
  env: sbx

components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: false
      pdb: false
      serviceaccount: true
      ingress: true
    replicaCount: 1
    ingress:
      internal:
        enabled: true
      external:
        enabled: false
```

**Production (full):**
```yaml
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
    pdb:
      minAvailable: 2
    ingress:
      internal:
        enabled: true
      external:
        enabled: true
```

## Ingress Host Configuration

The ingress host is automatically generated from the subdomain and domain.

### Host Name Formula

```
Non-production: {subdomain}.{env}.{domain}
Production:     {subdomain}.{domain}
```

### Subdomain Configuration

```yaml
components:
  # Default: uses component name as subdomain
  api:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    ingress:
      className: nginx
      internal:
        enabled: true
  # Host: api.dev.example.com

  # Custom subdomain
  frontend:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    ingress:
      className: nginx
      subdomain: "app"
      internal:
        enabled: true
      external:
        enabled: true
  # Host: app.dev.example.com

  # Another custom subdomain
  admin:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    ingress:
      className: nginx
      subdomain: "admin-portal"
      internal:
        enabled: true
  # Host: admin-portal.dev.example.com
```

### When Ingresses Are Generated

Ingresses are generated when ALL conditions are met:
1. `components.<name>.enabled: true`
2. `global.resources.ingresses: true` (default)
3. `components.<name>.generate.ingress` is not `false`
4. At least one of `internal.enabled` (default: true) or `external.enabled` (default: false) is true

### Disabling Ingresses

```yaml
# Disable for a component via generate block
components:
  worker:
    generate:
      deployment: true
      service: false
      hpa: true
      pdb: false
      serviceaccount: true
      ingress: false           # No ingress generated

# Or disable both types explicitly
components:
  internal-service:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true            # Ingress generation on, but both types disabled below
    ingress:
      internal:
        enabled: false
      external:
        enabled: false
```

## Deployment Command

```bash
helm upgrade --install myapp . \
  -f values.yaml \
  -f config/prd.yaml \
  --set global.imageDefaults.tag=${VERSION}
```

## Naming Convention

Resources are named using the pattern: `{Release.Name}-{componentName}`

**Example:**
```yaml
# Release name: myorg-myapp
components:
  api:
    enabled: true
```

Generates:
- Deployment: `myorg-myapp-api`
- Service: `myorg-myapp-api`
- HPA: `myorg-myapp-api`

**With `primaryComponent: true`:**
- Deployment: `myorg-myapp` (no `-api` suffix)
- Service: `myorg-myapp`
