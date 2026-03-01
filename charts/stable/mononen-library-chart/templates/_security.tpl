{{/*
Get pod security context
Checks component.security.enabled, then global.security.enabled
Returns podSecurityContext from component or global
*/}}
{{- define "common.podSecurityContext" -}}
{{- $global := .Values.global | default dict }}
{{- $globalSecurity := $global.security | default dict }}
{{- $component := .component | default dict }}
{{- $componentSecurity := $component.security | default dict }}
{{- $securityEnabled := true }}
{{/* Check if security is explicitly disabled at component level */}}
{{- if hasKey $componentSecurity "enabled" }}
{{- if not $componentSecurity.enabled }}
{{- $securityEnabled = false }}
{{- end }}
{{- else if hasKey $globalSecurity "enabled" }}
{{- if not $globalSecurity.enabled }}
{{- $securityEnabled = false }}
{{- end }}
{{- end }}
{{- if $securityEnabled }}
{{- $podSecurityContext := $componentSecurity.podSecurityContext | default $globalSecurity.podSecurityContext | default dict }}
{{- if $podSecurityContext }}
securityContext:
{{- toYaml $podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Get container security context
Checks component.security.enabled, then global.security.enabled
Returns containerSecurityContext from component or global
*/}}
{{- define "common.containerSecurityContext" -}}
{{- $global := .Values.global | default dict }}
{{- $globalSecurity := $global.security | default dict }}
{{- $component := .component | default dict }}
{{- $componentSecurity := $component.security | default dict }}
{{- $container := .container | default dict }}
{{- $securityEnabled := true }}
{{/* Check if security is explicitly disabled at component level */}}
{{- if hasKey $componentSecurity "enabled" }}
{{- if not $componentSecurity.enabled }}
{{- $securityEnabled = false }}
{{- end }}
{{- else if hasKey $globalSecurity "enabled" }}
{{- if not $globalSecurity.enabled }}
{{- $securityEnabled = false }}
{{- end }}
{{- end }}
{{- if $securityEnabled }}
{{/* Priority: container.securityContext > component.containerSecurityContext > global.containerSecurityContext */}}
{{- $containerSecurityContext := $container.securityContext | default $componentSecurity.containerSecurityContext | default $globalSecurity.containerSecurityContext | default dict }}
{{- if $containerSecurityContext }}
securityContext:
{{- toYaml $containerSecurityContext | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if security is enabled for a component
*/}}
{{- define "common.securityEnabled" -}}
{{- $global := .Values.global | default dict }}
{{- $globalSecurity := $global.security | default dict }}
{{- $component := .component | default dict }}
{{- $componentSecurity := $component.security | default dict }}
{{- $securityEnabled := true }}
{{- if hasKey $componentSecurity "enabled" }}
{{- $securityEnabled = $componentSecurity.enabled }}
{{- else if hasKey $globalSecurity "enabled" }}
{{- $securityEnabled = $globalSecurity.enabled }}
{{- end }}
{{- $securityEnabled }}
{{- end }}

