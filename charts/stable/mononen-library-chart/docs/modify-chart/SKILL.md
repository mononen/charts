---
name: modify-chart
description: Modify existing Helm charts - add ingress, containers, sidecars, storage, secrets, CronJobs, or Jobs. Use when updating an existing values.yaml or chart.
---

# Modify Existing Helm Chart

Use this skill when making **incremental changes** to an existing Helm chart using the common-library-chart.

> **CRITICAL**: Every component MUST include an explicit `generate` block listing all resource types (`deployment`, `service`, `hpa`, `pdb`, `serviceaccount`, `ingress`), even when all values are `true` (the defaults). This makes the chart self-documenting and prevents surprises. When adding or modifying any component, always include or preserve the `generate` block.

> **CRITICAL**: Do NOT guess or invent ingress ALB values. When a component has ingress enabled, you MUST discover the 3 required values (`loadBalancerName`, `groupName`, `securityGroups`) from existing ingresses in the target cluster using the Kubernetes MCP tool. See the **Ingress Value Discovery** section below for the full procedure.

## Recipes

### Set Custom ALB Healthcheck Path

**By default, the ALB healthcheck path is automatically inherited from your container probes!**

```yaml
components:
  myapp:
    containers:
      - name: myapp
        readinessProbe:
          httpGet:
            path: /health    # ← ALB automatically uses this!
            port: http
    
    ingress:
      internal:
        enabled: true
        # No healthcheckPath needed - auto-inherited from probe!
```

**Manual override when needed:**

```yaml
components:
  myapp:
    containers:
      - name: myapp
        readinessProbe:
          httpGet:
            path: /ready     # K8s uses this
            port: http
    
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/health"     # ALB uses this instead
      external:
        enabled: true
        healthcheckPath: "/api/health" # Different for external
```

**Priority:**
1. Manual `healthcheckPath` (override)
2. Auto-inherited from `readinessProbe` or `livenessProbe`
3. Not set (ALB uses default traffic path)

**When to use manual override:**
- Different paths needed for internal vs external ALBs
- ALB needs different endpoint than K8s probes
- Container uses non-httpGet probes (tcpSocket, exec)

### Add Another Ingress

> **REMINDER**: Discover `loadBalancerName`, `groupName`, and `securityGroups` from existing ingresses in the target cluster using the Kubernetes MCP tool. See the **Ingress Value Discovery** section below. Never invent these values.

**Basic internal ingress:**

```yaml
components:
  myapp:
    ingress:
      internal:
        enabled: true
        loadBalancerName: "discovered-from-cluster"
        groupName: "discovered-from-cluster"
        securityGroups: "discovered-from-cluster"
        groupOrder: "100"
```

Host: `myapp.{env}.{domain}` (uses component name as subdomain)

**Custom subdomain:**

```yaml
components:
  myapp:
    ingress:
      subdomain: "api"       # Override default subdomain
      internal:
        enabled: true
        loadBalancerName: "discovered-from-cluster"
        groupName: "discovered-from-cluster"
        securityGroups: "discovered-from-cluster"
        groupOrder: "100"
```

Host: `api.{env}.{domain}` (e.g., `api.dev.example.com`)

**Enable external ingress (alongside internal):**

```yaml
components:
  myapp:
    ingress:
      subdomain: "app"       # Custom subdomain
      internal:
        enabled: true
        loadBalancerName: "discovered-internal-lb"
        groupName: "discovered-internal-group"
        securityGroups: "discovered-internal-sgs"
        groupOrder: "100"
      external:
        enabled: true
        loadBalancerName: "discovered-external-lb"
        groupName: "discovered-external-group"
        securityGroups: "discovered-external-sgs"
        groupOrder: "100"
```

Creates both internal and external ingresses at `app.{env}.{domain}`

**Disable ingress for a component:**

```yaml
components:
  worker:
    generate:
      ingress: false         # No ingress generated for workers
```

See `references/ALB_INGRESS_CONFIG.md` for complete ALB annotation patterns and ingress generation details.

