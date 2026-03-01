{{/*
Restart CronJob bundle
Includes ServiceAccount, Role, RoleBinding, and CronJob for restarting deployments
*/}}
{{- define "common.restart.tpl" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $restartCronJob := $component.restartCronJob | default dict }}
{{- $saName := printf "%s-restart" $fullname }}
---
# ServiceAccount for restart cronjob
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $saName }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
---
# Role with permissions to restart deployments
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $saName }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
rules:
  - apiGroups: ["apps", "extensions"]
    resources: ["deployments"]
    resourceNames: ["{{ $fullname }}"]
    verbs: ["get", "patch"]
---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $saName }}
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ $saName }}
subjects:
  - kind: ServiceAccount
    name: {{ $saName }}
    namespace: {{ include "common.namespace" . }}
---
# CronJob to restart the deployment
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ $fullname }}-restart
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  concurrencyPolicy: {{ $restartCronJob.concurrencyPolicy | default "Forbid" }}
  schedule: {{ $restartCronJob.schedule | default "0 9 * * *" | quote }}
  successfulJobsHistoryLimit: {{ $restartCronJob.successfulJobsHistoryLimit | default 1 }}
  failedJobsHistoryLimit: {{ $restartCronJob.failedJobsHistoryLimit | default 1 }}
  jobTemplate:
    spec:
      backoffLimit: {{ $restartCronJob.backoffLimit | default 2 }}
      activeDeadlineSeconds: {{ $restartCronJob.activeDeadlineSeconds | default 600 }}
      template:
        metadata:
          labels:
            {{- include "common.selectorLabels" . | nindent 12 }}
            app.kubernetes.io/component: {{ $componentName }}
        spec:
          serviceAccountName: {{ $saName | quote }}
          restartPolicy: Never
          containers:
            - name: kubectl
              image: {{ $restartCronJob.image | default "public.ecr.aws/bitnami/kubectl:1.22.9" }}
              command:
                - "kubectl"
                - "rollout"
                - "restart"
                - "deployment/{{ $fullname }}"
{{- end }}

