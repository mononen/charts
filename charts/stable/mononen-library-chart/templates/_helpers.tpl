{{/*
Expand the name of the chart.
*/}}
{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name for a component.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
Supports:
  - primaryComponent: true - use Release.Name only (no component suffix)
  - fullnameOverride: "custom-name" - use a specific name
*/}}
{{- define "common.fullname" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component | default dict }}
{{- $componentName := .componentName | default "" }}
{{- /* Check for primary component flag - use Release.Name only */ -}}
{{- if $component.primaryComponent }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- /* Check for component fullnameOverride */ -}}
{{- else if $component.fullnameOverride }}
{{- $component.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if $componentName }}
{{- printf "%s-%s" .Release.Name $componentName | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get namespace - uses global.namespace if set, otherwise global.clientCode, otherwise Release.Namespace
*/}}
{{- define "common.namespace" -}}
{{- $global := .Values.global | default dict }}
{{- $namespace := $global.namespace | default $global.clientCode | default .Release.Namespace }}
{{- $namespace }}
{{- end }}

{{/*
Common labels
Supports .componentLabel to override the app.kubernetes.io/component value (used by jobs to set the job name)
*/}}
{{- define "common.labels" -}}
helm.sh/chart: {{ include "common.chart" . }}
{{ include "common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- $componentLabel := .componentLabel | default .componentName | default "" }}
{{- if $componentLabel }}
app.kubernetes.io/component: {{ $componentLabel }}
{{- end }}
{{- end }}

{{/*
Selector labels
Uses fullname for app.kubernetes.io/name to ensure selectors match when fullnameOverride is used
*/}}
{{- define "common.selectorLabels" -}}
{{- $component := .component | default dict }}
{{- $componentName := .componentName | default "" }}
app.kubernetes.io/name: {{ include "common.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get image reference for a container
Uses container.image settings with fallback to global.imageDefaults
*/}}
{{- define "common.image" -}}
{{- $global := .Values.global | default dict }}
{{- $imageDefaults := $global.imageDefaults | default dict }}
{{- $container := .container }}
{{- $image := $container.image | default dict }}
{{- $registry := $image.registry | default $imageDefaults.registry | default "" }}
{{- $repository := $image.repository | default "" }}
{{- $tag := $image.tag | default $imageDefaults.tag | default .Chart.AppVersion | default "latest" }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}

{{/*
Get image pull policy
*/}}
{{- define "common.imagePullPolicy" -}}
{{- $global := .Values.global | default dict }}
{{- $imageDefaults := $global.imageDefaults | default dict }}
{{- $container := .container }}
{{- $image := $container.image | default dict }}
{{- $pullPolicy := $image.pullPolicy | default $imageDefaults.pullPolicy | default "IfNotPresent" }}
{{- $pullPolicy }}
{{- end }}

{{/*
Get image pull secrets
*/}}
{{- define "common.imagePullSecrets" -}}
{{- $global := .Values.global | default dict }}
{{- $imageDefaults := $global.imageDefaults | default dict }}
{{- $component := .component | default dict }}
{{- $pullSecrets := $component.imagePullSecrets | default $imageDefaults.pullSecrets | default list }}
{{- if $pullSecrets }}
imagePullSecrets:
{{- toYaml $pullSecrets | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
Uses generate.serviceaccount to determine if a custom SA is being created
*/}}
{{- define "common.serviceAccountName" -}}
{{- $component := .component | default dict }}
{{- $serviceAccount := $component.serviceAccount | default dict }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "serviceaccount") true }}
{{- default (include "common.fullname" .) $serviceAccount.name }}
{{- else }}
{{- default "default" $serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate the FQDN for ingress based on environment
*/}}
{{- define "common.ingressFqdn" -}}
{{- $global := .Values.global | default dict }}
{{- $env := $global.env | default "dev" }}
{{- $domain := $global.domain | default "" }}
{{- $domainOverride := $global.domainOverride | default "" }}
{{- if $domainOverride }}
{{- $domainOverride }}
{{- else if eq $env "prd" }}
{{- $domain }}
{{- else }}
{{- printf "%s.%s" $env $domain }}
{{- end }}
{{- end }}

