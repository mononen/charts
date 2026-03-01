{{/*
Secret template
Renders a Secret resource
Can be called directly with custom data or via common.all for component secrets
*/}}
{{- define "common.secret.tpl" -}}
{{- $name := .name }}
{{- $namespace := .namespace | default (include "common.namespace" .) }}
{{- $labels := .labels | default dict }}
{{- $data := .data | default dict }}
{{- $stringData := .stringData | default dict }}
{{- $type := .type | default "Opaque" }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $name }}
  namespace: {{ $namespace }}
  {{- if $labels }}
  labels:
    {{- toYaml $labels | nindent 4 }}
  {{- end }}
  {{- if .annotations }}
  annotations:
    {{- toYaml .annotations | nindent 4 }}
  {{- end }}
type: {{ $type }}
{{- if $data }}
data:
  {{- toYaml $data | nindent 2 }}
{{- end }}
{{- if $stringData }}
stringData:
  {{- toYaml $stringData | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Secret template for component - generates secrets defined in component.secrets
*/}}
{{- define "common.secrets.tpl" -}}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $secrets := $component.secrets | default list }}
{{- range $secret := $secrets }}
---
apiVersion: v1
kind: Secret
metadata:
  name: {{ $secret.name | default (printf "%s-%s" $fullname $secret.suffix) }}
  namespace: {{ include "common.namespace" $ }}
  labels:
    {{- include "common.labels" $ | nindent 4 }}
  {{- if $secret.annotations }}
  annotations:
    {{- toYaml $secret.annotations | nindent 4 }}
  {{- end }}
type: {{ $secret.type | default "Opaque" }}
{{- if $secret.data }}
data:
{{- toYaml $secret.data | nindent 2 }}
{{- end }}
{{- if $secret.stringData }}
stringData:
{{- toYaml $secret.stringData | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

