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


