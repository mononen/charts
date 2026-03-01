{{/*
ServiceAccount template
Renders a complete ServiceAccount resource for a component
*/}}
{{- define "common.serviceaccount.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $serviceAccount := $component.serviceAccount | default dict }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "common.serviceAccountName" . }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{- if $serviceAccount.annotations }}
  annotations:
    {{- toYaml $serviceAccount.annotations | nindent 4 }}
  {{- end }}
{{- end }}

