# Logging Sidecars (Alloy/Loki)

**Purpose:** Configuration guide for adding logging sidecars using Alloy to ship logs to Loki.

> **Global Configuration**
>
> The following settings are configured globally and shared across all components:
> - Sidecar image: `grafana/alloy:v1.9.1` (via `global.logging.image`)
> - Loki endpoint: configured via `global.logs.lokiEndpoint`
> - Auth secret: `loki-auth`

## Basic Configuration

Enable logging sidecar for a component:

```yaml
components:
  myapp:
    generate:
      logging: true
    logging:
      appName: "my-application"    # Optional, defaults to fullname
      logTargets:
        - name: app-logs           # Volume name
          jobs:
            - name: app-stdout
              sidecarLogfile: application.log
              autoConfigure: true
              level: info
```

## Volume Configuration

Your application must write logs to a shared volume that the sidecar can access:

```yaml
components:
  myapp:
    containers:
      - name: myapp
        volumeMounts:
          - name: app-logs         # Must match logTarget name
            mountPath: /var/log/app
    
    volumes:
      - name: app-logs
        emptyDir: {}
    
    generate:
      logging: true
    logging:
      logTargets:
        - name: app-logs           # Matches volume name
          jobs:
            - name: app-stdout
              sidecarLogfile: application.log
              autoConfigure: true
```

The sidecar automatically mounts the volume at `/var/log/<name>` (e.g., `/var/log/app-logs`).

## Multiple Log Files

Collect multiple log files from the same volume:

```yaml
components:
  myapp:
    generate:
      logging: true
    logging:
      logTargets:
        - name: app-logs
          jobs:
            - name: app-stdout
              sidecarLogfile: stdout.log
              autoConfigure: true
              level: info
            - name: app-errors
              sidecarLogfile: stderr.log
              autoConfigure: true
              level: error
            - name: app-access
              sidecarLogfile: access.log
              autoConfigure: true
```

## Multiple Volumes

Collect logs from multiple directories:

```yaml
components:
  myapp:
    volumes:
      - name: app-logs
        emptyDir: {}
      - name: nginx-logs
        emptyDir: {}
    
    containers:
      - name: myapp
        volumeMounts:
          - name: app-logs
            mountPath: /var/log/app
      - name: nginx
        volumeMounts:
          - name: nginx-logs
            mountPath: /var/log/nginx
    
    generate:
      logging: true
    logging:
      logTargets:
        - name: app-logs
          jobs:
            - name: app-stdout
              sidecarLogfile: app.log
              autoConfigure: true
        - name: nginx-logs
          jobs:
            - name: nginx-access
              sidecarLogfile: access.log
              autoConfigure: true
            - name: nginx-error
              sidecarLogfile: error.log
              autoConfigure: true
```

## Log Target Configuration

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Volume name (mounted at `/var/log/<name>` in sidecar) |
| `jobs[].name` | Yes | Job name for Loki labels |
| `jobs[].sidecarLogfile` | Yes | Filename to collect from volume |
| `jobs[].autoConfigure` | No | Auto-generate scrape config (default: true) |
| `jobs[].level` | No | Optional log level label |

## Sidecar Defaults

These values are configured globally:

| Setting | Value |
|---------|-------|
| Image | `grafana/alloy:v1.9.1` |
| Loki Endpoint | Configured via `global.logs.lokiEndpoint` |
| Auth Secret | `loki-auth` |
| Memory Limit | `256Mi` |
| CPU Request | `50m` |
| Memory Request | `64Mi` |

## Complete Example

```yaml
global:
  clientCode: myorg
  project: myapp
  logs:
    lokiEndpoint: "https://loki.example.com"

components:
  api:
    enabled: true
    
    volumes:
      - name: api-logs
        emptyDir: {}
    
    containers:
      - name: api
        image:
          repository: myorg/api
        volumeMounts:
          - name: api-logs
            mountPath: /var/log/api
        # Application should log to:
        # - /var/log/api/application.log
        # - /var/log/api/errors.log
    
    generate:
      logging: true
    logging:
      appName: "myorg-api"
      logTargets:
        - name: api-logs
          jobs:
            - name: api-application
              sidecarLogfile: application.log
              autoConfigure: true
              level: info
            - name: api-errors
              sidecarLogfile: errors.log
              autoConfigure: true
              level: error
```

## Application Requirements

For logs to be collected:

1. **Write to shared volume:** Application must write logs to the mounted volume path
2. **Use expected filename:** Filename must match `sidecarLogfile` configuration
3. **Text format:** Logs should be in text format (JSON or plain text)

**Example application configuration:**

```yaml
# For a Laravel application
LOG_CHANNEL=single
LOG_PATH=/var/log/api/application.log

# For a Node.js application
LOG_FILE=/var/log/api/application.log
```

## Troubleshooting

### Logs Not Appearing in Loki

1. **Check volume mount:** Verify volume is mounted in both app container and sidecar
2. **Check filename:** Ensure `sidecarLogfile` matches actual filename
3. **Check app logging:** Verify application is writing to correct path
4. **Check sidecar logs:** `kubectl logs <pod> -c alloy`

### Sidecar Not Starting

1. **Check auth secret:** Verify `loki-auth` secret exists in namespace
2. **Check image pull:** Verify the sidecar image is accessible from your cluster

### High Memory Usage

The sidecar is limited to 256Mi. If processing high-volume logs:
1. Consider reducing log verbosity
2. Split logs across multiple targets
3. Override resource limits in component logging config

## Labels Added to Logs

The sidecar automatically adds these labels to logs:

| Label | Value |
|-------|-------|
| `app` | From `logging.appName` or release fullname |
| `namespace` | Kubernetes namespace |
| `pod` | Pod name |
| `container` | Container name |
| `job` | From `jobs[].name` |
| `level` | From `jobs[].level` (if set) |
