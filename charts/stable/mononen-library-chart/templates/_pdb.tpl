{{/*
PodDisruptionBudget template
Renders a complete PDB resource for a component
*/}}
{{- define "common.pdb.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $pdb := $component.pdb | default dict }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $fullname }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if $pdb.minAvailable }}
  minAvailable: {{ $pdb.minAvailable }}
  {{- else if $pdb.maxUnavailable }}
  maxUnavailable: {{ $pdb.maxUnavailable }}
  {{- else }}
  minAvailable: 1
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
{{- end }}

