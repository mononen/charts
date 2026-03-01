{{/*
Job template
Renders a Job resource with optional Helm hooks
*/}}
{{- define "common.job.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $job := .job | default dict }}
{{- $name := $fullname }}
{{- if $job.name }}
{{- $name = printf "%s-%s" .Release.Name $job.name | trunc 63 | trimSuffix "-" }}
{{- end }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $name }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- $labelCtx := dict "Values" .Values "Release" .Release "Chart" .Chart "component" .component "componentName" .componentName "componentLabel" $name }}
    {{- include "common.labels" $labelCtx | nindent 4 }}
  annotations:
    {{- if $job.hook }}
    helm.sh/hook: {{ $job.hook }}
    {{- end }}
    {{- if $job.hookWeight }}
    helm.sh/hook-weight: {{ $job.hookWeight | quote }}
    {{- end }}
    {{- if $job.hookDeletePolicy }}
    helm.sh/hook-delete-policy: {{ $job.hookDeletePolicy }}
    {{- end }}
    {{- if $job.annotations }}
    {{- toYaml $job.annotations | nindent 4 }}
    {{- end }}
spec:
  {{- if $job.ttlSecondsAfterFinished }}
  ttlSecondsAfterFinished: {{ $job.ttlSecondsAfterFinished }}
  {{- end }}
  {{- if $job.backoffLimit }}
  backoffLimit: {{ $job.backoffLimit }}
  {{- end }}
  {{- if $job.activeDeadlineSeconds }}
  activeDeadlineSeconds: {{ $job.activeDeadlineSeconds }}
  {{- end }}
  template:
    metadata:
      {{- if $job.podAnnotations }}
      annotations:
        {{- toYaml $job.podAnnotations | nindent 8 }}
      {{- end }}
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: {{ $name }}
    spec:
      {{- include "common.imagePullSecrets" . | nindent 6 }}
      serviceAccountName: {{ $job.serviceAccountName | default (include "common.serviceAccountName" .) }}
      restartPolicy: {{ $job.restartPolicy | default "Never" }}
      {{- include "common.podSecurityContext" . | nindent 6 }}
      containers:
        - name: {{ $job.containerName | default $componentName }}
          {{- if $job.image }}
          {{- if kindIs "string" $job.image }}
          image: {{ $job.image | quote }}
          {{- else }}
          {{- $containerCtx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "container" (dict "image" $job.image) }}
          image: {{ include "common.image" $containerCtx | quote }}
          {{- end }}
          {{- else }}
          {{- $containers := $component.containers | default list }}
          {{- if $containers }}
          {{- $containerCtx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "container" (index $containers 0) }}
          image: {{ include "common.image" $containerCtx | quote }}
          {{- end }}
          {{- end }}
          imagePullPolicy: {{ $job.imagePullPolicy | default "IfNotPresent" }}
          {{- if $job.command }}
          command:
            {{- toYaml $job.command | nindent 12 }}
          {{- end }}
          {{- if $job.args }}
          args:
            {{- toYaml $job.args | nindent 12 }}
          {{- end }}
          {{- if $job.env }}
          env:
            {{- toYaml $job.env | nindent 12 }}
          {{- end }}
          {{- if $job.envFrom }}
          envFrom:
            {{- toYaml $job.envFrom | nindent 12 }}
          {{- end }}
          {{- if $job.resources }}
          resources:
            {{- toYaml $job.resources | nindent 12 }}
          {{- end }}
          {{- if $job.volumeMounts }}
          volumeMounts:
            {{- toYaml $job.volumeMounts | nindent 12 }}
          {{- end }}
      {{- if $job.volumes }}
      volumes:
        {{- toYaml $job.volumes | nindent 8 }}
      {{- end }}
      {{- if $job.nodeSelector }}
      nodeSelector:
        {{- toYaml $job.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if $job.tolerations }}
      tolerations:
        {{- toYaml $job.tolerations | nindent 8 }}
      {{- end }}
      {{- if $job.affinity }}
      affinity:
        {{- toYaml $job.affinity | nindent 8 }}
      {{- end }}
{{- end }}

{{/*
Jobs template for component - generates jobs defined in component.jobs
*/}}
{{- define "common.jobs.tpl" -}}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $jobs := $component.jobs | default list }}
{{- range $job := $jobs }}
{{- if $job.enabled }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $componentName "job" $job }}
{{ include "common.job.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}

