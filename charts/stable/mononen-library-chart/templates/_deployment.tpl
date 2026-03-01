{{/*
Deployment template
Renders a complete Deployment resource for a component
*/}}
{{- define "common.deployment.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $fullname }}
  namespace: {{ include "common.namespace" . }}
  annotations:
    # Doppler operator reload annotation - automatically reload deployment when secrets change
    secrets.doppler.com/reload: "true"
    {{- if $component.annotations }}
    {{- toYaml $component.annotations | nindent 4 }}
    {{- end }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- $generate := $component.generate | default dict }}
  {{- if not (eq (index $generate "hpa") true) }}
  replicas: {{ $component.replicaCount | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- if $component.podAnnotations }}
      annotations:
        {{- toYaml $component.podAnnotations | nindent 8 }}
      {{- end }}
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: {{ $componentName }}
        {{- if $component.podLabels }}
        {{- toYaml $component.podLabels | nindent 8 }}
        {{- end }}
    spec:
      {{- include "common.imagePullSecrets" . | nindent 6 }}
      serviceAccountName: {{ include "common.serviceAccountName" . }}
      {{- include "common.podSecurityContext" . | nindent 6 }}
      {{- include "common.initContainers" . | nindent 6 }}
      containers:
        {{- $containers := $component.containers | default list }}
        {{- range $container := $containers }}
        {{- $containerCtx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $componentName "container" $container }}
        - name: {{ $container.name }}
          image: {{ include "common.image" $containerCtx | quote }}
          imagePullPolicy: {{ include "common.imagePullPolicy" $containerCtx }}
          {{- if $container.command }}
          command:
            {{- toYaml $container.command | nindent 12 }}
          {{- end }}
          {{- if $container.args }}
          args:
            {{- toYaml $container.args | nindent 12 }}
          {{- end }}
          {{- if $container.ports }}
          ports:
            {{- toYaml $container.ports | nindent 12 }}
          {{- end }}
          {{- if $container.lifecycle }}
          lifecycle:
            {{- toYaml $container.lifecycle | nindent 12 }}
          {{- end }}
          {{- if $container.resources }}
          resources:
            {{- toYaml $container.resources | nindent 12 }}
          {{- end }}
          {{- $secCtx := include "common.containerSecurityContext" $containerCtx }}
          {{- if $secCtx }}
          {{- $secCtx | nindent 10 }}
          {{- end }}
          {{- if $container.livenessProbe }}
          livenessProbe:
            {{- toYaml $container.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if $container.readinessProbe }}
          readinessProbe:
            {{- toYaml $container.readinessProbe | nindent 12 }}
          {{- end }}
          {{- if $container.startupProbe }}
          startupProbe:
            {{- toYaml $container.startupProbe | nindent 12 }}
          {{- end }}
          {{- if or $container.envFrom $component.envFrom }}
          envFrom:
            {{- if $container.envFrom }}
            {{- toYaml $container.envFrom | nindent 12 }}
            {{- end }}
            {{- if $component.envFrom }}
            {{- toYaml $component.envFrom | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- if $container.env }}
          env:
            {{- toYaml $container.env | nindent 12 }}
          {{- end }}
          {{- if $container.volumeMounts }}
          volumeMounts:
            {{- toYaml $container.volumeMounts | nindent 12 }}
          {{- end }}
        {{- end }}
        {{- /* Render sidecars */}}
        {{- include "common.sidecars" . | nindent 8 }}
      {{- include "common.volumes" . | nindent 6 }}
      {{- if $component.nodeSelector }}
      nodeSelector:
        {{- toYaml $component.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if $component.affinity }}
      affinity:
        {{- toYaml $component.affinity | nindent 8 }}
      {{- end }}
      {{- if $component.tolerations }}
      tolerations:
        {{- toYaml $component.tolerations | nindent 8 }}
      {{- end }}
      {{- if $component.terminationGracePeriodSeconds }}
      terminationGracePeriodSeconds: {{ $component.terminationGracePeriodSeconds }}
      {{- end }}
{{- end }}

