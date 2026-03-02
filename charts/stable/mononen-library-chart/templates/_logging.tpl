{{/*
Logging templates for Alloy/Loki integration
Provides ConfigMap generation, sidecar container, and volume definitions
*/}}

{{/*
common.logging.alloy-configmap - Generates the Alloy ConfigMap for log collection
Only generated when generate.logging=true AND component.logging.customConfig is not set
*/}}
{{- define "common.logging.alloy-configmap" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $componentName := .componentName }}
{{- $fullname := include "common.fullname" . }}
{{- $logging := $component.logging | default dict }}
{{- $logTargets := $logging.logTargets | default list }}
{{- $appName := $logging.appName | default $fullname }}
{{- $env := $global.env | default "dev" }}
{{- $lokiEndpoint := ($global.logs).lokiEndpoint | default "" }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $fullname }}-alloy-config
  namespace: {{ include "common.namespace" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
data:
  config.alloy: |
    loki.write "default" {
      endpoint {
        url = "{{ $lokiEndpoint }}/loki/api/v1/push"
        basic_auth {
          username = sys.env("LOKI_USERNAME")
          password = sys.env("LOKI_PASSWORD")
        }
        tenant_id = sys.env("LOKI_USERNAME")
      }
    }
{{- range $target := $logTargets }}
{{- $targetName := $target.name }}
{{- range $job := $target.jobs }}
{{- if $job.autoConfigure }}
{{- $jobId := $job.name | replace "-" "_" }}
    local.file_match "{{ $jobId }}" {
    	path_targets = [{
    		__address__ = "localhost",
    		__path__    = "/var/log/{{ $targetName }}/{{ $job.sidecarLogfile }}",
    		app         = "{{ $appName }}",
    		env         = "{{ $env }}",
    		job         = "{{ $job.name }}",
{{- if $job.level }}
    		level       = "{{ $job.level }}",
{{- end }}
    	}]
    }
{{- if $job.multilinePattern }}
    loki.process "{{ $jobId }}" {
    	forward_to = [loki.write.default.receiver]

    	stage.multiline {
    		firstline = "{{ $job.multilinePattern }}"
    		max_lines = 0
    	}
    }

    loki.source.file "{{ $jobId }}" {
    	targets               = local.file_match.{{ $jobId }}.targets
    	forward_to            = [loki.process.{{ $jobId }}.receiver]
    	legacy_positions_file = "/tmp/positions.yaml"
    }
{{- else if $job.dropPattern }}
    loki.process "{{ $jobId }}" {
    	forward_to = [loki.write.default.receiver]

    	stage.drop {
    		expression = "{{ $job.dropPattern }}"
    	}
    }

    loki.source.file "{{ $jobId }}" {
    	targets               = local.file_match.{{ $jobId }}.targets
    	forward_to            = [loki.process.{{ $jobId }}.receiver]
    	legacy_positions_file = "/tmp/positions.yaml"
    }
{{- else }}
    loki.source.file "{{ $jobId }}" {
    	targets               = local.file_match.{{ $jobId }}.targets
    	forward_to            = [loki.write.default.receiver]
    	legacy_positions_file = "/tmp/positions.yaml"
    }
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
common.logging.sidecar - Generates the logging sidecar container definition
Used internally by the sidecar template when logging is enabled
*/}}
{{- define "common.logging.sidecar" -}}
{{- $global := .Values.global | default dict }}
{{- $component := .component }}
{{- $fullname := include "common.fullname" . }}
{{- $logging := $component.logging | default dict }}
{{- $logTargets := $logging.logTargets | default list }}
{{- $loggingDefaults := ($global.logging) | default dict }}
{{- $imageDefaults := $loggingDefaults.image | default dict }}
{{- $image := $logging.image | default dict }}
{{- $imageRepo := $image.repository | default ($imageDefaults.repository | default "grafana/alloy") }}
{{- $imageTag := $image.tag | default ($imageDefaults.tag | default "v1.9.1") }}
{{- $resources := $logging.resources | default dict }}
- name: logging-sidecar
  image: "{{ $imageRepo }}:{{ $imageTag }}"
  env:
    - name: LOKI_USERNAME
      valueFrom:
        secretKeyRef:
          name: {{ $logging.lokiAuthSecret | default "loki-auth" }}
          key: username
    - name: LOKI_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ $logging.lokiAuthSecret | default "loki-auth" }}
          key: password
  resources:
    {{- if $resources }}
    {{- toYaml $resources | nindent 4 }}
    {{- else }}
    limits:
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
    {{- end }}
  volumeMounts:
    - name: alloy-config
      mountPath: /etc/alloy
    {{- range $target := $logTargets }}
    - name: {{ $target.name }}
      mountPath: /var/log/{{ $target.name }}
    {{- end }}
  {{- if $logging.securityContext }}
  securityContext:
    {{- toYaml $logging.securityContext | nindent 4 }}
  {{- else }}
  securityContext:
    runAsGroup: 473
  {{- end }}
{{- end }}

{{/*
common.logging.volumes - Generates the volumes required for logging
Returns the alloy-config volume. Log target volumes should be defined in component.volumes
if they need special configuration, otherwise they are auto-generated as emptyDir.
*/}}
{{- define "common.logging.volumes" -}}
{{- $component := .component }}
{{- $fullname := include "common.fullname" . }}
{{- $logging := $component.logging | default dict }}
{{- $logTargets := $logging.logTargets | default list }}
{{- $existingVolumes := $component.volumes | default list }}
{{- $existingVolumeNames := list }}
{{- range $vol := $existingVolumes }}
{{- $existingVolumeNames = append $existingVolumeNames $vol.name }}
{{- end }}
- name: alloy-config
  configMap:
    name: {{ $fullname }}-alloy-config
    defaultMode: 420
{{- range $target := $logTargets }}
{{- if not (has $target.name $existingVolumeNames) }}
- name: {{ $target.name }}
  emptyDir: {}
{{- end }}
{{- end }}
{{- end }}

{{/*
common.logging.enabled - Helper to check if logging is enabled for a component
Uses generate.logging to determine if logging is active
*/}}
{{- define "common.logging.enabled" -}}
{{- $component := .component | default dict }}
{{- $generate := $component.generate | default dict }}
{{- if eq (index $generate "logging") true }}true{{- end }}
{{- end }}

{{/*
common.logging.customConfig - Helper to check if custom config is used
*/}}
{{- define "common.logging.customConfig" -}}
{{- $component := .component | default dict }}
{{- $logging := $component.logging | default dict }}
{{- if $logging.customConfig }}true{{- end }}
{{- end }}

{{/*
common.logging.alloy-header - Generates just the Alloy header for custom templates
Use this in custom alloy-configmap.yaml templates:

  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: {{ include "common.fullname" . }}-alloy-config
  data:
    config.alloy: |
      {{- include "common.logging.alloy-header" . | nindent 4 }}
      # Your custom scrape configs here...

*/}}
{{- define "common.logging.alloy-header" -}}
{{- $global := .Values.global | default dict }}
{{- $lokiEndpoint := ($global.logs).lokiEndpoint | default "" }}
loki.write "default" {
  endpoint {
    url = "{{ $lokiEndpoint }}/loki/api/v1/push"
    basic_auth {
      username = sys.env("LOKI_USERNAME")
      password = sys.env("LOKI_PASSWORD")
    }
    tenant_id = sys.env("LOKI_USERNAME")
  }
}
{{- end }}
