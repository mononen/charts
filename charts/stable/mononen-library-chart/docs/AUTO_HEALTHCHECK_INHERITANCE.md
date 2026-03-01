# Automatic ALB Healthcheck Path Inheritance

## Overview

The common-library-chart now **automatically inherits ALB healthcheck paths from your container probes**. This eliminates duplicate configuration and follows the DRY (Don't Repeat Yourself) principle.

## How It Works

### Automatic Extraction

The chart extracts the healthcheck path from your first container's probes in this priority:

1. **readinessProbe.httpGet.path** (preferred - indicates the app is ready to serve traffic)
2. **livenessProbe.httpGet.path** (fallback - indicates the app is alive)

### Example: Zero Configuration Needed

```yaml
global:
  clientCode: myorg
  project: myapp
  env: dev
  domain: example.com

components:
  api:
    enabled: true
    containers:
      - name: api
        image:
          repository: myorg/api
        ports:
          - name: http
            containerPort: 8080
        # Define your probe once
        readinessProbe:
          httpGet:
            path: /health      # ← ALB automatically uses this!
            port: http
          periodSeconds: 5
          timeoutSeconds: 3
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          periodSeconds: 10
    
    service:
      port: 80
    
    ingress:
      internal:
        enabled: true
        # No healthcheckPath needed - automatically uses /health!
      external:
        enabled: true
        # Also automatically uses /health!
```

**Generated Ingress Annotations:**
```yaml
alb.ingress.kubernetes.io/healthcheck-path: "/health"
```

## Priority System

The healthcheck path is determined using a three-level priority:

### 1. Manual Override (Highest Priority)

Explicitly set `healthcheckPath` to override automatic inheritance:

```yaml
components:
  api:
    containers:
      - name: api
        readinessProbe:
          httpGet:
            path: /ready      # K8s uses this
            port: http
    
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/health"  # ALB uses THIS instead
```

**Result:** ALB uses `/health`, Kubernetes uses `/ready`

### 2. Automatic Probe Inheritance (Default)

If no manual `healthcheckPath` is set, automatically extract from probes:

```yaml
components:
  api:
    containers:
      - name: api
        readinessProbe:
          httpGet:
            path: /health     # ← Automatically used
            port: http
    
    ingress:
      internal:
        enabled: true         # Inherits /health
```

**Result:** ALB uses `/health` (auto-inherited)

### 3. No Annotation (Fallback)

If no manual override AND no suitable probe exists:

```yaml
components:
  api:
    containers:
      - name: api
        # No httpGet probes (e.g., tcpSocket or exec probe)
    
    ingress:
      internal:
        enabled: true
```

**Result:** No healthcheck-path annotation (ALB uses default behavior)

## Common Patterns

### Pattern 1: Same Path for K8s and ALB (Recommended)

```yaml
components:
  myapp:
    containers:
      - name: myapp
        readinessProbe:
          httpGet:
            path: /health
            port: http
    ingress:
      internal:
        enabled: true
        # Auto-inherits /health
```

**Use when:** ALB and K8s should check the same endpoint (most common)

### Pattern 2: Different Paths for Internal vs External

```yaml
components:
  myapp:
    containers:
      - name: myapp
        readinessProbe:
          httpGet:
            path: /health
            port: http
    ingress:
      internal:
        enabled: true
        # Auto-inherits /health
      external:
        enabled: true
        healthcheckPath: "/health/external"  # Override for external
```

**Use when:** External ALB needs more thorough healthcheck

### Pattern 3: ALB Uses Lighter Check Than K8s

```yaml
components:
  myapp:
    containers:
      - name: myapp
        readinessProbe:
          httpGet:
            path: /ready/full  # Thorough check for K8s
            port: http
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/ping"  # Lighter check for ALB
```

**Use when:** K8s needs comprehensive readiness but ALB just needs basic health

### Pattern 4: ReadinessProbe for Auto-Inheritance

```yaml
components:
  myapp:
    containers:
      - name: myapp
        livenessProbe:
          httpGet:
            path: /live      # K8s liveness
            port: http
        readinessProbe:
          httpGet:
            path: /ready     # ← ALB uses this (preferred)
            port: http
    ingress:
      internal:
        enabled: true         # Inherits /ready
```

**Result:** ALB uses `/ready` (readinessProbe takes priority over livenessProbe)

### Pattern 5: Only LivenessProbe Available

```yaml
components:
  myapp:
    containers:
      - name: myapp
        livenessProbe:
          httpGet:
            path: /health     # ← ALB falls back to this
            port: http
        # No readinessProbe
    ingress:
      internal:
        enabled: true         # Inherits /health from livenessProbe
```

**Result:** ALB uses `/health` from livenessProbe

## Non-HTTP Probes

If your container uses non-HTTP probes (tcpSocket, exec), automatic inheritance won't work:

```yaml
components:
  myapp:
    containers:
      - name: myapp
        livenessProbe:
          tcpSocket:           # Can't extract path from TCP probe
            port: 8080
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/health"  # Must set manually
```

## Testing

Verify automatic inheritance:

```bash
# Template the chart
helm template my-release . -f values.yaml

# Check for healthcheck-path annotation
helm template my-release . -f values.yaml | grep "healthcheck-path"
```

Expected output with automatic inheritance:
```
alb.ingress.kubernetes.io/healthcheck-path: "/health"
```

## Migration Benefits

### Before (Duplicate Configuration)

```yaml
containers:
  - name: api
    readinessProbe:
      httpGet:
        path: /health       # Defined here
        port: http
ingress:
  internal:
    enabled: true
    healthcheckPath: "/health"  # AND here (duplicate!)
```

**Problems:**
- Configuration duplication
- Easy to get out of sync
- More verbose

### After (Automatic - DRY)

```yaml
containers:
  - name: api
    readinessProbe:
      httpGet:
        path: /health       # Define once
        port: http
ingress:
  internal:
    enabled: true
    # Automatically uses /health!
```

**Benefits:**
- Single source of truth
- Less configuration to maintain
- Can't get out of sync
- More concise

## Edge Cases

### Multiple Containers

Only the **first container** in the containers array is checked:

```yaml
containers:
  - name: main          # ← This container's probes are used
    readinessProbe:
      httpGet:
        path: /health
        port: http
  - name: sidecar       # This container's probes are ignored
    readinessProbe:
      httpGet:
        path: /sidecar/health
        port: http
```

**Result:** ALB uses `/health` from the main container

### No Suitable Probes

If first container has no httpGet probes:

```yaml
containers:
  - name: main
    livenessProbe:
      exec:
        command: ["healthcheck.sh"]
```

**Result:** No healthcheck-path annotation (must set manually if needed)

## Backward Compatibility

All existing configurations continue to work:

1. **Explicit healthcheckPath** - Takes priority, works as before
2. **Manual annotations** - Still supported
3. **No healthcheck config** - Now gets automatic inheritance (new feature)

## Best Practices

1. ✅ **Use readinessProbe with httpGet** for best automatic inheritance
2. ✅ **Let automatic inheritance work** unless you need different paths
3. ✅ **Use manual override** only when ALB needs different path than K8s
4. ✅ **Document why** if you override (add comment explaining the reason)
5. ❌ **Don't duplicate** - Remove manual healthcheckPath if it matches your probe

## Troubleshooting

### Healthcheck not being set?

Check that:
1. First container has a readinessProbe or livenessProbe
2. The probe is httpGet type (not tcpSocket or exec)
3. The probe has a `path` field defined

### Wrong path being used?

Remember the priority:
1. Manual healthcheckPath (highest)
2. readinessProbe.httpGet.path
3. livenessProbe.httpGet.path
4. None (lowest)

### Need to debug?

Template the chart and inspect:

```bash
helm template my-release . -f values.yaml > output.yaml
grep -A 5 "healthcheck-path" output.yaml
```
