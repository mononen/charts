# ALB Healthcheck Path - Enhancement Summary

## What Was Implemented

The ALB healthcheck path configuration now features **automatic inheritance from Kubernetes probes** with optional manual override support.

## Key Features

### 1. Automatic Probe Inheritance (NEW!)

The chart automatically extracts healthcheck paths from your container's `readinessProbe` or `livenessProbe`:

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
        # No configuration needed!
```

**Result:** `alb.ingress.kubernetes.io/healthcheck-path: "/health"` is automatically added.

### 2. Manual Override (ENHANCED!)

Override when you need different paths for ALB vs Kubernetes:

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

### 3. Priority System

1. **Manual `healthcheckPath`** (highest priority)
2. **Auto-extracted from `readinessProbe.httpGet.path`**
3. **Auto-extracted from `livenessProbe.httpGet.path`** (fallback)
4. **No annotation** (ALB uses default traffic path)

## Technical Implementation

### New Helper Function

**File:** `templates/_helpers.tpl`

```go
{{- define "common.healthcheckPathFromProbe" -}}
{{- $component := .component | default dict }}
{{- $containers := $component.containers | default list }}
{{- if $containers }}
{{- $firstContainer := index $containers 0 }}
{{- /* Try readinessProbe first */ -}}
{{- if and $firstContainer.readinessProbe $firstContainer.readinessProbe.httpGet $firstContainer.readinessProbe.httpGet.path }}
{{- $firstContainer.readinessProbe.httpGet.path }}
{{- /* Fall back to livenessProbe */ -}}
{{- else if and $firstContainer.livenessProbe $firstContainer.livenessProbe.httpGet $firstContainer.livenessProbe.httpGet.path }}
{{- $firstContainer.livenessProbe.httpGet.path }}
{{- end }}
{{- end }}
{{- end }}
```

### Updated ALB Helpers

Both `common.ingress.alb.internal` and `common.ingress.alb.external` now:
- Accept `component` parameter
- Call `common.healthcheckPathFromProbe` to extract path
- Use manual `config.healthcheckPath` as override if provided

### Updated Ingress Template

`templates/_ingress.tpl` now passes `component` data to ALB helpers.

## Benefits

| Benefit | Description |
|---------|-------------|
| **DRY Configuration** | Define healthcheck path once in probes, used everywhere |
| **Zero Config** | Most apps need no additional configuration for ALB healthchecks |
| **Intelligent** | Prefers readinessProbe (most appropriate for healthchecks) |
| **Flexible** | Manual override available when needed |
| **Backward Compatible** | Existing manual configs continue to work |

## Before vs After

### Before (Duplicate Configuration)

```yaml
components:
  api:
    containers:
      - name: api
        readinessProbe:
          httpGet:
            path: /health       # Defined here
            port: http
    ingress:
      internal:
        enabled: true
        healthcheckPath: "/health"  # AND duplicated here!
```

**Problems:**
- Duplicate configuration
- Can get out of sync
- More verbose

### After (Automatic Inheritance)

```yaml
components:
  api:
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
- Can't get out of sync
- Less to maintain
- More concise

## Documentation Updated

All documentation has been updated to reflect automatic inheritance:

1. **ALB_INGRESS_CONFIG.md** - Complete reference with automatic inheritance examples
2. **HEALTHCHECK_PATH_SUMMARY.md** - Quick start guide
3. **VALUES_PATTERNS.md** - Updated ingress config patterns
4. **AUTO_HEALTHCHECK_INHERITANCE.md** - Comprehensive guide to automatic inheritance
5. **CHANGELOG_HEALTHCHECK.md** - Detailed changelog
6. **examples/healthcheck-path-example.yaml** - Working examples
7. **values.yaml** - Updated comments
8. **modify-chart SKILL.md** - Updated skill documentation

## Use Cases

### Use Case 1: Standard App (90% of cases)

```yaml
# Just define your probe - ALB inherits automatically
readinessProbe:
  httpGet:
    path: /health
    port: http
```

**No additional config needed!**

### Use Case 2: Different Checks for Internal/External

```yaml
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

### Use Case 3: ALB Needs Different Path Than K8s

```yaml
readinessProbe:
  httpGet:
    path: /ready/thorough  # K8s comprehensive check
    port: http

ingress:
  internal:
    enabled: true
    healthcheckPath: "/ping"  # ALB lightweight check
```

## Testing

Verify automatic inheritance works:

```bash
# Template with a values file containing probes
helm template my-release . -f values.yaml | grep "healthcheck-path"
```

Expected output:
```
alb.ingress.kubernetes.io/healthcheck-path: "/health"
```

## Migration Path

### No Action Required

If your existing configuration already has:
- Manual `healthcheckPath` set → Continues to work (takes priority)
- No healthcheck config → Now gets automatic inheritance (new feature!)

### Optional Cleanup

If you have duplicate configuration:

```yaml
# OLD - Can simplify
readinessProbe:
  httpGet:
    path: /health
ingress:
  internal:
    healthcheckPath: "/health"  # Remove this line

# NEW - Cleaner
readinessProbe:
  httpGet:
    path: /health
ingress:
  internal:
    enabled: true  # Auto-inherits /health
```

## Edge Cases Handled

1. **Multiple containers** - Uses first container's probes
2. **No httpGet probes** - No annotation added (tcpSocket, exec probes not supported)
3. **No probes at all** - No annotation added
4. **Manual override** - Takes priority over auto-inheritance
5. **Different readiness/liveness paths** - Prefers readinessProbe

## Backward Compatibility

✅ All existing configurations work without changes:
- Explicit `healthcheckPath` → Takes priority
- Manual annotations → Still supported
- No healthcheck config → Gets automatic inheritance (new!)

## Next Steps

1. **Existing charts** - No changes required, works automatically
2. **New charts** - Just define probes, healthcheck inherits
3. **Cleanup** - Optionally remove duplicate `healthcheckPath` configs that match probes

## Questions?

See the comprehensive guides:
- [AUTO_HEALTHCHECK_INHERITANCE.md](./AUTO_HEALTHCHECK_INHERITANCE.md) - Complete guide
- [HEALTHCHECK_PATH_SUMMARY.md](./HEALTHCHECK_PATH_SUMMARY.md) - Quick start
- [ALB_INGRESS_CONFIG.md](./references/ALB_INGRESS_CONFIG.md) - Full reference