### Add a Sidecar Container

Add to the `containers` array in the base values.yaml:

```yaml
components:
  myapp:
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
        ports:
          - name: http
            containerPort: 8080
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
      # Add sidecar:
      - name: sidecar
        image:
          repository: myorg/sidecar
        ports:
          - name: metrics
            containerPort: 9090
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
```

> **CRITICAL**: Always modify containers in base `values.yaml`, never in environment configs (Helm replaces arrays entirely).

### Add an Init Container

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    initContainers:
      - name: init-db
        image:
          repository: busybox
          tag: "1.35"
        command: ['sh', '-c', 'until nslookup db; do sleep 2; done']
        resources:
          limits:
            cpu: 100m
            memory: 64Mi
      - name: init-config
        image:
          repository: myorg/config-init
        volumeMounts:
          - name: config
            mountPath: /config
```

### Add Persistent Storage

**With PersistentVolumeClaim:**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    volumes:
      - name: data
        persistentVolumeClaim:
          claimName: my-data-pvc
    containers:
      - name: myapp
        volumeMounts:
          - name: data
            mountPath: /data
```

**With EmptyDir (ephemeral):**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    volumes:
      - name: cache
        emptyDir: {}
      - name: tmp
        emptyDir:
          sizeLimit: 1Gi
    containers:
      - name: myapp
        volumeMounts:
          - name: cache
            mountPath: /var/cache
          - name: tmp
            mountPath: /tmp
```

### Add a ConfigMap

**Define ConfigMap in component:**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    configMaps:
      - suffix: "config"      # Creates: release-myapp-config
        data:
          app.conf: |
            setting1=value1
            setting2=value2
```

**Mount as volume:**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    volumes:
      - name: config
        configMap:
          name: myapp-config
    containers:
      - name: myapp
        volumeMounts:
          - name: config
            mountPath: /etc/myapp
```

**Mount as environment variables:**

```yaml
containers:
  - name: myapp
    envFrom:
      - configMapRef:
          name: myapp-config
```

### Add a Secret

**Define Secret in component:**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    secrets:
      - suffix: "credentials"  # Creates: release-myapp-credentials
        type: Opaque
        stringData:            # Plain text (use stringData, not data)
          username: admin
          password: secret
```

**Mount as environment variable:**

```yaml
containers:
  - name: myapp
    env:
      - name: DB_PASSWORD
        valueFrom:
          secretKeyRef:
            name: db-credentials
            key: password
```

**Mount as volume:**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    volumes:
      - name: certs
        secret:
          secretName: myapp-tls
    containers:
      - name: myapp
        volumeMounts:
          - name: certs
            mountPath: /etc/ssl/certs
            readOnly: true
```

### Add a CronJob

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    cronJobs:
      - enabled: true
        schedule: "0 2 * * *"       # 2 AM daily
        command: ["python", "backup.py"]
        args: ["--full"]
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
        concurrencyPolicy: Forbid
        restartPolicy: OnFailure
```

See `references/COMPONENT_EXAMPLES.md` for full CronJob configuration.

### Add a Job (Helm Hook)

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    jobs:
      - enabled: true
        command: ["python", "migrate.py"]
        args: ["--apply"]
        hook: pre-install,pre-upgrade
        hookWeight: "0"
        hookDeletePolicy: before-hook-creation
        ttlSecondsAfterFinished: 300
        restartPolicy: Never
```

### Enable Logging Sidecar

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
      logging: true
```

> **WARNING**: Do NOT override `global.logs.lokiEndpoint` or `global.logging.image` - these are infrastructure-managed defaults.

See `references/LOGGING_SIDECARS.md` for Alloy/Loki configuration details.

### Add ServiceMonitor for Prometheus

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
      serviceMonitor: true
    serviceMonitor:
      interval: 30s
      scrapeTimeout: 10s
```

**Multiple endpoints:**

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
      serviceMonitor: true
    serviceMonitor:
      endpoints:
        - port: metrics
          interval: 30s
        - port: app-metrics
          path: /app/metrics
          interval: 30s
```

