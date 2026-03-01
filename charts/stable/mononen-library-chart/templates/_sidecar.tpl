{{/*
Render sidecars for a component
Sidecars are additional containers that run alongside the main containers
Automatically injects logging sidecar when generate.logging=true
*/}}
{{- define "common.sidecars" -}}
{{- $component := .component | default dict }}
{{- $sidecars := $component.sidecars | default list }}
{{- /* Auto-inject logging sidecar if logging is enabled */}}
{{- if include "common.logging.enabled" . }}
{{- include "common.logging.sidecar" . }}
{{- end }}
{{- range $sidecar := $sidecars }}
- name: {{ $sidecar.name }}
  image: {{ $sidecar.image | quote }}
  imagePullPolicy: {{ $sidecar.imagePullPolicy | default "IfNotPresent" }}
  {{- if $sidecar.command }}
  command:
  {{- toYaml $sidecar.command | nindent 4 }}
  {{- end }}
  {{- if $sidecar.args }}
  args:
  {{- toYaml $sidecar.args | nindent 4 }}
  {{- end }}
  {{- if $sidecar.ports }}
  ports:
  {{- toYaml $sidecar.ports | nindent 4 }}
  {{- end }}
  {{- if $sidecar.env }}
  env:
  {{- toYaml $sidecar.env | nindent 4 }}
  {{- end }}
  {{- if $sidecar.envFrom }}
  envFrom:
  {{- toYaml $sidecar.envFrom | nindent 4 }}
  {{- end }}
  {{- if $sidecar.resources }}
  resources:
  {{- toYaml $sidecar.resources | nindent 4 }}
  {{- end }}
  {{- if $sidecar.securityContext }}
  securityContext:
  {{- toYaml $sidecar.securityContext | nindent 4 }}
  {{- end }}
  {{- if $sidecar.volumeMounts }}
  volumeMounts:
  {{- toYaml $sidecar.volumeMounts | nindent 4 }}
  {{- end }}
  {{- if $sidecar.livenessProbe }}
  livenessProbe:
  {{- toYaml $sidecar.livenessProbe | nindent 4 }}
  {{- end }}
  {{- if $sidecar.readinessProbe }}
  readinessProbe:
  {{- toYaml $sidecar.readinessProbe | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Render init containers for a component
*/}}
{{- define "common.initContainers" -}}
{{- $component := .component | default dict }}
{{- $initContainers := $component.initContainers | default list }}
{{- if $initContainers }}
initContainers:
{{- range $initContainer := $initContainers }}
  - name: {{ $initContainer.name }}
    image: {{ $initContainer.image | quote }}
    imagePullPolicy: {{ $initContainer.imagePullPolicy | default "IfNotPresent" }}
    {{- if $initContainer.command }}
    command:
    {{- toYaml $initContainer.command | nindent 6 }}
    {{- end }}
    {{- if $initContainer.args }}
    args:
    {{- toYaml $initContainer.args | nindent 6 }}
    {{- end }}
    {{- if $initContainer.env }}
    env:
    {{- toYaml $initContainer.env | nindent 6 }}
    {{- end }}
    {{- if $initContainer.envFrom }}
    envFrom:
    {{- toYaml $initContainer.envFrom | nindent 6 }}
    {{- end }}
    {{- if $initContainer.resources }}
    resources:
    {{- toYaml $initContainer.resources | nindent 6 }}
    {{- end }}
    {{- if $initContainer.securityContext }}
    securityContext:
    {{- toYaml $initContainer.securityContext | nindent 6 }}
    {{- end }}
    {{- if $initContainer.volumeMounts }}
    volumeMounts:
    {{- toYaml $initContainer.volumeMounts | nindent 6 }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Render volumes for a component
Automatically includes logging volumes when generate.logging=true
*/}}
{{- define "common.volumes" -}}
{{- $component := .component | default dict }}
{{- $volumes := $component.volumes | default list }}
{{- $hasLogging := include "common.logging.enabled" . }}
{{- if or $volumes $hasLogging }}
volumes:
{{- /* Auto-inject logging volumes if logging is enabled */}}
{{- if $hasLogging }}
{{- include "common.logging.volumes" . | nindent 2 }}
{{- end }}
{{- range $volume := $volumes }}
  - name: {{ $volume.name }}
    {{- if $volume.configMap }}
    configMap:
    {{- toYaml $volume.configMap | nindent 6 }}
    {{- else if $volume.secret }}
    secret:
    {{- toYaml $volume.secret | nindent 6 }}
    {{- else if $volume.persistentVolumeClaim }}
    persistentVolumeClaim:
    {{- toYaml $volume.persistentVolumeClaim | nindent 6 }}
    {{- else if $volume.emptyDir }}
    emptyDir:
    {{- toYaml $volume.emptyDir | nindent 6 }}
    {{- else if $volume.hostPath }}
    hostPath:
    {{- toYaml $volume.hostPath | nindent 6 }}
    {{- else if $volume.projected }}
    projected:
    {{- toYaml $volume.projected | nindent 6 }}
    {{- else }}
    emptyDir: {}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

