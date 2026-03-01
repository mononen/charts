{{/*
PVC name for the config volume.
Uses persistence.config.claimName if set, otherwise <release>-config.
*/}}
{{- define "jdownloader.pvc.config" -}}
{{- $persistence := .Values.persistence | default dict -}}
{{- $config := $persistence.config | default dict -}}
{{- default (printf "%s-config" .Release.Name) $config.claimName -}}
{{- end -}}

{{/*
PVC name for the output volume.
Uses persistence.output.claimName if set, otherwise <release>-output.
*/}}
{{- define "jdownloader.pvc.output" -}}
{{- $persistence := .Values.persistence | default dict -}}
{{- $output := $persistence.output | default dict -}}
{{- default (printf "%s-output" .Release.Name) $output.claimName -}}
{{- end -}}
