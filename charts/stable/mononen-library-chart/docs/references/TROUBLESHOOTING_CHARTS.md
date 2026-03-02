# Chart Troubleshooting Guide

**Purpose:** Solutions for common Helm chart issues when using the common-library-chart.

## Template Errors

### Template Not Found Error

```
ERROR: template: ... no template "xxx" found
```

**Cause:** Helper template from deleted file is still referenced.

**Solution:** Create minimal `_helpers.tpl` with required helper definitions. Common helpers needed:

```yaml
# templates/_helpers.tpl
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

### Nil Pointer in Template

```
ERROR: nil pointer evaluating interface {}.xxx
```

**Cause:** Accessing nested value that doesn't exist.

**Solution:** Add `| default dict` when accessing nested values:

```yaml
# Wrong
{{- $component := .Values.components.myapp }}
{{- $service := $component.service }}

# Correct
{{- $component := .Values.components.myapp | default dict }}
{{- $service := $component.service | default dict }}
```

## Resource Generation Issues

### Resources Not Being Generated

```
Expected: Deployment, Service, HPA, PDB
Actual: No resources generated
```

**Cause:** Component not enabled or generate flag is false.

**Solution:**
1. Verify `enabled: true` on component:
   ```yaml
   components:
     myapp:
       enabled: true  # Must be true
   ```

2. Check `generate` flags:
   ```yaml
   components:
     myapp:
       generate:
         deployment: true   # Must be true for deployment
         service: true      # Must be true for service
   ```

### Double Component Suffix in Resource Names

```
Expected: myorg-myapp-api
Actual: myorg-myapp-api-api
```

**Cause:** Not using `primaryComponent: true` for main component.

**Solution:** Add `primaryComponent: true` to the main component:

```yaml
components:
  api:
    enabled: true
    primaryComponent: true  # Resources named without component suffix
```

## Ingress Issues

### Wrong Ingress Hosts in Different Environments

```
Expected: myorg-prd-internal
Actual: myorg-dev-internal (in production)
```

**Cause:** `global.env` not set correctly in environment-specific values file.

**Solution:** Verify `global.env` is set in each environment file:

```yaml
# config/prd.yaml
global:
  env: prd  # MUST match environment
```

### Missing Ingress Class

```
ERROR: Ingress does not have an IngressClass
```

**Solution:** Set the ingress class for your controller:

```yaml
components:
  myapp:
    ingress:
      className: nginx  # or traefik, etc.
```

## Values File Issues

### Container Config Lost After Helm Upgrade

**Cause:** Overriding `containers` array in environment config.

**Solution:** NEVER override arrays in environment configs:

```yaml
# WRONG - replaces entire containers array
components:
  myapp:
    containers:
      - name: myapp
        image:
          tag: "1.0.0"

# CORRECT - use --set for tag
# helm upgrade --set global.imageDefaults.tag=1.0.0
```

### Image Pull Fails

```
ERROR: ErrImagePull - unauthorized
```

**Cause:** Image pull secret name doesn't match what's configured in the cluster.

**Solution:** Ensure pull secret name matches your registry credentials:

```yaml
global:
  imageDefaults:
    pullSecrets:
      - name: regcred  # Must match the secret name in your namespace
```

### Wrong Image Tag

```
Expected: 1.0.0-rc.vabc1234
Actual: (empty or wrong tag)
```

**Solution:** Image tags should be set via `--set` during deployment:

```bash
helm upgrade --install myapp . \
  -f values.yaml \
  -f config/prd.yaml \
  --set global.imageDefaults.tag=${VERSION}
```

## Dependency Issues

### Library Chart Not Found

```
ERROR: failed to locate chart
```

**Solution:**
1. Verify Chart.yaml has correct dependency:
   ```yaml
   dependencies:
     - name: mononen-library-chart
       version: "1.0.0"
       repository: "https://mononen.github.io/charts/"
   ```

2. Run dependency update:
   ```bash
   helm dependency update .
   ```

3. Check `charts/` directory has the downloaded chart.

### Version Mismatch

```
ERROR: Chart version doesn't match dependency
```

**Solution:** Update to correct version in Chart.yaml and re-run:

```bash
helm dependency update .
```

## Validation Errors

### YAML Syntax Error

```
ERROR: error converting YAML to JSON
```

**Solution:** Validate YAML syntax:

```bash
helm lint .
# or
yq eval values.yaml > /dev/null
```

Common issues:
- Missing quotes around special characters
- Incorrect indentation (use spaces, not tabs)
- Unclosed brackets or braces

### Dry-Run Fails

```
ERROR: validation failed
```

**Solution:** Test with dry-run and debug:

```bash
helm template test-release . > rendered.yaml
kubectl apply --dry-run=client -f rendered.yaml
```

## Debugging Commands

### View Generated Resources

```bash
# Template and save output
helm template test-release . > rendered.yaml

# Template with specific values
helm template test-release . -f values.yaml -f config/prd.yaml > rendered.yaml

# Debug template rendering
helm template test-release . --debug
```

### Check Values Resolution

```bash
# Show computed values
helm template test-release . --set global.env=prd --show-only templates/deployment.yaml
```

### Validate Against Cluster

```bash
kubectl apply --dry-run=server -f rendered.yaml
```

## Quick Reference: Common Fixes

| Issue | Likely Cause | Quick Fix |
|-------|--------------|-----------|
| Template not found | Missing helper | Add to `_helpers.tpl` |
| Nil pointer | Missing `default dict` | Add `\| default dict` |
| No resources | `enabled: false` | Set `enabled: true` |
| Double suffix | Missing primaryComponent | Add `primaryComponent: true` |
| Wrong ingress hosts | Wrong `global.env` | Check env config files |
| Image pull fails | Wrong secret name | Check `pullSecrets` name matches cluster secret |
| Config lost | Array override | Never override `containers[]` |
| Chart not found | Missing dependency | Run `helm dependency update` |
