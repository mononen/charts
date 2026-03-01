{{/*
ServiceMonitor template
Renders a Prometheus ServiceMonitor resource for a component
*/}}
{{- define "common.servicemonitor.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $serviceMonitor := $component.serviceMonitor | default dict }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ $fullname }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
    {{- if $serviceMonitor.labels }}
    {{- toYaml $serviceMonitor.labels | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  namespaceSelector:
    matchNames:
      - {{ include "common.namespace" . }}
  endpoints:
    {{- if $serviceMonitor.endpoints }}
    {{- toYaml $serviceMonitor.endpoints | nindent 4 }}
    {{- else }}
    - port: {{ $serviceMonitor.port | default "http" }}
      interval: {{ $serviceMonitor.interval | default "30s" }}
      scrapeTimeout: {{ $serviceMonitor.scrapeTimeout | default "10s" }}
      {{- if $serviceMonitor.path }}
      path: {{ $serviceMonitor.path }}
      {{- end }}
      {{- if $serviceMonitor.scheme }}
      scheme: {{ $serviceMonitor.scheme }}
      {{- end }}
      {{- if $serviceMonitor.tlsConfig }}
      tlsConfig:
        {{- toYaml $serviceMonitor.tlsConfig | nindent 8 }}
      {{- end }}
      {{- if $serviceMonitor.metricRelabelings }}
      metricRelabelings:
        {{- toYaml $serviceMonitor.metricRelabelings | nindent 8 }}
      {{- end }}
      {{- if $serviceMonitor.relabelings }}
      relabelings:
        {{- toYaml $serviceMonitor.relabelings | nindent 8 }}
      {{- end }}
    {{- end }}
{{- end }}

