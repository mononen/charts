{{/*
CronJob template
Renders a CronJob resource for a component
*/}}
{{- define "common.cronjob.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $cronJob := .cronJob | default dict }}
{{- $name := $cronJob.name | default $fullname }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ $name }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{- if $cronJob.annotations }}
  annotations:
    {{- toYaml $cronJob.annotations | nindent 4 }}
  {{- end }}
spec:
  schedule: {{ $cronJob.schedule | quote }}
  concurrencyPolicy: {{ $cronJob.concurrencyPolicy | default "Forbid" }}
  successfulJobsHistoryLimit: {{ $cronJob.successfulJobsHistoryLimit | default 3 }}
  failedJobsHistoryLimit: {{ $cronJob.failedJobsHistoryLimit | default 1 }}
  {{- if $cronJob.suspend }}
  suspend: {{ $cronJob.suspend }}
  {{- end }}
  jobTemplate:
    spec:
      {{- if $cronJob.ttlSecondsAfterFinished }}
      ttlSecondsAfterFinished: {{ $cronJob.ttlSecondsAfterFinished }}
      {{- end }}
      {{- if $cronJob.backoffLimit }}
      backoffLimit: {{ $cronJob.backoffLimit }}
      {{- end }}
      template:
        metadata:
          {{- if $cronJob.podAnnotations }}
          annotations:
            {{- toYaml $cronJob.podAnnotations | nindent 12 }}
          {{- end }}
          labels:
            {{- include "common.selectorLabels" . | nindent 12 }}
            app.kubernetes.io/component: {{ $componentName }}
        spec:
          {{- include "common.imagePullSecrets" . | nindent 10 }}
          serviceAccountName: {{ $cronJob.serviceAccountName | default (include "common.serviceAccountName" .) }}
          restartPolicy: {{ $cronJob.restartPolicy | default "OnFailure" }}
          {{- include "common.podSecurityContext" . | nindent 10 }}
          containers:
            - name: {{ $cronJob.containerName | default $componentName }}
              {{- if $cronJob.image }}
              {{- if kindIs "string" $cronJob.image }}
              image: {{ $cronJob.image | quote }}
              {{- else }}
              {{- $containerCtx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "container" (dict "image" $cronJob.image) }}
              image: {{ include "common.image" $containerCtx | quote }}
              {{- end }}
              {{- else }}
              {{- $containers := $component.containers | default list }}
              {{- if $containers }}
              {{- $containerCtx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "container" (index $containers 0) }}
              image: {{ include "common.image" $containerCtx | quote }}
              {{- end }}
              {{- end }}
              imagePullPolicy: {{ $cronJob.imagePullPolicy | default "IfNotPresent" }}
              {{- if $cronJob.command }}
              command:
                {{- toYaml $cronJob.command | nindent 16 }}
              {{- end }}
              {{- if $cronJob.args }}
              args:
                {{- toYaml $cronJob.args | nindent 16 }}
              {{- end }}
              {{- if $cronJob.env }}
              env:
                {{- toYaml $cronJob.env | nindent 16 }}
              {{- end }}
              {{- if $cronJob.envFrom }}
              envFrom:
                {{- toYaml $cronJob.envFrom | nindent 16 }}
              {{- end }}
              {{- if $cronJob.resources }}
              resources:
                {{- toYaml $cronJob.resources | nindent 16 }}
              {{- end }}
              {{- if $cronJob.volumeMounts }}
              volumeMounts:
                {{- toYaml $cronJob.volumeMounts | nindent 16 }}
              {{- end }}
          {{- if $cronJob.volumes }}
          volumes:
            {{- toYaml $cronJob.volumes | nindent 12 }}
          {{- end }}
          {{- if $cronJob.nodeSelector }}
          nodeSelector:
            {{- toYaml $cronJob.nodeSelector | nindent 12 }}
          {{- end }}
          {{- if $cronJob.tolerations }}
          tolerations:
            {{- toYaml $cronJob.tolerations | nindent 12 }}
          {{- end }}
          {{- if $cronJob.affinity }}
          affinity:
            {{- toYaml $cronJob.affinity | nindent 12 }}
          {{- end }}
{{- end }}

{{/*
CronJobs template for component - generates cronjobs defined in component.cronJobs
*/}}
{{- define "common.cronjobs.tpl" -}}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $cronJobs := $component.cronJobs | default list }}
{{- range $cronJob := $cronJobs }}
{{- if $cronJob.enabled }}
{{- $ctx := dict "Values" $.Values "Release" $.Release "Chart" $.Chart "component" $component "componentName" $componentName "cronJob" $cronJob }}
{{ include "common.cronjob.tpl" $ctx }}
---
{{- end }}
{{- end }}
{{- end }}

