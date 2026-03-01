{{/*
HorizontalPodAutoscaler template
Renders a complete HPA resource for a component
*/}}
{{- define "common.hpa.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $autoscaling := $component.autoscaling | default dict }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $fullname }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ $fullname }}
  minReplicas: {{ $autoscaling.minReplicas | default 1 }}
  maxReplicas: {{ $autoscaling.maxReplicas | default 10 }}
  metrics:
    {{- if $autoscaling.metrics }}
    {{- toYaml $autoscaling.metrics | nindent 4 }}
    {{- else }}
    {{- if $autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
    {{- end }}
  {{- if $autoscaling.behavior }}
  behavior:
    {{- toYaml $autoscaling.behavior | nindent 4 }}
  {{- end }}
{{- end }}

