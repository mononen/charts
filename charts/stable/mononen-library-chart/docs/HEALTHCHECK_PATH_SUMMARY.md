# ALB Healthcheck Path Configuration - Quick Start

## What's New

The ALB healthcheck path is now **automatically inherited from your container probes**! No manual configuration needed in most cases.

**Before:**
```yaml
readinessProbe:
  httpGet:
    path: /health
# AND manually set:
ingress:
  internal:
    healthcheckPath: "/health"  # Duplicate!
```

**After:**
```yaml
readinessProbe:
  httpGet:
    path: /health
# ALB automatically uses /health - no duplication!
```

## How It Works

### Automatic Inheritance (Recommended)

The chart automatically extracts the healthcheck path from your first container's probes:

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
        # No healthcheckPath needed - auto-inherited!
```

**Result:** ALB annotation `alb.ingress.kubernetes.io/healthcheck-path: "/health"` is automatically added.

### Manual Override (When Needed)

You can still manually set `healthcheckPath` to override the probe-derived value:

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
        healthcheckPath: "/health"  # ALB uses this instead
```

### Different Paths for Internal and External ALBs

```yaml
components:
  api:
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/health"
      external:
        enabled: true
        healthcheckPath: "/api/health"
```

### Complete Example with All Options

```yaml
global:
  clientCode: myorg
  project: myapp
  env: dev
  namespace: myorg
  domain: example.com
  certificateARN: "arn:aws:acm:..."
  
  alb:
    prefix: myorg

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
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
    
    service:
      port: 80
      targetPort: http
    
    ingress:
      subdomain: "api"
      internal:
        enabled: true
        groupOrder: "100"
        healthcheckPath: "/health"
      external:
        enabled: true
        groupOrder: "100"
        healthcheckPath: "/health"

    autoscaling:
      minReplicas: 2
      maxReplicas: 10
```

## Priority Order

The healthcheck path is determined in this priority:

1. **Manual override** - `healthcheckPath` in ingress config
2. **Probe inheritance** - Extracted from `readinessProbe` or `livenessProbe`
3. **No annotation** - ALB uses default traffic path

## Key Points

1. **Automatic** - Inherits from container probes by default (no duplication!)
2. **Optional override** - Set `healthcheckPath` when you need different paths for ALB vs K8s
3. **Per-Ingress** - Different paths for internal and external ALBs
4. **Backward Compatible** - Existing manual configurations continue to work

## What Gets Generated

When you set `healthcheckPath: "/health"`, the template generates:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: "/health"
    # ... other ALB annotations ...
```

## Common Use Cases

### 1. Dedicated Health Endpoint

```yaml
healthcheckPath: "/health"
```

### 2. Framework-Specific Endpoints

```yaml
# Spring Boot Actuator
healthcheckPath: "/actuator/health"

# Express.js
healthcheckPath: "/healthz"

# Django
healthcheckPath: "/health/"
```

### 3. API Versioning

```yaml
healthcheckPath: "/api/v1/health"
```

### 4. Different Ports (using service ports)

If your health endpoint is on a different port, configure it in the service:

```yaml
service:
  port: 80
  targetPort: http
  additionalPorts:
    - name: health
      port: 9090
      targetPort: 9090

ingress:
  internal:
    enabled: true
    healthcheckPath: "/health"
```

## Testing

Verify the configuration:

```bash
# Template the chart
helm template my-release . -f values.yaml

# Or grep for healthcheck-path
helm template my-release . -f values.yaml | grep "healthcheck-path"
```

Expected output:
```
alb.ingress.kubernetes.io/healthcheck-path: "/health"
```

## When to Use Manual Override

✅ **Use manual `healthcheckPath` when:**
- You need different paths for internal vs external ALBs
- ALB should check a different endpoint than Kubernetes probes
- You want a lighter healthcheck for ALB vs K8s probes
- Your container uses tcpSocket or exec probes (not httpGet)

❌ **No manual override needed when:**
- ALB should check the same path as your readinessProbe (most common!)
- You want to keep configuration DRY and maintainable

## Need Help?

See the full documentation:
- [ALB Ingress Configuration](./references/ALB_INGRESS_CONFIG.md)
- [Complete Example](./examples/healthcheck-path-example.yaml)
- [Values Patterns](./references/VALUES_PATTERNS.md)