### Add Another Component

```yaml
components:
  api:
    enabled: true
    primaryComponent: true    # Main component (no name suffix)
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    containers:
      - name: api
        # ...
    service:
      port: 80

  # Add new component:
  worker:
    enabled: true
    generate:
      deployment: true
      service: false           # Workers typically don't need a service
      hpa: true
      pdb: false               # No PDB for workers
      serviceaccount: true
      ingress: false            # Workers don't need ingress
    containers:
      - name: worker
        image:
          repository: myorg/worker
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
```

### Enable Autoscaling

```yaml
components:
  myapp:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    autoscaling:
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 80
      targetMemoryUtilizationPercentage: 80
```

### Skip Specific Resources

Always include the full `generate` block with every key explicitly set:

```yaml
components:
  stateless-worker:
    generate:
      deployment: true         # Still need a deployment
      service: false           # No service needed
      hpa: false               # Using KEDA instead
      pdb: false               # No PDB for stateless workers
      serviceaccount: false    # Use default service account
      ingress: false           # No ingress needed
```

## Ingress Value Discovery (via Kubernetes MCP)

When adding or modifying ingress configuration, discover ALB parameters from existing ingresses in the target cluster instead of asking the user to provide them manually.

### Procedure

1. **List available cluster contexts:**
   ```
   CallMcpTool:
     server: user-kubernetes-mcp-server
     toolName: configuration_contexts_list
   ```
   Cross-reference with `global-config.yml` to identify which context corresponds to the project's target cluster.

2. **List ingresses in the target cluster:**
   ```
   CallMcpTool:
     server: user-kubernetes-mcp-server
     toolName: resources_list
     arguments:
       apiVersion: networking.k8s.io/v1
       kind: Ingress
       context: <cluster-context>
   ```

3. **Extract unique load balancer names** from `alb.ingress.kubernetes.io/load-balancer-name` annotations. Group by `alb.ingress.kubernetes.io/scheme` (`internal` vs `internet-facing`). There are multiple LBs per cluster, each with different purposes.

4. **Prompt the user** to select which load balancer to use for this project's internal ingress (and external, if applicable).

5. **Fetch a matching ingress** using `resources_get` and extract the full set of values:
   - `loadBalancerName` from `alb.ingress.kubernetes.io/load-balancer-name`
   - `groupName` from `alb.ingress.kubernetes.io/group.name`
   - `securityGroups` from `alb.ingress.kubernetes.io/security-groups`

6. **Repeat for each environment's cluster** if they differ (e.g., govcloud-int vs govcloud-prd).

### External Ingress Defaults

- **Lower environments (sbx, int, stg):** Default to internal-only ingress. Do not enable external ingress unless the user explicitly requests it.
- **Production (prd):** Prompt the user: "Which components/services need to be exposed externally (internet-facing) on production?" Enable external ingress only for those components in `prd.yaml`.

## Validation

After modifying values.yaml:

```bash
cd .ci/chart
helm dependency update
helm lint .
helm template my-release . > rendered.yaml
```

Review `rendered.yaml` to verify the changes generate expected resources.

## Common Issues

See `references/TROUBLESHOOTING_CHARTS.md` for detailed solutions:

- **Template not found** - Check _helpers.tpl exists
- **Nil pointer** - Add `| default dict` for nested values
- **Resources not generating** - Check `generate` block flags are set to `true`
- **Wrong ALB names** - Verify `global.env` is set in env configs

## Related References

- `references/COMPONENT_EXAMPLES.md` - Multi-container, storage, secrets, CronJobs
- `references/ALB_INGRESS_CONFIG.md` - Ingress annotation helpers
- `references/VALUES_PATTERNS.md` - Complete values.yaml templates
- `references/LOGGING_SIDECARS.md` - Alloy/Loki configuration
- `references/TROUBLESHOOTING_CHARTS.md` - Issue resolution
