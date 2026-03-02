{{/*
Ingress template
Renders internal and/or external Ingress resources for a component
*/}}
{{- define "common.ingress.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $ingress := $component.ingress | default dict }}
{{- $service := $component.service | default dict }}
{{- $fqdn := include "common.ingressFqdn" . }}
{{- $subdomain := $ingress.subdomain | default $componentName }}
{{- $host := printf "%s.%s" $subdomain $fqdn }}
{{- $sharedClassName := $ingress.className | default "" }}
{{- $sharedAnnotations := $ingress.annotations | default dict }}
{{/* Internal Ingress - enabled by default unless explicitly disabled */}}
{{- if ne ($ingress.internal | default dict).enabled false }}
{{- $internal := $ingress.internal | default dict }}
{{- $className := $internal.className | default $sharedClassName }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullname }}-internal
  namespace: {{ include "common.namespace" . }}
  {{- $mergedAnnotations := merge ($internal.annotations | default dict) $sharedAnnotations }}
  {{- if $mergedAnnotations }}
  annotations:
    {{- toYaml $mergedAnnotations | nindent 4 }}
  {{- end }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if $className }}
  ingressClassName: {{ $className }}
  {{- end }}
  rules:
    - host: {{ $host | quote }}
      http:
        paths:
          {{- if $internal.paths }}
          {{- range $path := $internal.paths }}
          - path: {{ $path.path | default "/" }}
            pathType: {{ $path.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $path.serviceName | default $fullname }}
                port:
                  {{- if $path.portName }}
                  name: {{ $path.portName }}
                  {{- else }}
                  number: {{ $path.servicePort | default ($service.port | default 80) }}
                  {{- end }}
          {{- end }}
          {{- else }}
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ $fullname }}
                port:
                  number: {{ $service.port | default 80 }}
          {{- end }}
  {{- if $internal.tls }}
  tls:
    {{- toYaml $internal.tls | nindent 4 }}
  {{- end }}
{{- end -}}
{{/* External Ingress - disabled by default unless explicitly enabled */}}
{{- if ($ingress.external | default dict).enabled }}
{{- $external := $ingress.external | default dict }}
{{- $className := $external.className | default $sharedClassName }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullname }}-external
  namespace: {{ include "common.namespace" . }}
  {{- $mergedAnnotations := merge ($external.annotations | default dict) $sharedAnnotations }}
  {{- if $mergedAnnotations }}
  annotations:
    {{- toYaml $mergedAnnotations | nindent 4 }}
  {{- end }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if $className }}
  ingressClassName: {{ $className }}
  {{- end }}
  rules:
    - host: {{ $host | quote }}
      http:
        paths:
          {{- if $external.paths }}
          {{- range $path := $external.paths }}
          - path: {{ $path.path | default "/" }}
            pathType: {{ $path.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $path.serviceName | default $fullname }}
                port:
                  {{- if $path.portName }}
                  name: {{ $path.portName }}
                  {{- else }}
                  number: {{ $path.servicePort | default ($service.port | default 80) }}
                  {{- end }}
          {{- end }}
          {{- else }}
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ $fullname }}
                port:
                  number: {{ $service.port | default 80 }}
          {{- end }}
  {{- if $external.tls }}
  tls:
    {{- toYaml $external.tls | nindent 4 }}
  {{- end }}
{{- end -}}
{{- end -}}
