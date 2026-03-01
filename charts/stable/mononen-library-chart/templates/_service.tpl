{{/*
Service template
Renders a complete Service resource for a component
*/}}
{{- define "common.service.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $service := $component.service | default dict }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $fullname }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{- if $service.annotations }}
  annotations:
    {{- toYaml $service.annotations | nindent 4 }}
  {{- end }}
spec:
  type: {{ $service.type | default "ClusterIP" }}
  ports:
    - port: {{ $service.port | default 80 }}
      targetPort: {{ $service.targetPort | default "http" }}
      protocol: TCP
      name: http
    {{- if $service.additionalPorts }}
    {{- range $port := $service.additionalPorts }}
    - port: {{ $port.port }}
      targetPort: {{ $port.targetPort | default $port.port }}
      protocol: {{ $port.protocol | default "TCP" }}
      name: {{ $port.name }}
    {{- end }}
    {{- end }}
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
{{- end }}