{{/*
Determine if a resource should be generated
Checks both global.resources and component.generate settings
*/}}
{{- define "common.shouldGenerate" -}}
{{- $global := .Values.global | default dict }}
{{- $resourceConfig := $global.resources | default dict }}
{{- $component := .component | default dict }}
{{- $componentGenerate := $component.generate | default dict }}
{{- $resourceType := .resourceType }}
{{- $globalEnabled := true }}
{{- $componentEnabled := true }}
{{- if hasKey $resourceConfig $resourceType }}
{{- $globalEnabled = index $resourceConfig $resourceType }}
{{- end }}
{{- if hasKey $componentGenerate $resourceType }}
{{- $componentEnabled = index $componentGenerate $resourceType }}
{{- end }}
{{- and $globalEnabled $componentEnabled }}
{{- end }}

{{/*
Merge annotations - combines component annotations with any additional annotations
*/}}
{{- define "common.annotations" -}}
{{- $annotations := .annotations | default dict }}
{{- if $annotations }}
{{- toYaml $annotations }}
{{- end }}
{{- end }}


{{/*
Extract healthcheck path from container probes
Tries readinessProbe first, then livenessProbe, looks for httpGet.path
Returns empty string if no suitable probe found

Usage: {{ include "common.healthcheckPathFromProbe" (dict "component" $component) }}
*/}}
{{- define "common.healthcheckPathFromProbe" -}}
{{- $component := .component | default dict }}
{{- $containers := $component.containers | default list }}
{{- if $containers }}
{{- $firstContainer := index $containers 0 }}
{{- /* Try readinessProbe first (preferred for healthchecks) */ -}}
{{- if and $firstContainer.readinessProbe $firstContainer.readinessProbe.httpGet $firstContainer.readinessProbe.httpGet.path }}
{{- $firstContainer.readinessProbe.httpGet.path }}
{{- /* Fall back to livenessProbe */ -}}
{{- else if and $firstContainer.livenessProbe $firstContainer.livenessProbe.httpGet $firstContainer.livenessProbe.httpGet.path }}
{{- $firstContainer.livenessProbe.httpGet.path }}
{{- end }}
{{- end }}
{{- end }}

{{/*
===========================================
  ALB INGRESS ANNOTATION HELPERS
===========================================
Auto-generates ALB settings from prefix + env, with per-ingress override support.
Pattern: {prefix}-{env}-internal / {prefix}-{env}-external
*/}}

