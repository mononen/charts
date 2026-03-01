{{/*
ALB Ingress template
Renders internal and/or external ALB Ingress resources for a component
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
{{/* Internal Ingress - enabled by default unless explicitly disabled */}}
{{- if ne ($ingress.internal | default dict).enabled false }}
{{- $internal := $ingress.internal | default dict }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullname }}-internal
  namespace: {{ include "common.namespace" . }}
  annotations:
    {{- include "common.ingress.alb.internal" (dict "global" $global "config" $internal "certificateARN" ($ingress.certificateARN | default $global.certificateARN) "component" $component) | nindent 4 }}
    {{- if $internal.annotations }}
    {{- toYaml $internal.annotations | nindent 4 }}
    {{- end }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  ingressClassName: alb
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
{{- end -}}
{{/* External Ingress - disabled by default unless explicitly enabled */}}
{{- if ($ingress.external | default dict).enabled }}
{{- $external := $ingress.external | default dict }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullname }}-external
  namespace: {{ include "common.namespace" . }}
  annotations:
    {{- include "common.ingress.alb.external" (dict "global" $global "config" $external "certificateARN" ($ingress.certificateARN | default $global.certificateARN) "component" $component) | nindent 4 }}
    {{- if $external.annotations }}
    {{- toYaml $external.annotations | nindent 4 }}
    {{- end }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  ingressClassName: alb
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
{{- end -}}
{{- end -}}
