# Component Configuration Examples

**Purpose:** Detailed examples for common component patterns including multi-container pods, persistent storage, ConfigMaps, Secrets, CronJobs, and Jobs.

> **CRITICAL**: Every component MUST include an explicit `generate` block listing all resource types (`deployment`, `service`, `hpa`, `pdb`, `serviceaccount`, `ingress`), even when all values are `true` (the defaults). This makes the chart self-documenting and prevents surprises.

## Primary Component

Use for the main component to avoid name suffix:

```yaml
components:
  lms:
    enabled: true
    primaryComponent: true  # Resources named "release-name" not "release-name-lms"
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
```

## Multi-Container Pod

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
      - name: app
        image:
          repository: myorg/app
        ports:
          - name: http
            containerPort: 8080
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
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
          requests:
            cpu: 50m
            memory: 64Mi
```

## Persistent Storage

### With PersistentVolumeClaim

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

### With EmptyDir

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

## ConfigMaps

### Define ConfigMaps in Component

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
          nginx.conf: |
            server {
              listen 80;
            }
        annotations: {}
```

### Mount ConfigMap as Volume

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

### Mount ConfigMap as Environment Variables

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
        envFrom:
          - configMapRef:
              name: myapp-config
```

## Secrets

### Define Secrets in Component

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
        type: Opaque           # Default: Opaque
        stringData:            # Use stringData for plain text
          username: admin
          password: secret
        annotations: {}
```

### Use Base64-Encoded Data

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
      - suffix: "creds"
        data:                  # Base64-encoded values
          username: YWRtaW4=
          password: c2VjcmV0
```

### Mount Secret as Environment Variables

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
        envFrom:
          - secretRef:
              name: myapp-secrets
        env:
          - name: DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: db-credentials
                key: password
```

### Mount Secret as Volume

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

## Init Containers

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

## CronJobs

### Basic CronJob

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
        resources:
          limits:
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
```

### Full CronJob Configuration

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
        name: ""                    # Defaults to component name
        schedule: "0 2 * * *"       # Required
        command: ["python", "backup.py"]
        args: ["--full"]
        env:
          - name: BACKUP_TYPE
            value: "full"
        envFrom:
          - secretRef:
              name: backup-credentials
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        concurrencyPolicy: Forbid   # Forbid, Allow, or Replace
        successfulJobsHistoryLimit: 3
        failedJobsHistoryLimit: 1
        ttlSecondsAfterFinished: 86400
        backoffLimit: 3
        restartPolicy: OnFailure
        suspend: false
        volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
        volumeMounts:
          - name: backup-storage
            mountPath: /backup
```

## Jobs

### Basic Job

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
        restartPolicy: Never
```

### Helm Hook Job

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
        backoffLimit: 3
        activeDeadlineSeconds: 600
        restartPolicy: Never
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
        env:
          - name: DB_HOST
            valueFrom:
              secretKeyRef:
                name: db-credentials
                key: host
```

## ServiceMonitor

### Basic ServiceMonitor

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

### Multiple Endpoints

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
          scrapeTimeout: 10s
        - port: app-metrics
          interval: 30s
          scrapeTimeout: 10s
          path: /app/metrics
```

## Restart CronJob

Automatically rolls deployment on schedule:

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
      restartCronJob: true
    restartCronJob:
      schedule: "0 9 * * *"  # 9 AM daily
```

## Disable Security (Legacy Apps)

### Global Disable

```yaml
global:
  security:
    enabled: false
```

### Per-Component Disable

```yaml
components:
  legacy-app:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    security:
      enabled: false
```

### Custom Security Context

```yaml
components:
  special-app:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    security:
      enabled: true
      podSecurityContext:
        runAsUser: 0  # Run as root
        fsGroup: 0
      containerSecurityContext:
        allowPrivilegeEscalation: true
```

## Skip Specific Resources

```yaml
components:
  stateless-worker:
    generate:
      deployment: true
      service: false           # No service needed
      pdb: false               # No PDB for stateless workers
      hpa: false               # Using KEDA instead
      serviceaccount: false    # Use default service account
      ingress: false           # No ingress needed
```

## Ingress Configuration

### Basic Ingress (Internal Only)

```yaml
components:
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
```

Host: `api.{env}.{domain}` (e.g., `api.dev.example.com`)

### Custom Subdomain

```yaml
components:
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
      subdomain: "app"         # Override default (component name)
      internal:
        enabled: true
```

Host: `app.{env}.{domain}` (e.g., `app.dev.example.com`)

### Internal and External

```yaml
components:
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
      subdomain: "api"
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt
      internal:
        enabled: true
      external:
        enabled: true
```

Creates two Ingress resources:
- `{release}-api-internal` → Internal ingress
- `{release}-api-external` → External ingress (internet-facing)

### Custom Path Routing

```yaml
components:
  gateway:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    ingress:
      className: nginx
      subdomain: "api"
      internal:
        enabled: true
        paths:
          - path: /v1
            pathType: Prefix
            serviceName: api-v1
            servicePort: 80
          - path: /v2
            pathType: Prefix
            serviceName: api-v2
            servicePort: 80
```

### Disable Ingress for Component

```yaml
components:
  worker:
    generate:
      deployment: true
      service: false
      hpa: true
      pdb: false
      serviceaccount: true
      ingress: false           # No ingress generated
```

### Per-Type Annotations

```yaml
components:
  special-api:
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    ingress:
      className: nginx
      subdomain: "special"
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt
      internal:
        enabled: true
      external:
        enabled: true
        annotations:
          nginx.ingress.kubernetes.io/whitelist-source-range: "0.0.0.0/0"
```

## Multiple Components

```yaml
components:
  api:
    enabled: true
    primaryComponent: true
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    containers:
      - name: api
        image:
          repository: myorg/api
        ports:
          - name: http
            containerPort: 8080
    service:
      port: 80
    ingress:
      className: nginx
      subdomain: "api"         # Host: api.{env}.{domain}
      internal:
        enabled: true
      external:
        enabled: true

  frontend:
    enabled: true
    generate:
      deployment: true
      service: true
      hpa: true
      pdb: true
      serviceaccount: true
      ingress: true
    containers:
      - name: frontend
        image:
          repository: myorg/frontend
        ports:
          - name: http
            containerPort: 3000
    service:
      port: 80
    ingress:
      className: nginx
      subdomain: "app"         # Host: app.{env}.{domain}
      internal:
        enabled: true
      external:
        enabled: true

  worker:
    enabled: true
    generate:
      deployment: true
      service: false           # Workers don't need a service
      hpa: true
      pdb: false               # No PDB for workers
      serviceaccount: true
      ingress: false           # Workers don't need ingress
    containers:
      - name: worker
        image:
          repository: myorg/worker

  scheduler:
    enabled: true
    replicaCount: 1
    generate:
      deployment: true
      service: false           # Schedulers don't need a service
      hpa: false               # Single replica, no autoscaling
      pdb: false               # Single replica, no PDB
      serviceaccount: true
      ingress: false           # Schedulers don't need ingress
    containers:
      - name: scheduler
        image:
          repository: myorg/scheduler
```

This configuration creates:
- `api.dev.example.com` - API with internal and external access
- `app.dev.example.com` - Frontend with internal and external access
- Worker and scheduler with no ingress (internal services only)
