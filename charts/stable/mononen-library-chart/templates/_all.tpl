{{/*
common.all - Main entry point that iterates over all components and generates resources
This is the only template that consuming charts need to call
Usage: {{ include "common.all" . }}
*/}}
{{- define "common.all" -}}
{{- $global := .Values.global | default dict -}}
{{- $resourceConfig := $global.resources | default dict -}}

{{/* ===== DEPLOYMENTS ===== */}}
{{- if ne (index $resourceConfig "deployments") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if ne (index $generate "deployment") false }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.deployment.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== SERVICES ===== */}}
{{- if ne (index $resourceConfig "services") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "service") true }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.service.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== HORIZONTAL POD AUTOSCALERS ===== */}}
{{- if ne (index $resourceConfig "hpas") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "hpa") true }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.hpa.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== POD DISRUPTION BUDGETS ===== */}}
{{- if ne (index $resourceConfig "pdbs") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "pdb") true }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.pdb.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== SERVICE ACCOUNTS ===== */}}
{{- if ne (index $resourceConfig "serviceaccounts") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "serviceaccount") true }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.serviceaccount.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== INGRESSES ===== */}}
{{- if ne (index $resourceConfig "ingresses") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if ne (index $generate "ingress") false }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.ingress.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== RESTART CRONJOBS (with RBAC) ===== */}}
{{- if ne (index $resourceConfig "restartCronjobs") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "restartCronJob") true }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.restart.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== SERVICE MONITORS ===== */}}
{{- if ne (index $resourceConfig "serviceMonitors") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "serviceMonitor") true }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.servicemonitor.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== LOGGING CONFIGMAPS ===== */}}
{{- if ne (index $resourceConfig "logging") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "logging") true }}
{{- $logging := $component.logging | default dict }}
{{- if not $logging.customConfig }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.logging.alloy-configmap" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== CONFIGMAPS ===== */}}
{{- if ne (index $resourceConfig "configmaps") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $configMaps := $component.configMaps | default list }}
{{- if $configMaps }}
{{- $generate := $component.generate | default dict }}
{{- if ne (index $generate "configmaps") false }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.configmaps.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== SECRETS ===== */}}
{{- if ne (index $resourceConfig "secrets") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $secrets := $component.secrets | default list }}
{{- if $secrets }}
{{- $generate := $component.generate | default dict }}
{{- if ne (index $generate "secrets") false }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.secrets.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== CRONJOBS ===== */}}
{{- if ne (index $resourceConfig "cronjobs") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $cronJobs := $component.cronJobs | default list }}
{{- if $cronJobs }}
{{- $generate := $component.generate | default dict }}
{{- if ne (index $generate "cronjobs") false }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.cronjobs.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* ===== JOBS ===== */}}
{{- if ne (index $resourceConfig "jobs") false }}
{{- range $name, $component := .Values.components }}
{{- if $component.enabled }}
{{- $jobs := $component.jobs | default list }}
{{- if $jobs }}
{{- $generate := $component.generate | default dict }}
{{- if ne (index $generate "jobs") false }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $name }}
{{ include "common.jobs.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}

