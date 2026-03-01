{{/*
ConfigMap template
Renders a ConfigMap resource
Can be called directly with custom data or via common.all for component configmaps
*/}}
{{- define "common.configmap.tpl" -}}
{{- $name := .name }}
{{- $namespace := .namespace | default (include "common.namespace" .) }}
{{- $labels := .labels | default dict }}
{{- $data := .data | default dict }}
{{- $binaryData := .binaryData | default dict }}
apiVersion: v1
kind: ConfigMap
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
{{- if $data }}
data:
  {{- range $key, $value := $data }}
  {{ $key }}: |
{{ $value | indent 4 }}
  {{- end }}
{{- end }}
{{- if $binaryData }}
binaryData:
  {{- toYaml $binaryData | nindent 2 }}
{{- end }}
{{- end }}

{{/*
ConfigMap template for component - generates configmaps defined in component.configMaps
*/}}
{{- define "common.configmaps.tpl" -}}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $configMaps := $component.configMaps | default list }}
{{- range $cm := $configMaps }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $cm.name | default (printf "%s-%s" $fullname $cm.suffix) }}
  namespace: {{ include "common.namespace" $ }}
  labels:
    {{- include "common.labels" $ | nindent 4 }}
  {{- if $cm.annotations }}
  annotations:
    {{- toYaml $cm.annotations | nindent 4 }}
  {{- end }}
{{- if $cm.data }}
data:
{{- toYaml $cm.data | nindent 2 }}
{{- end }}
{{- if $cm.binaryData }}
binaryData:
{{- toYaml $cm.binaryData | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