{{/*
Internal ALB Ingress annotations
Usage: {{ include "common.ingress.alb.internal" (dict "global" $global "config" $internal "certificateARN" $certARN "component" $component) }}

Auto-generates from global.alb.prefix (defaults to global.clientCode):
  - loadBalancerName: {prefix}-{env}-internal
  - groupName: {prefix}-{env}-internal
  - securityGroups: govcloud-{env}-alb-internal, {prefix}-{env}-alb-internal

Per-ingress overrides (optional):
  - config.loadBalancerName, config.groupName, config.securityGroups, config.groupOrder
  - config.healthcheckPath (optional - custom healthcheck path)

Healthcheck path priority:
  1. config.healthcheckPath (manual override)
  2. Extracted from container readinessProbe/livenessProbe httpGet.path
  3. Not set (ALB uses default traffic path)
*/}}
{{- define "common.ingress.alb.internal" -}}
{{- $global := .global }}
{{- $config := .config | default dict }}
{{- $component := .component | default dict }}
{{- $prefix := ($global.alb).prefix | default $global.clientCode }}
{{- $env := $global.env }}
{{- $groupOrder := $config.groupOrder | default "100" }}
{{- $certARN := .certificateARN }}
{{- /* Generate defaults, allow override */}}
{{- $lbName := $config.loadBalancerName | default (printf "%s-%s-internal" $prefix $env) }}
{{- $grpName := $config.groupName | default (printf "%s-%s-internal" $prefix $env) }}
{{- $secGroups := $config.securityGroups | default (printf "govcloud-%s-alb-internal, %s-%s-alb-internal" $env $prefix $env) }}
{{- /* Healthcheck path: manual override > probe path > not set */ -}}
{{- $healthcheckPath := $config.healthcheckPath }}
{{- if not $healthcheckPath }}
{{- $healthcheckPath = include "common.healthcheckPathFromProbe" (dict "component" $component) }}
{{- end }}
alb.ingress.kubernetes.io/load-balancer-name: {{ $lbName | quote }}
alb.ingress.kubernetes.io/group.name: {{ $grpName | quote }}
alb.ingress.kubernetes.io/group.order: "{{ $groupOrder }}"
alb.ingress.kubernetes.io/scheme: internal
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/certificate-arn: {{ $certARN }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
alb.ingress.kubernetes.io/security-groups: {{ $secGroups | quote }}
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=300,load_balancing.algorithm.type=least_outstanding_requests
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
{{- if $healthcheckPath }}
alb.ingress.kubernetes.io/healthcheck-path: {{ $healthcheckPath | quote }}
{{- end }}
{{- end }}

{{/*
External ALB Ingress annotations
Usage: {{ include "common.ingress.alb.external" (dict "global" $global "config" $external "certificateARN" $certARN "component" $component) }}

Auto-generates from global.alb.prefix (defaults to global.clientCode):
  - loadBalancerName: {prefix}-{env}-external
  - groupName: {prefix}-{env}-external
  - securityGroups: govcloud-{env}-alb-external, {prefix}-{env}-alb-external

Per-ingress overrides (optional):
  - config.loadBalancerName, config.groupName, config.securityGroups, config.groupOrder
  - config.healthcheckPath (optional - custom healthcheck path)

Healthcheck path priority:
  1. config.healthcheckPath (manual override)
  2. Extracted from container readinessProbe/livenessProbe httpGet.path
  3. Not set (ALB uses default traffic path)
*/}}
{{- define "common.ingress.alb.external" -}}
{{- $global := .global }}
{{- $config := .config | default dict }}
{{- $component := .component | default dict }}
{{- $prefix := ($global.alb).prefix | default $global.clientCode }}
{{- $env := $global.env }}
{{- $groupOrder := $config.groupOrder | default "100" }}
{{- $certARN := .certificateARN }}
{{- /* Generate defaults, allow override */}}
{{- $lbName := $config.loadBalancerName | default (printf "%s-%s-external" $prefix $env) }}
{{- $grpName := $config.groupName | default (printf "%s-%s-external" $prefix $env) }}
{{- $secGroups := $config.securityGroups | default (printf "govcloud-%s-alb-external, %s-%s-alb-external" $env $prefix $env) }}
{{- /* Healthcheck path: manual override > probe path > not set */ -}}
{{- $healthcheckPath := $config.healthcheckPath }}
{{- if not $healthcheckPath }}
{{- $healthcheckPath = include "common.healthcheckPathFromProbe" (dict "component" $component) }}
{{- end }}
alb.ingress.kubernetes.io/load-balancer-name: {{ $lbName | quote }}
alb.ingress.kubernetes.io/group.name: {{ $grpName | quote }}
alb.ingress.kubernetes.io/group.order: "{{ $groupOrder }}"
alb.ingress.kubernetes.io/scheme: internet-facing
alb.ingress.kubernetes.io/target-type: ip
alb.ingress.kubernetes.io/certificate-arn: {{ $certARN }}
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
alb.ingress.kubernetes.io/security-groups: {{ $secGroups | quote }}
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=300,load_balancing.algorithm.type=least_outstanding_requests
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
{{- if $healthcheckPath }}
alb.ingress.kubernetes.io/healthcheck-path: {{ $healthcheckPath | quote }}
{{- end }}
{{- end }}
